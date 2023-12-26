const std = @import("std");
const net = std.net;
const JSON = std.json;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

const length_header = "Content-Length: {d}\r\n\r\n";

const result_wrapper = "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{s}}}";

const result_wrapper_len = result_wrapper.len - 2 - 3 - 3;

const initalize_response = @embedFile("initializeResult.json");

const Request = struct { id: u64 = 0, method: []const u8 };

pub fn main() !void {
    const self_addr = try net.Address.resolveIp("127.0.0.1", 6005);

    var buff: [5000]u8 = undefined;

    var listener = net.StreamServer.init(.{});
    try listener.listen(self_addr);
    defer listener.deinit();

    std.log.info("Listening on {}; press Ctrl-C to exit...", .{self_addr});

    while (listener.accept()) |conn| {
        std.log.info("Accepted Connection from: {}", .{conn.address});

        while (conn.stream.read(&buff)) |size| {
            if (size == 0) break;

            var items = std.mem.tokenizeSequence(u8, &buff, "\r\n");
            const size_string = items.next().?;
            // const size : usize = std.fmt.parseInt(usize, size_string[16..size_string.len], 10);
            const json_string = items.next().?;
            std.log.info("{s}", .{json_string[0 .. size - (size_string.len + 4)]});
            const request = try JSON.parseFromSlice(
                Request,
                gpa,
                json_string[0 .. size - (size_string.len + 4)],
                .{ .ignore_unknown_fields = true },
            );
            defer request.deinit();

            std.log.info("request: {s}", .{request.value.method});

            if (std.mem.eql(u8, request.value.method, "initialize")) {
                //std.log.info("packet: {s}", .{buff[0..size]});
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
                const hello = "{\"contents\":\"Hello World!\n\"}";
                //std.log.info("packet: {s}", .{buff[0..size]});
                _ = try std.fmt.format(
                    conn.stream.writer(),
                    length_header ++ result_wrapper,
                    .{
                        hello.len + result_wrapper_len + 1,
                        request.value.id,
                        hello,
                    },
                );
                std.log.info(
                    length_header ++ result_wrapper,
                    .{
                        hello.len + result_wrapper_len + 1,
                        request.value.id,
                        hello,
                    },
                );
            }
            //std.log.info(
            //    "Content-Length: {d}\r\n\r\n{s}",
            //    .{
            //        initalize_response.len,
            //        initalize_response,
            //    },
            //);
        } else |err| {
            return err;
        }

        std.log.info("Closing connection: {}", .{conn.address});
        conn.stream.close();
    } else |err| {
        return err;
    }
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
