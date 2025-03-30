const std = @import("std");
const net = std.net;

const RequestHandler = @import("requestHandler.zig");

const Handler_t = @TypeOf(RequestHandler.dynamicHandleConnection);

var dynamicHandleConnection: if (HOTRELOAD) *Handler_t else void = undefined;

const HOTRELOAD = build_options.hotreload;
var dll_file: if (HOTRELOAD) std.DynLib else void = undefined;

const build_options = @import("build_options");
const LIB_SRC_DIR = "zig-out/lib";
const LIB_DEST_DIR = "libs";
const LIB_WATCH_PATH = "zig-out\\lib";

const CopyFile = struct { src: []const u8, dst: []const u8 };
const FILES_TO_COPY = [_]CopyFile{
    .{ .src = LIB_SRC_DIR ++ "/libhotreload.so", .dst = LIB_DEST_DIR ++ "/libhotreload.so" },
};

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

pub fn main() !void {
    if (HOTRELOAD) try reloadLibrary(false);

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.next();
    const arg1 = args.next();
    std.log.info("{?s}", .{arg1});

    if (arg1 != null and
        std.mem.orderZ(u8, arg1.?, "--network") == std.math.Order.eq)
    {
        const self_addr = try net.Address.resolveIp("127.0.0.1", 6005);
        //const localhost = net.Address{ .in = loopback };
        //        var listener = net.StreamServer.init(.{});
        var listener = try self_addr.listen(.{ .reuse_port = true });
        //try listener.listen(self_addr);
        defer listener.deinit();

        std.log.info("Listening on {}; press Ctrl-C to exit...", .{self_addr});

        while (listener.accept()) |conn| {
            std.log.info("Accepted Connection from: {}", .{conn.address});
            handleConnection(&conn);
            if (HOTRELOAD) try reloadLibrary(true);
        } else |err| {
            std.log.info("Connection rejected from error: {}", .{err});
        }
    } else {
        try RequestHandler.handleConnection(
            std.io.getStdOut().writer(),
            std.io.getStdIn().reader(),
            "",
        );
    }
}

/// Move library from zig-out to libs folder
/// When first loading, run with close_dll = false. On hotreload, close_dll = true
fn reloadLibrary(close_dll: bool) !void {
    if (close_dll) dll_file.close();
    for (FILES_TO_COPY) |paths| try std.fs.Dir.copyFile(std.fs.cwd(), paths.src, std.fs.cwd(), paths.dst, .{});
    const out_path = LIB_DEST_DIR ++ "/libhotreload.so";
    //dll_file = try std.DynLib.open("/home/frankie/Documents/zig/mtglsp/zig-out/lib/libhotreload.so");
    dll_file = try std.DynLib.open(out_path);
    std.debug.print("reloaded dll: {s}\n", .{out_path});
    dynamicHandleConnection = dll_file.lookup(*Handler_t, "dynamicHandleConnection").?;
}

fn handleConnection(conn: *const net.Server.Connection) void {
    if (HOTRELOAD) {
        std.log.info("Dynamically starting connection handler with function at {}", .{dynamicHandleConnection});
        (dynamicHandleConnection)(conn);
    } else RequestHandler.dynamicHandleConnection(conn);
}
