const std = @import("std");
const mem = std.mem;
const fs = @import("fs.zig");

pub const Store = struct {
    path: []const u8,
    default: bool = false,
};

pub const Config = struct {
    stores: []const Store,

    pub const app_name = "defrag";
    pub const config_filename = "config.json";
    pub const collections_dir = "collections";
    pub const fragments_dir = "fragments";
    pub const build_dir = "build";
    pub const manifest_ext = ".manifest";

    pub const Error = error{
        FileNotFound,
        ParseError,
        HomeNotSet,
    };

    pub fn defaultStore(self: Config) ?[]const u8 {
        for (self.stores) |store| {
            if (store.default) return store.path;
        }
        if (self.stores.len > 0) return self.stores[0].path;
        return null;
    }

    pub fn load(allocator: mem.Allocator) !Config {
        return loadConfig(allocator);
    }

    pub fn loadFromPath(allocator: mem.Allocator, path: []const u8) !Config {
        return loadConfigFromPath(allocator, path);
    }

    pub fn defaultPath(allocator: mem.Allocator) ![]const u8 {
        return getConfigPath(allocator);
    }
};

fn loadConfig(allocator: mem.Allocator) !Config {
    const config_path = try getConfigPath(allocator);
    return loadConfigFromPath(allocator, config_path);
}

fn loadConfigFromPath(allocator: mem.Allocator, path: []const u8) !Config {
    const expanded_path = fs.expandTilde(allocator, path) catch return Config.Error.HomeNotSet;

    const file = std.fs.cwd().openFile(expanded_path, .{}) catch |err| {
        if (err == error.FileNotFound) return Config.Error.FileNotFound;
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, fs.max_file_size);

    const parsed = std.json.parseFromSlice(Config, allocator, content, .{
        .allocate = .alloc_always,
    }) catch return Config.Error.ParseError;

    var expanded_stores = try allocator.alloc(Store, parsed.value.stores.len);
    for (parsed.value.stores, 0..) |store, i| {
        expanded_stores[i] = .{
            .path = fs.expandTilde(allocator, store.path) catch return Config.Error.HomeNotSet,
            .default = store.default,
        };
    }

    return Config{
        .stores = expanded_stores,
    };
}

fn getConfigPath(allocator: mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |base| {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ base, Config.app_name, Config.config_filename });
    }

    const home = std.posix.getenv("HOME") orelse return Config.Error.HomeNotSet;
    return std.fmt.allocPrint(allocator, "{s}/.config/{s}/{s}", .{ home, Config.app_name, Config.config_filename });
}

test "defaultStore returns store with default true" {
    const stores = [_]Store{
        .{ .path = "/first", .default = false },
        .{ .path = "/second", .default = true },
        .{ .path = "/third", .default = false },
    };
    const config = Config{ .stores = &stores };
    try std.testing.expectEqualStrings("/second", config.defaultStore().?);
}

test "defaultStore returns first store when none marked default" {
    const stores = [_]Store{
        .{ .path = "/first", .default = false },
        .{ .path = "/second", .default = false },
    };
    const config = Config{ .stores = &stores };
    try std.testing.expectEqualStrings("/first", config.defaultStore().?);
}

test "defaultStore returns null when no stores" {
    const stores = [_]Store{};
    const config = Config{ .stores = &stores };
    try std.testing.expect(config.defaultStore() == null);
}

test "defaultStore returns single store even without default flag" {
    const stores = [_]Store{
        .{ .path = "/only" },
    };
    const config = Config{ .stores = &stores };
    try std.testing.expectEqualStrings("/only", config.defaultStore().?);
}
