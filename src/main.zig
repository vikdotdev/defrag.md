const std = @import("std");
const config = @import("config.zig");
const path = @import("core/path.zig");
const manifest = @import("core/manifest.zig");
const heading = @import("core/heading.zig");
const fragment = @import("core/fragment.zig");

pub fn main() !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    defer stdout_writer.interface.flush() catch {};

    try stdout_writer.interface.print("defrag v0.1.0\n", .{});
}

test {
    _ = config;
    _ = path;
    _ = manifest;
    _ = heading;
    _ = fragment;
}
