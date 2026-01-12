const std = @import("std");
const fs = @import("../fs.zig");
const log = @import("../log.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = @import("../config.zig").Config;
const NewOptions = @import("../cli.zig").NewOptions;

pub const NewError = error{
    CollectionExists,
    CreateFailed,
};

pub fn run(arena: *ArenaAllocator, options: NewOptions) !void {
    const collection_name = options.collection_name;

    // Check if collection already exists
    std.fs.cwd().access(collection_name, .{}) catch {
        // Doesn't exist, good
        return createCollection(arena, collection_name, options.no_manifest);
    };

    try log.err("Collection '{s}' already exists", .{collection_name});
    return NewError.CollectionExists;
}

fn createCollection(arena: *ArenaAllocator, collection_name: []const u8, no_manifest: bool) !void {
    const allocator = arena.allocator();

    try log.info("Creating new collection: {s}", .{collection_name});

    // Create fragments directory
    const fragments_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ collection_name, Config.fragments_dir },
    );
    std.fs.cwd().makePath(fragments_path) catch {
        try log.err("Failed to create directory: {s}", .{fragments_path});
        return NewError.CreateFailed;
    };

    // Create manifest (unless --no-manifest)
    if (!no_manifest) {
        const manifest_path = try std.fmt.allocPrint(
            allocator,
            "{s}/default{s}",
            .{ collection_name, Config.manifest_ext },
        );
        const manifest_content =
            \\[config]
            \\heading_wrapper_template = "# Rule: {fragment_id}"
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

    // Create example fragment
    const example_path = try std.fmt.allocPrint(
        allocator,
        "{s}/example{s}",
        .{ fragments_path, fs.md_ext },
    );
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
        try log.info("  1. Edit {s}/default{s}", .{ collection_name, Config.manifest_ext });
        try log.info("  2. Add fragments to {s}/", .{fragments_path});
        try log.info("  3. Build with: defrag build {s}/default{s}", .{ collection_name, Config.manifest_ext });
    } else {
        try log.info("  1. Add fragments to {s}/", .{fragments_path});
        try log.info("  2. Create a manifest when ready", .{});
    }
}
