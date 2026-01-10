const std = @import("std");

pub fn main() !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    defer stdout_writer.interface.flush() catch {};

    try stdout_writer.interface.print("defrag v0.1.0\n", .{});
}
