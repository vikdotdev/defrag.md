const std = @import("std");
const mem = std.mem;
const fs = @import("../fs.zig");
const log = @import("../log.zig");

const Config = @import("../config.zig").Config;
const Store = @import("../config.zig").Store;
const InitOptions = @import("../cli.zig").InitOptions;

pub const InitError = error{
    StoreExists,
    CreateFailed,
};

pub fn run(allocator: mem.Allocator, options: InitOptions) !void {
    const store_path = options.store_path;

    std.fs.cwd().access(store_path, .{}) catch {
        return createStore(allocator, store_path, options.config_path);
    };

    try log.err("Store '{s}' already exists", .{store_path});
    return InitError.StoreExists;
}

fn createStore(allocator: mem.Allocator, store_path: []const u8, config_path: ?[]const u8) !void {
    try log.info("Creating new store: {s}", .{store_path});

    const collections_path = try std.fs.path.join(allocator, &.{ store_path, Config.collections_dir });
    std.fs.cwd().makePath(collections_path) catch {
        try log.err("Failed to create directory: {s}", .{collections_path});
        return InitError.CreateFailed;
    };

    const build_path = try std.fs.path.join(allocator, &.{ store_path, Config.build_dir });
    std.fs.cwd().makePath(build_path) catch {
        try log.err("Failed to create directory: {s}", .{build_path});
        return InitError.CreateFailed;
    };

    try log.info("Created: {s}", .{store_path});

    try createGitignore(allocator, store_path);
    try updateConfig(allocator, store_path, config_path);

    try log.info("", .{});
    try log.info("Next: defrag new <collection-name>", .{});
}

fn createGitignore(allocator: mem.Allocator, store_path: []const u8) !void {
    const gitignore_path = try std.fs.path.join(allocator, &.{ store_path, ".gitignore" });
    const build_entry = "build/\n";

    const file = std.fs.cwd().openFile(gitignore_path, .{ .mode = .read_write }) catch |err| {
        if (err == error.FileNotFound) {
            fs.writeFile(gitignore_path, build_entry) catch return;
            try log.info("Created: {s}", .{gitignore_path});
            return;
        }
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, fs.max_file_size) catch return;
    if (mem.indexOf(u8, content, "build/") != null) return;

    file.seekTo(try file.getEndPos()) catch return;
    file.writeAll(build_entry) catch return;
    try log.info("Updated: {s}", .{gitignore_path});
}

fn updateConfig(allocator: mem.Allocator, store_path: []const u8, custom_config_path: ?[]const u8) !void {
    const config_path = custom_config_path orelse try Config.defaultPath(allocator);
    const expanded_store = fs.expandTilde(allocator, store_path) catch store_path;
    const abs_store = std.fs.cwd().realpathAlloc(allocator, expanded_store) catch expanded_store;

    const file = std.fs.cwd().openFile(config_path, .{ .mode = .read_only }) catch |err| {
        if (err == error.FileNotFound) {
            try createNewConfig(allocator, config_path, abs_store);
            return;
        }
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, fs.max_file_size) catch return;

    const parsed = std.json.parseFromSlice(Config, allocator, content, .{
        .allocate = .alloc_always,
    }) catch {
        try log.err("Failed to parse config", .{});
        return;
    };

    for (parsed.value.stores) |store| {
        const expanded = fs.expandTilde(allocator, store.path) catch store.path;
        const abs = std.fs.cwd().realpathAlloc(allocator, expanded) catch expanded;
        if (mem.eql(u8, abs, abs_store)) {
            try log.info("Store already in config", .{});
            return;
        }
    }

    var new_stores = try allocator.alloc(Store, parsed.value.stores.len + 1);
    @memcpy(new_stores[0..parsed.value.stores.len], parsed.value.stores);
    new_stores[parsed.value.stores.len] = .{ .path = abs_store, .default = false };

    try writeConfig(allocator, config_path, new_stores);
    try log.info("Updated: {s}", .{config_path});
}

fn createNewConfig(allocator: mem.Allocator, config_path: []const u8, store_path: []const u8) !void {
    const dir_path = std.fs.path.dirname(config_path) orelse return;
    std.fs.cwd().makePath(dir_path) catch return;

    var stores = try allocator.alloc(Store, 1);
    stores[0] = .{ .path = store_path, .default = true };

    try writeConfig(allocator, config_path, stores);
    try log.info("Created: {s}", .{config_path});
}

fn writeConfig(allocator: mem.Allocator, config_path: []const u8, stores: []const Store) !void {
    const data = Config{ .stores = stores };
    const json = std.json.Stringify.valueAlloc(allocator, data, .{ .whitespace = .indent_2 }) catch return;
    fs.writeFile(config_path, json) catch return;
}

