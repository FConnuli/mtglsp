const std = @import("std");
const net = std.net;
const JSON = std.json;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

const length_header = "Content-Length: {d}\r\n\r\n";

const result_wrapper = "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{s}}}";

const result_wrapper_len = result_wrapper.len - 2 - 3 - 3;

const initalize_response = @embedFile("initializeResult.json");

const Request = struct {
    id: u64 = 0,
    method: []const u8,
    params: JSON.Value = undefined,
};

fn countDigits(comptime T: type, num: T, base: T) T {
    if (num < base) return 1;
    return 1 + countDigits(T, num / base, base);
}

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

// read loop for an individual connection
pub fn handleConnection(conn: net.StreamServer.Connection) !void {
    var buff: [10000]u8 = undefined;

    while (conn.stream.read(&buff)) |size| {
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
            gpa,
            json_string,
            .{ .ignore_unknown_fields = true },
        );
        defer request.deinit();

        std.log.info("request: {s}", .{request.value.method});

        if (std.mem.eql(u8, request.value.method, "initialize")) {
            _ = try std.fmt.format(
                conn.stream.writer(),
                length_header ++ result_wrapper,
                .{
                    initalize_response.len + result_wrapper_len + 1,
                    request.value.id,
                    initalize_response,
                },
            );
        }

        if (std.mem.eql(u8, request.value.method, "textDocument/hover")) {
            const hello = "{\"contents\":\"Hello World!\n![some card](https://cards.scryfall.io/normal/front/5/6/565b2a40-57b1-451f-8c2a-e02222502288.jpg?1562608891)\n\"}";
            _ = try std.fmt.format(
                conn.stream.writer(),
                length_header ++ result_wrapper,
                .{
                    hello.len + result_wrapper_len + countDigits(u64, request.value.id, 10),
                    request.value.id,
                    hello,
                },
            );
            std.log.info(
                length_header ++ result_wrapper,
                .{
                    hello.len + result_wrapper_len + countDigits(u64, request.value.id, 10),
                    request.value.id,
                    hello,
                },
            );
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
