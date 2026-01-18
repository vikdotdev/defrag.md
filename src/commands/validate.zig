const std = @import("std");
const mem = std.mem;
const paths = @import("../paths.zig");
const log = @import("../log.zig");

const Config = @import("../config.zig").Config;
const Manifest = @import("../core/manifest.zig").Manifest;
const Collection = @import("../core/fragment.zig").Collection;
const Fragment = @import("../core/fragment.zig").Fragment;
const ValidateOptions = @import("../cli.zig").ValidateOptions;

pub const ValidateError = error{
    ManifestNotFound,
    InvalidManifest,
    ValidationFailed,
    StoreNotFound,
};

pub fn printHelp(version: []const u8) !void {
    try log.info(
        \\
        \\Usage: defrag validate <manifest> [options]
        \\       defrag validate --all [options]
        \\
        \\Validate a manifest file.
        \\
        \\Arguments:
        \\    <manifest>         Path to manifest file (or use --all)
        \\
        \\Options:
        \\    -m, --manifest     Path to manifest file
        \\    -a, --all          Validate all collections in store
        \\    -s, --store <name> Use specific store
        \\    --config <path>    Path to config file
        \\
        \\Examples:
        \\    defrag validate path/to/manifest
        \\    defrag validate --all
        \\
        \\Version: {s}
    , .{version});
}

pub fn run(allocator: mem.Allocator, options: ValidateOptions, config: Config) !void {
    if (options.all) {
        try validateAllManifests(allocator, options.store, config);
    } else {
        try validateManifest(allocator, options.manifest_path.?, config);
    }
}

fn validateManifest(allocator: mem.Allocator, manifest_path: []const u8, config: Config) !void {
    const manifest_content = paths.readFile(allocator, manifest_path) catch {
        try log.err("Manifest file not found: {s}", .{manifest_path});
        return ValidateError.ManifestNotFound;
    };

    var parse_ctx = Manifest.ParseContext{};
    const manifest = Manifest.parse(allocator, manifest_content, &parse_ctx) catch {
        if (parse_ctx.error_message) |msg| {
            try log.err("{s}", .{msg});
            try log.err("  in: {s}", .{manifest_path});
        }
        return ValidateError.InvalidManifest;
    };

    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection_name = try paths.getCollectionName(allocator, manifest_dir);
    const collection = try Collection.init(allocator, manifest_dir);

    try log.info("Validating manifest: {s}", .{manifest_path});
    try log.info("Collection path: {s}", .{manifest_dir});
    try log.info("", .{});

    var total: usize = 0;
    var valid: usize = 0;
    var missing: usize = 0;

    for (manifest.fragments) |entry| {
        total += 1;
        const fragment_id = Fragment.Id.parse(entry.name);
        const name_with_ext = try paths.ensureMdExtension(allocator, entry.name);

        if (Fragment.resolve(allocator, collection, fragment_id, config)) |_| {
            try log.info("✓ {s} (level {d})", .{ name_with_ext, entry.level });
            valid += 1;
        } else |_| {
            try log.info("✗ {s} (not found)", .{name_with_ext});
            missing += 1;
        }
    }

    try log.info("", .{});
    try log.info("Validation Summary:", .{});
    try log.info("Total rules: {d}", .{total});
    try log.info("Valid rules: {d}", .{valid});
    try log.info("Missing rules: {d}", .{missing});
    try log.info("", .{});

    if (missing == 0) {
        try log.info("✓ Collection '{s}' is valid!", .{collection_name});
    } else {
        try log.info("✗ Collection '{s}' has {d} missing fragment(s)", .{ collection_name, missing });
        return ValidateError.ValidationFailed;
    }
}

fn validateAllManifests(allocator: mem.Allocator, store_filter: ?[]const u8, config: Config) !void {
    if (store_filter) |filter| {
        const store_path = config.resolveStore(filter) orelse {
            try log.err("Store not found: {s}", .{filter});
            return ValidateError.StoreNotFound;
        };
        if (!paths.fileExists(store_path)) {
            try log.err("Store path does not exist: {s}", .{store_path});
            return ValidateError.StoreNotFound;
        }
    }

    var validated_count: usize = 0;
    var failed_count: usize = 0;

    for (config.stores) |store| {
        if (store_filter) |filter| {
            if (!storeMatches(store.path, filter)) continue;
        }

        const collections_path = try std.fs.path.join(allocator, &.{ store.path, Config.collections_dir });
        var collections_dir = std.fs.cwd().openDir(collections_path, .{ .iterate = true }) catch continue;
        defer collections_dir.close();

        var iter = collections_dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .directory) continue;

            const collection_path = try std.fs.path.join(allocator, &.{ collections_path, entry.name });
            validateCollectionManifests(allocator, collection_path, config, &validated_count, &failed_count) catch continue;
        }
    }

    try log.info("", .{});
    if (failed_count == 0) {
        try log.info("Validated {d} manifest(s)", .{validated_count});
    } else {
        try log.info("Validated {d} manifest(s), {d} failed", .{ validated_count, failed_count });
    }
}

fn validateCollectionManifests(
    allocator: mem.Allocator,
    collection_path: []const u8,
    config: Config,
    validated_count: *usize,
    failed_count: *usize,
) !void {
    var collection_dir = std.fs.cwd().openDir(collection_path, .{ .iterate = true }) catch return;
    defer collection_dir.close();

    var coll_iter = collection_dir.iterate();
    while (coll_iter.next() catch null) |file_entry| {
        if (file_entry.kind != .file) continue;
        if (!mem.endsWith(u8, file_entry.name, Config.manifest_ext)) continue;

        const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, file_entry.name });
        validateManifest(allocator, manifest_path, config) catch {
            failed_count.* += 1;
            continue;
        };
        validated_count.* += 1;
    }
}

fn storeMatches(store_path: []const u8, filter: []const u8) bool {
    const store_name = std.fs.path.basename(store_path);
    return mem.eql(u8, store_name, filter);
}
