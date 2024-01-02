const std = @import("std");

pub fn parseCardNameFromLine(buf: []const u8) ![]const u8 {
    var i: u64 = 0;
    var len: usize = 0;
    var index: usize = 0;
    var char: [1]u8 = undefined;
    var wasNum: bool = false;
    var char_list = buf;
    for (buf) |_| {
        char[0] = buf[index];
        if (i == 0) {
            if (std.ascii.isDigit(char[0])) wasNum = true;
        }
        if (std.ascii.isDigit(char[0]) and wasNum) {} else if (char[0] == ' ') {
            if (wasNum) {
                wasNum = false;
            } else len += 1;
            //try char_list.append('-');
        } else {
            if (wasNum) return error.syntaxError;
            len += 1;
            //try char_list.append(char[0]);
        }

        i += 1;
        index += 1;
    }
    return char_list[(index - len)..index];
}

pub fn getLine(line: usize, buf: []const u8) ?[]const u8 {
    var line_generator = std.mem.splitAny(u8, buf, "\n");
    var cur_line: ?[]const u8 = line_generator.next();
    for (0..line) |_| {
        cur_line = line_generator.next();
    }
    return cur_line;
}
