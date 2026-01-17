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
};

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

    const manifest = Manifest.parse(allocator, manifest_content) catch {
        try log.err("Invalid manifest: {s}", .{manifest_path});
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
    var validated_count: usize = 0;
    var failed_count: usize = 0;

    for (config.stores) |store| {
        if (store_filter) |filter| {
            if (!mem.eql(u8, store.path, filter)) continue;
        }

        const collections_path = try std.fs.path.join(allocator, &.{ store.path, Config.collections_dir });
        var collections_dir = std.fs.cwd().openDir(collections_path, .{ .iterate = true }) catch continue;
        defer collections_dir.close();

        var iter = collections_dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .directory) continue;

            const manifest_path = try std.fs.path.join(allocator, &.{ collections_path, entry.name, "manifest" });
            if (!paths.fileExists(manifest_path)) continue;

            validateManifest(allocator, manifest_path, config) catch {
                failed_count += 1;
                continue;
            };
            validated_count += 1;
        }
    }

    try log.info("", .{});
    if (failed_count == 0) {
        try log.info("Validated {d} manifest(s)", .{validated_count});
    } else {
        try log.info("Validated {d} manifest(s), {d} failed", .{ validated_count, failed_count });
    }
}

