const std = @import("std");
const mem = std.mem;
const fs = @import("../fs.zig");
const log = @import("../log.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const Config = @import("../config.zig").Config;
const Manifest = @import("../core/manifest.zig").Manifest;
const Collection = @import("../core/fragment.zig").Collection;
const Fragment = @import("../core/fragment.zig").Fragment;
const BuildOptions = @import("../cli.zig").BuildOptions;

pub const BuildError = error{
    ManifestNotFound,
    InvalidManifest,
    FragmentNotFound,
    OutputError,
};

/// Execute the build command
pub fn run(arena: *ArenaAllocator, options: BuildOptions, config: Config) !void {
    if (options.all) {
        try buildAllManifests(arena, config);
    } else {
        try buildManifest(arena, options, config);
    }
}

/// Build a single manifest file
fn buildManifest(arena: *ArenaAllocator, build_options: BuildOptions, config: Config) !void {
    const allocator = arena.allocator();

    // Determine collection directory from manifest path
    const manifest_dir = std.fs.path.dirname(build_options.manifest_path) orelse ".";
    const collection = try Collection.init(allocator, manifest_dir);

    // Read manifest file
    const manifest_content = fs.readFile(allocator, build_options.manifest_path) catch {
        try log.err("Manifest file not found: {s}", .{build_options.manifest_path});
        return BuildError.ManifestNotFound;
    };

    // Parse manifest
    const manifest = Manifest.parse(arena, manifest_content) catch {
        try log.err("Invalid manifest: {s}", .{build_options.manifest_path});
        return BuildError.InvalidManifest;
    };

    // Build output
    var output: ArrayList(u8) = .empty;

    for (manifest.fragments) |entry| {
        const fragment_id = Fragment.Id.parse(entry.name);

        const frag_path = Fragment.resolve(arena, collection, fragment_id, config) catch {
            try log.warn("Fragment not found: {s}", .{entry.name});
            continue;
        };

        const processed = Fragment.process(
            arena,
            frag_path,
            fragment_id,
            collection,
            manifest,
            entry.level,
        ) catch |process_err| {
            try log.warn("Failed to process fragment {s}: {}", .{ entry.name, process_err });
            continue;
        };

        // Append to output
        try output.appendSlice(allocator, processed.heading);
        try output.appendSlice(allocator, "\n");
        if (processed.content.len > 0) {
            try output.appendSlice(allocator, processed.content);
            try output.appendSlice(allocator, "\n\n");
        }
    }

    // Trim trailing newlines
    while (output.items.len > 0 and output.items[output.items.len - 1] == '\n') {
        _ = output.pop();
    }
    try output.append(allocator, '\n');

    // Determine output path
    const final_output_path = if (build_options.output_path) |path|
        path
    else
        try defaultOutputPath(allocator, build_options.manifest_path);

    // Write output file
    try fs.ensureParentDir(final_output_path);
    try fs.writeFile(final_output_path, output.items);

    try log.info("Built: {s}", .{final_output_path});
}

/// Build all *.manifest files in current directory
fn buildAllManifests(arena: *ArenaAllocator, config: Config) !void {
    const allocator = arena.allocator();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.fs.cwd().realpath(".", &buf) catch ".";
    try log.info("Building {s}/*{s}", .{ cwd, Config.manifest_ext });

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var built_count: usize = 0;
    var iter = dir.iterate();

    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!mem.endsWith(u8, entry.name, Config.manifest_ext)) continue;

        const manifest_path = try allocator.dupe(u8, entry.name);
        buildManifest(arena, .{ .manifest_path = manifest_path }, config) catch |err| {
            try log.warn("Failed to build {s}: {}", .{ entry.name, err });
            continue;
        };
        built_count += 1;
    }

    if (built_count == 0) {
        try log.info("No *{s} files found in current directory", .{Config.manifest_ext});
    } else {
        try log.info("Built {d} manifest(s)", .{built_count});
    }
}

/// Generate default output path: build/<collection>.<manifest-prefix>.md
/// e.g. my-collection/default.manifest -> build/my-collection.default.md
fn defaultOutputPath(allocator: mem.Allocator, manifest_path: []const u8) ![]const u8 {
    const collection_name = try getCollectionName(manifest_path);
    const prefix = getManifestPrefix(manifest_path);
    return std.fmt.allocPrint(
        allocator,
        Config.build_dir ++ "/{s}.{s}" ++ fs.md_ext,
        .{ collection_name, prefix },
    );
}

fn getCollectionName(manifest_path: []const u8) ![]const u8 {
    if (std.fs.path.dirname(manifest_path)) |dir| {
        if (!mem.eql(u8, dir, ".")) {
            return std.fs.path.basename(dir);
        }
    }
    // Manifest in current directory - get current dir name
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &buf);
    return std.fs.path.basename(cwd);
}

fn getManifestPrefix(manifest_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(manifest_path);
    if (mem.endsWith(u8, basename, Config.manifest_ext)) {
        return basename[0 .. basename.len - Config.manifest_ext.len];
    }
    return basename;
}

test "defaultOutputPath with .manifest extension" {
    const allocator = std.testing.allocator;
    const result = try defaultOutputPath(allocator, "/path/to/my-collection/api.manifest");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("build/my-collection.api.md", result);
}

test "defaultOutputPath without extension" {
    const allocator = std.testing.allocator;
    const result = try defaultOutputPath(allocator, "/path/to/my-collection/default");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("build/my-collection.default.md", result);
}
