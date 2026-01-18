const std = @import("std");
const mem = std.mem;
const paths = @import("../paths.zig");
const log = @import("../log.zig");

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

pub fn printHelp(version: []const u8) !void {
    try log.info(
        \\
        \\Usage: defrag build <manifest> [options]
        \\       defrag build --all [options]
        \\
        \\Build documentation from a manifest.
        \\
        \\Arguments:
        \\    <manifest>         Path to manifest file (or use --all)
        \\
        \\Options:
        \\    -m, --manifest     Path to manifest file
        \\    -o, --out <path>   Output file path
        \\    -a, --all          Build all collections in store
        \\    -s, --store <name> Use specific store
        \\    --config <path>    Path to config file
        \\
        \\Examples:
        \\    defrag build path/to/manifest
        \\    defrag build --manifest path/to/manifest --out output.md
        \\    defrag build --all
        \\
        \\Version: {s}
    , .{version});
}

/// Execute the build command
pub fn run(allocator: mem.Allocator, options: BuildOptions, config: Config) !void {
    if (options.all) {
        try buildAllManifests(allocator, options.store, config);
    } else {
        try buildManifest(allocator, options.manifest_path.?, options.output_path, config);
    }
}

/// Build a single manifest file
fn buildManifest(
    allocator: mem.Allocator,
    manifest_path: []const u8,
    output_path: ?[]const u8,
    config: Config,
) !void {
    // Determine collection directory from manifest path
    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection = try Collection.init(allocator, manifest_dir);

    // Read manifest file
    const manifest_content = paths.readFile(allocator, manifest_path) catch {
        try log.err("Manifest file not found: {s}", .{manifest_path});
        return BuildError.ManifestNotFound;
    };

    // Parse manifest
    var parse_ctx = Manifest.ParseContext{};
    const manifest = Manifest.parse(allocator, manifest_content, &parse_ctx) catch {
        if (parse_ctx.error_message) |msg| {
            try log.err("{s}", .{msg});
            try log.err("  in: {s}", .{manifest_path});
        }
        return BuildError.InvalidManifest;
    };

    // Build output
    var output: ArrayList(u8) = .empty;

    for (manifest.fragments) |entry| {
        const fragment_id = Fragment.Id.parse(entry.name);

        const frag_path = Fragment.resolve(allocator, collection, fragment_id, config) catch {
            try log.warn("Fragment not found: {s}", .{entry.name});
            continue;
        };

        const processed = Fragment.process(
            allocator,
            frag_path,
            fragment_id,
            collection,
            manifest,
            entry.level,
        ) catch {
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
    const final_output_path = if (output_path) |path|
        path
    else
        try defaultOutputPath(allocator, manifest_path);

    // Write output file
    try paths.ensureParentDir(final_output_path);
    try paths.writeFile(final_output_path, output.items);

    try log.info("Built: {s}", .{final_output_path});
}

/// Build all manifests in stores
fn buildAllManifests(allocator: mem.Allocator, store_filter: ?[]const u8, config: Config) !void {
    var built_count: usize = 0;

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
            buildCollectionManifests(
                allocator,
                collection_path,
                entry.name,
                store.path,
                config,
                &built_count,
            ) catch {
                continue;
            };
        }
    }

    if (built_count == 0) {
        try log.info("No manifests found", .{});
    } else {
        try log.info("Built {d} manifest(s)", .{built_count});
    }
}

fn buildCollectionManifests(
    allocator: mem.Allocator,
    collection_path: []const u8,
    collection_name: []const u8,
    store_path: []const u8,
    config: Config,
    built_count: *usize,
) !void {
    var collection_dir = std.fs.cwd().openDir(collection_path, .{ .iterate = true }) catch return;
    defer collection_dir.close();

    var coll_iter = collection_dir.iterate();
    while (coll_iter.next() catch null) |file_entry| {
        if (file_entry.kind != .file) continue;
        if (!mem.endsWith(u8, file_entry.name, Config.manifest_ext)) continue;

        const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, file_entry.name });
        const prefix = getManifestPrefix(file_entry.name);
        const output_name = try std.fmt.allocPrint(allocator, "{s}.{s}{s}", .{ collection_name, prefix, paths.md_ext });
        const output_path = try std.fs.path.join(allocator, &.{ store_path, Config.build_dir, output_name });

        buildManifest(allocator, manifest_path, output_path, config) catch {
            continue;
        };
        built_count.* += 1;
    }
}

/// Generate default output path: build/<collection>.<manifest-prefix>.md
/// e.g. my-collection/default.manifest -> build/my-collection.default.md
fn defaultOutputPath(allocator: mem.Allocator, manifest_path: []const u8) ![]const u8 {
    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const collection_name = try paths.getCollectionName(allocator, manifest_dir);
    const prefix = getManifestPrefix(manifest_path);
    return std.fmt.allocPrint(
        allocator,
        Config.build_dir ++ "/{s}.{s}" ++ paths.md_ext,
        .{ collection_name, prefix },
    );
}

fn getManifestPrefix(manifest_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(manifest_path);
    if (mem.endsWith(u8, basename, Config.manifest_ext)) {
        return basename[0 .. basename.len - Config.manifest_ext.len];
    }
    return basename;
}

fn storeMatches(store_path: []const u8, filter: []const u8) bool {
    const store_name = std.fs.path.basename(store_path);
    return mem.eql(u8, store_name, filter);
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
