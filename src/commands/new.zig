const std = @import("std");
const mem = std.mem;
const paths = @import("../paths.zig");
const log = @import("../log.zig");

const Config = @import("../config.zig").Config;
const NewOptions = @import("../cli.zig").NewOptions;

pub const NewError = error{
    CollectionExists,
    CreateFailed,
    NoDefaultStore,
};

pub fn printHelp(version: []const u8) !void {
    try log.info(
        \\
        \\Usage: defrag new <collection_name> [options]
        \\
        \\Create a new collection.
        \\
        \\Arguments:
        \\    <collection_name>  Name of the collection to create (required)
        \\
        \\Options:
        \\    -c, --collection   Collection name (alternative to positional)
        \\    -s, --store <name> Use specific store
        \\    --no-manifest      Don't create a manifest file
        \\    --config <path>    Path to config file
        \\
        \\Examples:
        \\    defrag new my-collection
        \\    defrag new my-collection --store my-store
        \\    defrag new my-collection --no-manifest
        \\
        \\Version: {s}
    , .{version});
}

pub fn run(allocator: mem.Allocator, options: NewOptions, config: Config) !void {
    const store_path = if (options.store) |filter|
        resolveStore(config, filter) orelse {
            try log.err("Store not found: {s}", .{filter});
            return NewError.NoDefaultStore;
        }
    else
        config.defaultStore() orelse {
            try log.err("No default store configured", .{});
            return NewError.NoDefaultStore;
        };

    const collection_path = try std.fs.path.join(allocator, &.{
        store_path,
        Config.collections_dir,
        options.collection_name,
    });

    std.fs.cwd().access(collection_path, .{}) catch {
        return createCollection(allocator, collection_path, options.no_manifest);
    };

    try log.err("Collection '{s}' already exists", .{collection_path});
    return NewError.CollectionExists;
}

fn createCollection(
    allocator: mem.Allocator,
    collection_path: []const u8,
    no_manifest: bool,
) !void {
    const fragments_path = try std.fs.path.join(allocator, &.{ collection_path, Config.fragments_dir });
    std.fs.cwd().makePath(fragments_path) catch {
        try log.err("Failed to create directory: {s}", .{fragments_path});
        return NewError.CreateFailed;
    };

    if (!no_manifest) {
        const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "default" ++ Config.manifest_ext });
        const manifest_content =
            \\[config]
            \\heading_wrapper_template = "{fragment_id}"
            \\
            \\[fragments]
            \\| example
            \\
        ;
        paths.writeFile(manifest_path, manifest_content) catch {
            try log.err("Failed to create manifest: {s}", .{manifest_path});
            return NewError.CreateFailed;
        };
        try log.info("Created: {s}", .{manifest_path});
    }

    const example_path = try std.fs.path.join(allocator, &.{ fragments_path, "example" ++ paths.md_ext });
    const example_content =
        \\## Example
        \\
        \\Add your content here.
        \\
    ;
    paths.writeFile(example_path, example_content) catch {
        try log.err("Failed to create example: {s}", .{example_path});
        return NewError.CreateFailed;
    };
    try log.info("Created: {s}", .{example_path});
}

fn resolveStore(config: Config, filter: []const u8) ?[]const u8 {
    for (config.stores) |store| {
        const store_name = std.fs.path.basename(store.path);
        if (mem.eql(u8, store_name, filter)) return store.path;
    }
    return null;
}
