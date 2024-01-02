const std = @import("std");
const net = std.net;
const JSON = std.json;

const jsonRpc = @import("jsonRpc.zig");

const documentSync = @import("documentSync.zig");

const hover = @import("hover.zig");

const completion = @import("completion.zig");

const scryfall = @import("scryfallClient.zig");

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

const initalize_response = @import("initalizeResult.zig").value;
var scryfall_client: scryfall.Client = undefined;

const ParamError = error{MissingParams};

const Request = struct {
    id: u64 = 0,
    method: []const u8,
    params: JSON.Value = undefined,
};

fn readFullMessage(
    stream: net.Stream,
    buffer: []u8,
    cur_size: usize,
    full_size: usize,
) !void {
    if (cur_size >= full_size) return;
    if (stream.read(buffer[cur_size..])) |read_size| {
        return readFullMessage(
            stream,
            buffer,
            cur_size + read_size,
            full_size,
        );
    } else |err| {
        return err;
    }
}

pub export fn dynamicHandleConnection(conn: *const net.StreamServer.Connection) void {
    std.log.info("Handler for connection at {} running in dynamicHandleConnection", .{conn.address});
    handleConnection(conn) catch |err| {
        std.log.err("connection {} exited with error: {}", .{ conn.address, err });
    };
}
// read loop for an individual connection
pub fn handleConnection(conn: *const net.StreamServer.Connection) !void {
    var buff: [10000]u8 = undefined;
    scryfall_client = scryfall.Client.init(gpa);
    defer scryfall_client.client.deinit();

    var documentMap: std.StringHashMap([]const u8) =
        std.StringHashMap([]const u8).init(gpa);
    std.log.info("Handler for connection at {} running", .{conn.address});
    while (conn.stream.read(&buff)) |size| {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();

        if (size == 0) break;

        var items = std.mem.tokenizeSequence(u8, &buff, "\r\n");
        const size_string = items.next().?;
        const json_size: usize = try std.fmt.parseInt(usize, size_string[16..size_string.len], 10);
        const header_size = size_string.len + 4;
        const full_size = json_size + header_size;

        try readFullMessage(conn.stream, &buff, size, full_size);

        const json_string = items.next().?[0..json_size];

        std.log.info("buff: {s}", .{buff[0..full_size]});

        const request = try JSON.parseFromSlice(
            Request,
            allocator,
            json_string,
            .{ .ignore_unknown_fields = true },
        );
        defer request.deinit();

        std.log.info("request: {s}", .{request.value.method});

        if (std.mem.eql(u8, request.value.method, "initialize")) {
            try jsonRpc.writeJsonRpc(
                conn.stream.writer(),
                initalize_response,
                request.value.id,
            );
        } else if (std.mem.eql(u8, request.value.method, "textDocument/hover")) {
            hover.serve(
                conn.stream.writer(),
                request.value.params,
                &documentMap,
                &scryfall_client,
                request.value.id,
                allocator,
            ) catch |err| {
                std.log.err("hover at {} failed with error: {}", .{ conn.address, err });
            };
        } else if (std.mem.eql(u8, request.value.method, "textDocument/didOpen") or std.mem.eql(u8, request.value.method, "textDocument/didChange")) {
            try documentSync.sync(
                &documentMap,
                request.value.params,
                gpa,
            );
        } else if (std.mem.eql(u8, request.value.method, "textDocument/completion")) {
            completion.serve(
                conn.stream.writer(),
                request.value.params,
                &documentMap,
                &scryfall_client,
                request.value.id,
                allocator,
            ) catch |err| {
                const empty: [][]const u8 = &.{};
                try jsonRpc.writeJsonRpc(
                    conn.stream.writer(),
                    .{
                        .isIncomplete = true,
                        .items = empty,
                    },
                    request.value.id,
                );
                std.log.err("hover at {} failed with error: {}", .{ conn.address, err });
            };
        }
    } else |err| {
        return err;
    }
    std.log.info("Closing connection: {}", .{conn.address});
    conn.stream.close();
}

test "simple test" {
    const request = try JSON.parseFromSlice(
        Request,
        std.testing.allocator,
        "{\"method\":\"lul\", \"another\":\"wow\"}",
        .{ .ignore_unknown_fields = true },
    );
    defer request.deinit();
}
