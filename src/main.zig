const std = @import("std");
const net = std.net;

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
            std.log.info("packet: {s}", .{buff[0..size]});
            _ = try conn.stream.write("Hello !");
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
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
