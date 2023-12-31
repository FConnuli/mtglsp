const std = @import("std");

const json = std.json;

const length_header = "Content-Length: {d}\r\n\r\n";

const result_wrapper = "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{s}}}";

const result_wrapper_len = result_wrapper.len - 2 - 3 - 3;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

fn countDigits(comptime T: type, num: T, base: T) T {
    if (num < base) return 1;
    return 1 + countDigits(T, num / base, base);
}

pub fn writeJsonRpc(
    writer: anytype,
    payload: anytype,
    request_id: u64,
) !void {
    // makes a writer that writes to nothing but counts the amount of writes
    var counting_writer = std.io.countingWriter(std.io.null_writer);
    const json_size = counting_writer.writer();
    try json.stringify(
        .{ .jsonrpc = "2.0", .id = request_id, .result = payload },
        .{},
        json_size,
    );
    try std.fmt.format(writer, length_header, .{
        json_size.context.bytes_written,
    });
    try json.stringify(
        .{ .jsonrpc = "2.0", .id = request_id, .result = payload },
        .{},
        writer,
    );

    var json_size_test = std.ArrayList(u8).init(gpa); //payload.len + result_wrapper_len + countDigits(u64, request_id, 10);
    defer json_size_test.deinit();
    try json.stringify(
        .{ .jsonrpc = "2.0", .id = request_id, .result = payload },
        .{},
        json_size_test.writer(),
    );

    std.log.info("sent jsonRPC: {s}", .{json_size_test.items});

    // _ = try std.fmt.format(
    //     writer,
    //     length_header ++ result_wrapper,
    //     .{
    //         json_size,
    //         request_id,
    //         payload,
    //     },
    // );
    // std.log.info(
    //     length_header ++ result_wrapper,
    //     .{
    //         json_size,
    //         request_id,
    //         payload,
    //     },
    // );
}

pub fn sanitizeString(str: []const u8, writer: anytype) !void {
    var i = 0;
    while (i < str.len) : (i += 1) {
        if (str[i] == '"') {
            writer.write("\\");
        }
        writer.write(str[i..1]);
    }
}
