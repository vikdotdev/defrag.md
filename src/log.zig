const std = @import("std");

const File = std.fs.File;

var stderr_buf: [4096]u8 = undefined;
var stderr_writer: ?File.Writer = null;

fn getStderr() *std.Io.Writer {
    if (stderr_writer == null) {
        stderr_writer = File.stderr().writer(&stderr_buf);
    }
    return &stderr_writer.?.interface;
}

pub fn info(comptime format: []const u8, args: anytype) !void {
    const writer = getStderr();
    try writer.print(format ++ "\n", args);
    try writer.flush();
}

pub fn warn(comptime format: []const u8, args: anytype) !void {
    const writer = getStderr();
    try writer.print("WARNING: " ++ format ++ "\n", args);
    try writer.flush();
}

pub fn err(comptime format: []const u8, args: anytype) !void {
    const writer = getStderr();
    try writer.print("ERROR: " ++ format ++ "\n", args);
    try writer.flush();
}
