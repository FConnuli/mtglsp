const std = @import("std");
const net = std.net;
const RequestHandler = @import("requestHandler.zig");

pub fn main() !void {
    const self_addr = try net.Address.resolveIp("127.0.0.1", 6005);

    var listener = net.StreamServer.init(.{});
    try listener.listen(self_addr);
    defer listener.deinit();

    std.log.info("Listening on {}; press Ctrl-C to exit...", .{self_addr});

    while (listener.accept()) |conn| {
        std.log.info("Accepted Connection from: {}", .{conn.address});
        const foreign_addr = conn.address;
        RequestHandler.handleConnection(conn) catch |err| {
            std.log.info("Connection {} lost because: {}", .{ foreign_addr, err });
        };
    } else |err| {
        std.log.info("Connection rejected from error: {}", .{err});
    }
}
