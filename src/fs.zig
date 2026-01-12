const std = @import("std");
const mem = std.mem;

const max_fragment_size = 10 * 1024 * 1024; // 10MB
pub const md_ext = ".md";

pub fn readFile(allocator: mem.Allocator, file_path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, max_fragment_size);
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

pub const ExpandTildeError = error{ HomeNotSet, OutOfMemory };

pub fn expandTilde(allocator: mem.Allocator, path: []const u8) ExpandTildeError![]const u8 {
    if (path.len == 0) return path;

    if (path[0] == '~') {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        if (path.len == 1) {
            return allocator.dupe(u8, home);
        }
        if (path[1] == '/') {
            return std.fmt.allocPrint(allocator, "{s}{s}", .{ home, path[1..] });
        }
    }

    return allocator.dupe(u8, path);
}

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

test "expandTilde with absolute path" {
    const result = try expandTilde(std.testing.allocator, "/absolute/path");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("/absolute/path", result);
}

test "expandTilde with home" {
    if (std.posix.getenv("HOME")) |home| {
        const result = try expandTilde(std.testing.allocator, "~/test");
        defer std.testing.allocator.free(result);
        const expected = try std.fmt.allocPrint(std.testing.allocator, "{s}/test", .{home});
        defer std.testing.allocator.free(expected);
        try std.testing.expectEqualStrings(expected, result);
    }
}
