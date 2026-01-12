const std = @import("std");
const fs = @import("fs.zig");

const ArenaAllocator = std.heap.ArenaAllocator;

const max_config_size = 1024 * 1024; // 1MB

pub const Config = struct {
    paths: []const []const u8,

    pub const app_name = "defrag";
    pub const config_filename = "config.json";
    pub const fragments_dir = "fragments";
    pub const build_dir = "build";
    pub const manifest_ext = ".manifest";

    pub const Error = error{
        FileNotFound,
        ParseError,
        HomeNotSet,
    };

    pub fn load(arena: *ArenaAllocator) !Config {
        return loadConfig(arena);
    }

    pub fn loadFromPath(arena: *ArenaAllocator, path: []const u8) !Config {
        return loadConfigFromPath(arena, path);
    }
};

fn loadConfig(arena: *ArenaAllocator) !Config {
    const config_path = try getConfigPath(arena);
    return loadConfigFromPath(arena, config_path);
}

fn loadConfigFromPath(arena: *ArenaAllocator, path: []const u8) !Config {
    const allocator = arena.allocator();
    const expanded_path = fs.expandTilde(allocator, path) catch return Config.Error.HomeNotSet;

    const file = std.fs.cwd().openFile(expanded_path, .{}) catch |err| {
        if (err == error.FileNotFound) return Config.Error.FileNotFound;
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, max_config_size);

    const parsed = std.json.parseFromSlice(Config, allocator, content, .{
        .allocate = .alloc_always,
    }) catch return Config.Error.ParseError;

    var expanded_paths = try allocator.alloc([]const u8, parsed.value.paths.len);
    for (parsed.value.paths, 0..) |p, i| {
        expanded_paths[i] = fs.expandTilde(allocator, p) catch return Config.Error.HomeNotSet;
    }

    return Config{
        .paths = expanded_paths,
    };
}

fn getConfigPath(arena: *ArenaAllocator) ![]const u8 {
    const allocator = arena.allocator();

    if (std.posix.getenv("XDG_CONFIG_HOME")) |base| {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ base, Config.app_name, Config.config_filename });
    }

    const home = std.posix.getenv("HOME") orelse return Config.Error.HomeNotSet;
    return std.fmt.allocPrint(allocator, "{s}/.config/{s}/{s}", .{ home, Config.app_name, Config.config_filename });
}
