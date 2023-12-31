const std = @import("std");
const http = std.http;
const json = std.json;

const url = "https://api.scryfall.com/";

pub const CardData = struct {
    name: []const u8,
    oracle_text: []const u8,
    mana_cost: []const u8,
    power: ?u16 = null,
    toughness: ?u16 = null,
    type_line: []const u8,
};

pub const Card = struct {
    data: *const CardData,
    parsed_json: json.Parsed(CardData),
    raw_json: []u8,
    allocator: std.mem.Allocator,
    pub fn deinit(self: *const @This()) void {
        _ = self;
        //self.parsed_json.deinit();
        //self.allocator.free(self.raw_json); //TODO figure out a way to do this outside of the function scope
    }
};

pub const Client = struct {
    client: http.Client,

    pub fn init(allocator: std.mem.Allocator) Client {
        return Client{ .client = http.Client{ .allocator = allocator } };
    }

    pub fn getCard(self: *@This(), card_name: []const u8, arena: std.mem.Allocator) !*const Card {
        var full_url = std.ArrayList(u8).init(arena);
        defer full_url.deinit();
        try std.fmt.format(full_url.writer(), url ++ "cards/named?exact={s}", .{card_name});
        const uri = std.Uri.parse(full_url.items) catch unreachable;

        // Create the headers that will be sent to the server.
        var headers = std.http.Headers{ .allocator = arena };
        defer headers.deinit();

        // Accept anything.
        try headers.append("accept", "*/*");

        var request = try self.client.request(.GET, uri, headers, .{});
        defer request.deinit();

        try request.start();

        try request.wait();

        const body = request.reader().readAllAlloc(arena, 8192) catch unreachable;

        //std.log.info("scryfall card name: {s}", .{card_obj.value.name});

        const card_obj = try json.parseFromSlice(
            CardData,
            arena,
            body,
            .{ .ignore_unknown_fields = true },
        );
        std.log.info("scryfall card name: {s}", .{card_obj.value.name});
        return &Card{
            .data = &card_obj.value,
            .parsed_json = card_obj,
            .raw_json = body,
            .allocator = arena,
        };
    }
};
