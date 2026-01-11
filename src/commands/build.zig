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
        try buildAll(arena, config);
    } else {
        try buildManifest(arena, options.manifest_path, options.output_path, config);
    }
}

/// Build a single manifest file
fn buildManifest(
    arena: *ArenaAllocator,
    manifest_path: []const u8,
    output_path: ?[]const u8,
    config: Config,
) !void {
    const allocator = arena.allocator();

    // Determine collection directory from manifest path
    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection = Collection.init(manifest_dir);

    // Read manifest file
    const manifest_content = fs.readFile(allocator, manifest_path) catch {
        return BuildError.ManifestNotFound;
    };

    // Parse manifest
    const manifest = Manifest.parse(arena, manifest_content) catch {
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
        try output.appendSlice(allocator, "\n\n");
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
    const final_output_path = output_path orelse try defaultOutputPath(allocator, manifest_path);

    // Write output file
    try fs.ensureParentDir(final_output_path);
    try fs.writeFile(final_output_path, output.items);

    try log.info("Built: {s}", .{final_output_path});
}

/// Build all manifests in a collection
fn buildAll(arena: *ArenaAllocator, config: Config) !void {
    _ = arena;
    _ = config;
    // TODO: Find all *.manifest files and build each
    try log.info("build --all not yet implemented", .{});
}

/// Generate default output path: build/<collection-name>.md
fn defaultOutputPath(allocator: mem.Allocator, manifest_path: []const u8) ![]const u8 {
    const dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection_name = std.fs.path.basename(dir);
    return std.fmt.allocPrint(allocator, "build/{s}.md", .{collection_name});
}

test "defaultOutputPath" {
    const allocator = std.testing.allocator;
    const result = try defaultOutputPath(allocator, "/path/to/my-collection/manifest");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("build/my-collection.md", result);
}
