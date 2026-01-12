const std = @import("std");
const mem = std.mem;
const fs = @import("../fs.zig");
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
    const manifest_path = options.manifest_path;

    const manifest_content = fs.readFile(allocator, manifest_path) catch {
        try log.err("Manifest file not found: {s}", .{manifest_path});
        return ValidateError.ManifestNotFound;
    };

    const manifest = Manifest.parse(allocator, manifest_content) catch {
        try log.err("Invalid manifest: {s}", .{manifest_path});
        return ValidateError.InvalidManifest;
    };

    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection_name = try getCollectionName(allocator, manifest_dir);
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
        const name_with_ext = try fs.ensureMdExtension(allocator, entry.name);

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

fn getCollectionName(allocator: std.mem.Allocator, manifest_dir: []const u8) ![]const u8 {
    if (!std.mem.eql(u8, manifest_dir, ".")) {
        return std.fs.path.basename(manifest_dir);
    }
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &buf);
    return allocator.dupe(u8, std.fs.path.basename(cwd));
}
