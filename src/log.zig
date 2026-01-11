const std = @import("std");

const File = std.fs.File;

pub fn info(comptime format: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var writer = File.stdout().writer(&buf);
    try writer.interface.print(format ++ "\n", args);
    try writer.interface.flush();
}

pub fn warn(comptime format: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var writer = File.stderr().writer(&buf);
    try writer.interface.print("WARNING: " ++ format ++ "\n", args);
    try writer.interface.flush();
}

pub fn err(comptime format: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    var writer = File.stderr().writer(&buf);
    try writer.interface.print("ERROR: " ++ format ++ "\n", args);
    try writer.interface.flush();
}
