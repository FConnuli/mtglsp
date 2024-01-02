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

    const card_name = try parse.parseCardNameFromLine(
        parse.getLine(
            params_parsed.value.position.line,
            documentMap.get(params_parsed.value.textDocument.uri).?,
        ).?,
    );
    std.log.info("parsed card name: {s}", .{card_name});
    //defer card_name.deinit();

    const card = try scry.getCard(card_name, allocator);

    var card_text_render = std.ArrayList(u8).init(allocator);
    defer card_text_render.deinit();

    try writeCard(card_text_render.writer(), card);

    //try jsonRpc.writeJsonRpc(writer, .{ .contents = "test" }, request_id);
    try jsonRpc.writeJsonRpc(writer, .{ .contents = card_text_render.items }, request_id);
}

fn writeCard(writer: anytype, card_data: scryfall.CardData) !void {
    switch (card_data) {
        .single_faced_card => |card| {
            try writeCardFace(writer, card);
        },
        .double_faced_card => |card| {
            for (card.card_faces, 0..) |face, i| {
                if (i != 0) _ = try writer.write("\n");
                try writeCardFace(writer, face);
            }
        },
    }
}

fn writeCardFace(writer: anytype, card: scryfall.CardFace) !void {
    const line_length: usize = card.name.len + @max(23, card.mana_cost.len + 3);
    formatText(card.oracle_text, line_length);
    _ = try std.fmt.format(writer,
        \\# {s} {s: >20} 
        \\
        \\   
        \\{s}
        \\
        \\{s}
        \\
    , .{ card.name, card.mana_cost, card.type_line, card.oracle_text });
    if (card.power != null and card.toughness != null) {
        _ = try std.fmt.format(writer,
            \\
            \\{s}/{s}
            \\
        , .{ card.power.?, card.toughness.? });
    }
}

fn formatText(buffer: []u8, line_length: usize) void {
    var last_space: usize = 0;
    var cur_line_length: usize = 0;
    for (buffer, 0..) |char, i| {
        if (char == ' ') {
            last_space = i;
        }
        if (char == '\n') {
            cur_line_length = 0;
            continue;
        }
        cur_line_length += 1;
        if (cur_line_length >= line_length) {
            buffer[last_space] = '\n';
            cur_line_length = i - last_space;
        }
    }
}
