const std = @import("std");
const fs = std.fs;
const json = std.json;

const jsonRpc = @import("jsonRpc.zig");

const scryfall = @import("scryfallClient.zig");

const parse = @import("parse.zig");

const Params = struct {
    position: struct { line: u64 },
    textDocument: struct { uri: []const u8 },
};

const CompletionItem = struct {
    label: []const u8,
};

pub fn serve(
    writer: anytype,
    params: json.Value,
    documentMap: *std.StringHashMap([]const u8),
    scry: *scryfall.Client,
    request_id: u64,
    allocator: std.mem.Allocator,
) !void {
    const params_parsed = try json.parseFromValue(
        Params,
        allocator,
        params,
        .{ .ignore_unknown_fields = true },
    );
    defer params_parsed.deinit();

    const line = parse.getLine(
        params_parsed.value.position.line,
        documentMap.get(params_parsed.value.textDocument.uri).?,
    ).?;

    const card_name = try parse.parseCardNameFromLine(
        line,
    );
    const position: usize = @intFromPtr(card_name.ptr) - @intFromPtr(line.ptr);
    std.log.info("parsed card name: {s}", .{card_name});
    std.log.info("card name position: {d}", .{position});
    if (card_name.len < 3) {
        return error.TooShort;
    }

    //defer card_name.deinit();

    const cards = try scry.getCompletion(card_name, allocator);

    // scryfall has a maximum length of 20 items for search calls
    var completionItems: [20]CompletionItem = undefined;

    for (cards, 0..) |card, i| {
        completionItems[i].label = card;
    }

    //try jsonRpc.writeJsonRpc(writer, .{ .contents = "test" }, request_id);
    try jsonRpc.writeJsonRpc(
        writer,
        .{
            .isIncomplete = true,
            .itemDefaults = .{
                .editRange = .{
                    .start = .{
                        .line = params_parsed.value.position.line,
                        .character = position,
                    },
                    .end = .{
                        .line = params_parsed.value.position.line,
                        .character = line.len,
                    },
                },
            },
            .items = completionItems[0..cards.len],
        },
        request_id,
    );
}
