const std = @import("std");
const config_mod = @import("../config.zig");

const mem = std.mem;
const md_ext = config_mod.md_ext;

const max_file_size = 10 * 1024 * 1024; // 10MB

pub fn readFile(allocator: mem.Allocator, file_path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, max_file_size);
}

pub fn writeFile(file_path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(content);
}

pub fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

pub fn ensureMdExtension(allocator: mem.Allocator, path: []const u8) ![]const u8 {
    if (mem.endsWith(u8, path, md_ext)) {
        return path;
    }
    return std.fmt.allocPrint(allocator, "{s}" ++ md_ext, .{path});
}

pub fn ensureParentDir(path: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        try std.fs.cwd().makePath(dir);
    }
}

// Tests

test "ensureMdExtension without extension" {
    const allocator = std.testing.allocator;
    const result = try ensureMdExtension(allocator, "fragment");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("fragment.md", result);
}

test "ensureMdExtension with extension" {
    const result = try ensureMdExtension(std.testing.allocator, "fragment.md");
    try std.testing.expectEqualStrings("fragment.md", result);
}

test "fileExists nonexistent" {
    try std.testing.expect(!fileExists("/nonexistent/path/file.txt"));
}
