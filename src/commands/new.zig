const std = @import("std");
const mem = std.mem;
const fs = @import("../fs.zig");
const log = @import("../log.zig");

const Config = @import("../config.zig").Config;
const NewOptions = @import("../cli.zig").NewOptions;

pub const NewError = error{
    CollectionExists,
    CreateFailed,
    NoDefaultStore,
};

pub fn run(allocator: mem.Allocator, options: NewOptions, config: Config) !void {
    const store_path = options.store orelse config.defaultStore() orelse {
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
    try log.info("Creating new collection: {s}", .{collection_path});

    const fragments_path = try std.fs.path.join(allocator, &.{ collection_path, Config.fragments_dir });
    std.fs.cwd().makePath(fragments_path) catch {
        try log.err("Failed to create directory: {s}", .{fragments_path});
        return NewError.CreateFailed;
    };

    if (!no_manifest) {
        const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "manifest" });
        const manifest_content =
            \\[config]
            \\heading_wrapper_template = "{fragment_id}"
            \\
            \\[fragments]
            \\| example
            \\
        ;
        fs.writeFile(manifest_path, manifest_content) catch {
            try log.err("Failed to create manifest: {s}", .{manifest_path});
            return NewError.CreateFailed;
        };
        try log.info("Created: {s}", .{manifest_path});
    }

    const example_path = try std.fs.path.join(allocator, &.{ fragments_path, "example" ++ fs.md_ext });
    const example_content =
        \\## Example
        \\
        \\Add your content here.
        \\
    ;
    fs.writeFile(example_path, example_content) catch {
        try log.err("Failed to create example: {s}", .{example_path});
        return NewError.CreateFailed;
    };
    try log.info("Created: {s}", .{example_path});

    try log.info("", .{});
    try log.info("Next steps:", .{});
    if (!no_manifest) {
        try log.info("  1. Edit {s}/manifest", .{collection_path});
        try log.info("  2. Add fragments to {s}/", .{fragments_path});
        try log.info("  3. Build with: defrag build {s}/manifest", .{collection_path});
    } else {
        try log.info("  1. Add fragments to {s}/", .{fragments_path});
        try log.info("  2. Create a manifest when ready", .{});
    }
}
