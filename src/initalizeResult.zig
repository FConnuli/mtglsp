pub const value = .{
    .name = "mtglsp",
    .version = "0.0.1",
    .capabilities = .{
        .completionProvider = .{
            .triggerCharacter = [_][]const u8{" "},
            .allCommitCharacters = [_][]const u8{"\n"},
        },
        .hoverProvider = true,
    },
};
