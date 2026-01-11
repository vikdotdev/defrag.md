const std = @import("std");

const File = std.fs.File;

var stdout_buf: [4096]u8 = undefined;
var stderr_buf: [4096]u8 = undefined;
var stdout_writer: ?File.Writer = null;
var stderr_writer: ?File.Writer = null;

fn getStdout() *std.Io.Writer {
    if (stdout_writer == null) {
        stdout_writer = File.stdout().writer(&stdout_buf);
    }
    return &stdout_writer.?.interface;
}

fn getStderr() *std.Io.Writer {
    if (stderr_writer == null) {
        stderr_writer = File.stderr().writer(&stderr_buf);
    }
    return &stderr_writer.?.interface;
}

pub fn info(comptime format: []const u8, args: anytype) !void {
    const writer = getStdout();
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
