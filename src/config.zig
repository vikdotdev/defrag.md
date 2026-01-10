const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
const max_file_size = 1024 * 1024;

pub const ConfigError = error{
    FileNotFound,
    ParseError,
    HomeNotSet,
};

pub const Config = struct {
    paths: []const []const u8,

    pub fn load(arena: *ArenaAllocator) !Config {
        const config_path = try getConfigPath(arena);
        return loadFromPath(arena, config_path);
    }

    pub fn loadFromPath(arena: *ArenaAllocator, path: []const u8) !Config {
        const allocator = arena.allocator();
        const expanded_path = try expandTilde(arena, path);

        const file = std.fs.cwd().openFile(expanded_path, .{}) catch |err| {
            if (err == error.FileNotFound) return ConfigError.FileNotFound;
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, max_file_size);

        const parsed = std.json.parseFromSlice(JsonConfig, allocator, content, .{
            .allocate = .alloc_always,
        }) catch return ConfigError.ParseError;

        // Expand ~ in all paths
        var expanded_paths = try allocator.alloc([]const u8, parsed.value.paths.len);
        for (parsed.value.paths, 0..) |p, i| {
            expanded_paths[i] = try expandTilde(arena, p);
        }

        return Config{
            .paths = expanded_paths,
        };
    }
};

const JsonConfig = struct {
    paths: []const []const u8,
};

fn getConfigPath(arena: *ArenaAllocator) ![]const u8 {
    const allocator = arena.allocator();

    if (std.posix.getenv("XDG_CONFIG_HOME")) |base| {
        return std.fmt.allocPrint(allocator, "{s}/defrag/config.json", .{base});
    }

    const home = std.posix.getenv("HOME") orelse return ConfigError.HomeNotSet;
    return std.fmt.allocPrint(allocator, "{s}/.config/defrag/config.json", .{home});
}

fn expandTilde(arena: *ArenaAllocator, path: []const u8) ![]const u8 {
    const allocator = arena.allocator();

    if (path.len == 0) return path;

    if (path[0] == '~') {
        const home = std.posix.getenv("HOME") orelse return ConfigError.HomeNotSet;
        if (path.len == 1) {
            return try allocator.dupe(u8, home);
        }
        if (path[1] == '/') {
            return try std.fmt.allocPrint(allocator, "{s}{s}", .{ home, path[1..] });
        }
    }

    return try allocator.dupe(u8, path);
}

test "expandTilde with absolute path" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const result = try expandTilde(&arena, "/absolute/path");
    try std.testing.expectEqualStrings("/absolute/path", result);
}

test "expandTilde with home" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    if (std.posix.getenv("HOME")) |home| {
        const result = try expandTilde(&arena, "~/test");
        const expected = try std.fmt.allocPrint(arena.allocator(), "{s}/test", .{home});
        try std.testing.expectEqualStrings(expected, result);
    }
}
