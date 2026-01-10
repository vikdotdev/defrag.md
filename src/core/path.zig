const std = @import("std");
const config_mod = @import("../config.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = config_mod.Config;
const fragments_dir = config_mod.fragments_dir;
const md_ext = config_mod.md_ext;

pub const PathError = error{
    CollectionNotFound,
    FragmentNotFound,
};

/// A collection directory (contains manifest and fragments/)
pub const Collection = struct {
    path: []const u8,

    pub fn init(path: []const u8) Collection {
        return .{ .path = path };
    }

    pub fn name(self: Collection) []const u8 {
        return std.fs.path.basename(self.path);
    }
};

/// A fragment reference like "fragment" or "other-collection/fragment"
pub const FragmentRef = struct {
    collection: ?[]const u8, // null for local fragments
    name: []const u8,
    raw: []const u8, // original string

    pub fn parse(raw: []const u8) FragmentRef {
        if (std.mem.indexOf(u8, raw, "/")) |slash_pos| {
            return .{
                .collection = raw[0..slash_pos],
                .name = raw[slash_pos + 1 ..],
                .raw = raw,
            };
        }
        return .{
            .collection = null,
            .name = raw,
            .raw = raw,
        };
    }

    /// Returns full "collection/name" identifier (always includes collection)
    pub fn identifier(self: FragmentRef, arena: *ArenaAllocator, current_collection: Collection) ![]const u8 {
        if (self.collection != null) {
            // Cross-collection: already has collection/name format
            return self.raw;
        }
        // Local: prepend current collection name
        return std.fmt.allocPrint(arena.allocator(), "{s}/{s}", .{ current_collection.name(), self.name });
    }
};

/// Ensure path has .md extension
pub fn ensureMdExtension(arena: *ArenaAllocator, path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, path, md_ext)) {
        return path;
    }
    return std.fmt.allocPrint(arena.allocator(), "{s}" ++ md_ext, .{path});
}

/// Resolve a fragment path to its full filesystem path
pub fn resolveFragmentPath(
    arena: *ArenaAllocator,
    collection: Collection,
    ref: FragmentRef,
    config: Config,
) ![]const u8 {
    const allocator = arena.allocator();
    const name_with_ext = try ensureMdExtension(arena, ref.name);

    if (ref.collection) |coll| {
        // Cross-collection reference: search config paths
        for (config.paths) |base_path| {
            const full_path = try std.fs.path.join(allocator, &.{
                base_path,
                coll,
                fragments_dir,
                name_with_ext,
            });

            if (fileExists(full_path)) {
                return full_path;
            }
        }
        return PathError.CollectionNotFound;
    } else {
        // Local fragment: relative to collection directory
        const full_path = try std.fs.path.join(allocator, &.{
            collection.path,
            fragments_dir,
            name_with_ext,
        });

        if (fileExists(full_path)) {
            return full_path;
        }
        return PathError.FragmentNotFound;
    }
}

fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

// Tests

test "FragmentRef.parse local" {
    const ref = FragmentRef.parse("my-fragment");
    try std.testing.expect(ref.collection == null);
    try std.testing.expectEqualStrings("my-fragment", ref.name);
}

test "FragmentRef.parse cross-collection" {
    const ref = FragmentRef.parse("other-collection/my-fragment");
    try std.testing.expectEqualStrings("other-collection", ref.collection.?);
    try std.testing.expectEqualStrings("my-fragment", ref.name);
}

test "FragmentRef.identifier local" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const collection = Collection.init("/path/to/my-collection");
    const ref = FragmentRef.parse("my-fragment");
    const id = try ref.identifier(&arena, collection);
    try std.testing.expectEqualStrings("my-collection/my-fragment", id);
}

test "FragmentRef.identifier cross-collection" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const collection = Collection.init("/path/to/current-collection");
    const ref = FragmentRef.parse("other-collection/my-fragment");
    const id = try ref.identifier(&arena, collection);
    try std.testing.expectEqualStrings("other-collection/my-fragment", id);
}

test "ensureMdExtension without extension" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const result = try ensureMdExtension(&arena, "fragment");
    try std.testing.expectEqualStrings("fragment.md", result);
}

test "ensureMdExtension with extension" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const result = try ensureMdExtension(&arena, "fragment.md");
    try std.testing.expectEqualStrings("fragment.md", result);
}

test "Collection.name" {
    const collection = Collection.init("/home/user/collections/my-collection");
    try std.testing.expectEqualStrings("my-collection", collection.name());
}
