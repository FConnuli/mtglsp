const std = @import("std");
const http = std.http;
const json = std.json;

const url = "https://api.scryfall.com/";

pub const CardFace = struct {
    name: []const u8,
    oracle_text: []u8,
    mana_cost: []const u8,
    power: ?([]const u8) = null,
    toughness: ?([]const u8) = null,
    type_line: []const u8,
};

//pub const DoubleFacedCard = struct { card_faces: struct {
//    @"0": CardFace,
//    @"1": CardFace,
//} };
pub const DoubleFacedCard = struct {
    card_faces: []const CardFace,
};

pub const CardData = union(enum) {
    single_faced_card: CardFace,
    double_faced_card: DoubleFacedCard,
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

const Completion = struct {
    data: [][]const u8,
};

pub const Client = struct {
    client: http.Client,

    pub fn init(allocator: std.mem.Allocator) Client {
        return Client{ .client = http.Client{ .allocator = allocator } };
    }

    pub fn getCard(self: *@This(), card_name: []const u8, arena: std.mem.Allocator) !CardData {
        var full_url = std.ArrayList(u8).init(arena);
        defer full_url.deinit();
        try std.fmt.format(full_url.writer(), url ++ "cards/named?exact={s}", .{card_name});
        const uri = std.Uri.parse(full_url.items) catch unreachable;

        // Create the headers that will be sent to the server.
        var headers = std.http.Headers{ .allocator = arena };
        defer headers.deinit();

        // Accept anything.
        try headers.append("accept", "*/*");

        var request = try self.client.open(.GET, uri, headers, .{});
        defer request.deinit();

        try request.send(.{}); //  start();

        try request.wait();

        const body = request.reader().readAllAlloc(arena, 8192) catch unreachable;

        //std.log.info("{s}", .{body});

        //std.log.info("scryfall card name: {s}", .{card_obj.value.name});

        const single_faced_card_obj = json.parseFromSlice(
            CardFace,
            arena,
            body,
            .{ .ignore_unknown_fields = true },
        );
        std.time.sleep(100000);
        if (single_faced_card_obj) |card| {
            std.log.info("scryfall card name: {s}", .{card.value.name});
            return CardData{ .single_faced_card = card.value };
        } else |err| {
            if (err == error.MissingField) {
                const double_faced_card_obj = try json.parseFromSlice(
                    DoubleFacedCard,
                    arena,
                    body,
                    .{ .ignore_unknown_fields = true },
                );
                std.log.info("scryfall card name: {s}", .{double_faced_card_obj.value.card_faces[0].name});
                return CardData{ .double_faced_card = double_faced_card_obj.value };
            }
            std.log.info("likely not a card", .{});
            return err;
        }
    }

    pub fn getCompletion(self: *@This(), card_name: []const u8, arena: std.mem.Allocator) ![][]const u8 {
        var full_url = std.ArrayList(u8).init(arena);
        defer full_url.deinit();
        try std.fmt.format(
            full_url.writer(),
            url ++ "cards/autocomplete?q={s}",
            .{card_name},
        );
        const uri = std.Uri.parse(full_url.items) catch unreachable;

        // Create the headers that will be sent to the server.
        var headers = std.http.Headers{ .allocator = arena };
        defer headers.deinit();

        // Accept anything.
        try headers.append("accept", "*/*");

        var request = try self.client.open(.GET, uri, headers, .{});
        defer request.deinit();

        try request.send(.{}); //  start();

        try request.wait();

        const body = request.reader().readAllAlloc(arena, 8192) catch unreachable;

        //std.log.info("{s}", .{body});

        //std.log.info("scryfall card name: {s}", .{card_obj.value.name});

        const complete = try json.parseFromSlice(
            Completion,
            arena,
            body,
            .{ .ignore_unknown_fields = true },
        );
        std.time.sleep(100000);
        return complete.value.data;
    }
};
