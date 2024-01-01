const std = @import("std");
const json = std.json;

/// structure is built such that json.parseFromValue() will parse to it
/// for both didChange and didOpen parameters
const Params = struct {
    textDocument: struct {
        text: ?[]const u8 = null,
        uri: []const u8,
    },
    contentChanges: ?[]struct { text: []const u8 } = null,
};

pub fn sync(
    map: *std.StringHashMap([]const u8),
    params: json.Value,
    allocator: std.mem.Allocator,
) !void {
    const params_parsed = try json.parseFromValue(
        Params,
        allocator,
        params,
        .{ .ignore_unknown_fields = true },
    );
    defer params_parsed.deinit();

    const maybe_text =
        if (params_parsed.value.textDocument.text) |t| t else if (params_parsed.value.contentChanges) |t| t[0].text else json.Error.UnexpectedEndOfInput;
    if (maybe_text) |text| {
        if (map.get(params_parsed.value.textDocument.uri)) |slice| {
            allocator.free(slice);
        } else {
            const buf = try allocator.alloc(u8, params_parsed.value.textDocument.uri.len);

            std.mem.copyForwards(u8, buf, params_parsed.value.textDocument.uri);

            try map.put(buf, "");
        }

        const buf = try allocator.alloc(u8, text.len);

        std.mem.copyForwards(u8, buf, text);

        try map.put(params_parsed.value.textDocument.uri, buf);
    } else |err| return err;
}
