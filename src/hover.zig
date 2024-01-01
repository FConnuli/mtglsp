const std = @import("std");
const fs = std.fs;
const json = std.json;

const jsonRpc = @import("jsonRpc.zig");

const scryfall = @import("scryfallClient.zig");

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

    //const file_name = params_parsed.value.textDocument.uri[7..];

    //const file = try fs.openFileAbsolute(file_name, .{});
    //defer file.close();

    const card_name = try parseCardName(
        params_parsed.value.position.line,
        documentMap.get(params_parsed.value.textDocument.uri).?,
        allocator,
    );
    defer card_name.deinit();

    const card = try scry.getCard(card_name.items, allocator);

    var card_text_render = std.ArrayList(u8).init(allocator);
    defer card_text_render.deinit();

    try writeCard(card_text_render.writer(), card);

    //try jsonRpc.writeJsonRpc(writer, .{ .contents = "test" }, request_id);
    try jsonRpc.writeJsonRpc(writer, .{ .contents = card_text_render.items }, request_id);
}

fn parseCardName(line: u64, buf: []const u8, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var n: u64 = 0;
    var i: u64 = 0;
    var index: usize = 0;
    var char: [1]u8 = undefined;
    var wasNum: bool = false;
    var char_list = std.ArrayList(u8).init(allocator);
    while (n <= line) : (index += 1) {
        char[0] = buf[index];
        if (char[0] == '\n') {
            n += 1;
        } else if (n == line) {
            if (i == 0) {
                if (std.ascii.isDigit(char[0])) wasNum = true;
            }
            if (std.ascii.isDigit(char[0]) and wasNum) {} else if (char[0] == ' ') {
                if (wasNum) {
                    wasNum = false;
                }
                try char_list.append('-');
            } else {
                if (wasNum) return error.syntaxError;
                try char_list.append(char[0]);
            }

            i += 1;
        }
    }
    return char_list;
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
