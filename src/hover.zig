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

    const file_name = params_parsed.value.textDocument.uri[7..];

    const file = try fs.openFileAbsolute(file_name, .{});
    defer file.close();

    const card_name = try parseCardName(
        params_parsed.value.position.line,
        file,
        allocator,
    );
    defer card_name.deinit();

    const card = try scry.getCard(card_name.items, allocator);

    var card_text_render = std.ArrayList(u8).init(allocator);
    defer card_text_render.deinit();

    try writeCard(card_text_render.writer(), card.data);

    try jsonRpc.writeJsonRpc(writer, .{ .contents = card_text_render.items }, request_id);
}

fn parseCardName(line: u64, file: fs.File, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var n: u64 = 0;
    var i: u64 = 0;
    var char: [1]u8 = undefined;
    var wasNum: bool = false;
    var char_list = std.ArrayList(u8).init(allocator);
    while (n <= line) {
        _ = try file.read(char[0..1]);
        if (char[0] == '\n') {
            n += 1;
        } else if (n == line) {
            if (i == 0) {
                if (std.ascii.isDigit(char[0])) wasNum = true;
            } else {
                if (std.ascii.isDigit(char[0]) and wasNum) {} else if (char[0] == ' ') {
                    if (wasNum) {
                        wasNum = false;
                    }
                    try char_list.append('-');
                } else {
                    if (wasNum) return error.syntaxError;
                    try char_list.append(char[0]);
                }
            }
            i += 1;
        }
    }
    return char_list;
}

fn writeCard(writer: anytype, card: *const scryfall.CardData) !void {
    _ = try std.fmt.format(writer,
        \\{s}{s: >20}
        \\
        \\   
        \\{s}
        \\
        \\{s}
        \\
        \\
        \\{?d}/{?d}
    , .{
        card.name, card.mana_cost, card.type_line, card.oracle_text, card.power, card.toughness,
    });
}
