const std = @import("std");
const config_mod = @import("../config.zig");
const fs = @import("fs.zig");
const heading_mod = @import("heading.zig");
const manifest_mod = @import("manifest.zig");

const mem = std.mem;
const fmt = std.fmt;
const ArenaAllocator = std.heap.ArenaAllocator;
const Config = config_mod.Config;
const Manifest = manifest_mod.Manifest;
const fragments_dir = config_mod.fragments_dir;
const heading_wrapper_identifier = manifest_mod.heading_wrapper_identifier;

pub const FragmentError = error{
    CollectionNotFound,
    FragmentNotFound,
    FileNotFound,
    ReadError,
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
        if (mem.indexOf(u8, raw, "/")) |slash_pos| {
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
            return self.raw;
        }
        return fmt.allocPrint(arena.allocator(), "{s}/{s}", .{ current_collection.name(), self.name });
    }
};

/// A processed fragment ready for output
pub const ProcessedFragment = struct {
    heading: []const u8,
    content: []const u8,
};

/// Resolve a fragment reference to its full filesystem path
pub fn resolveFragmentPath(
    arena: *ArenaAllocator,
    collection: Collection,
    ref: FragmentRef,
    config: Config,
) ![]const u8 {
    const allocator = arena.allocator();
    const name_with_ext = try fs.ensureMdExtension(allocator, ref.name);

    if (ref.collection) |coll| {
        // Cross-collection reference: search config paths
        for (config.paths) |base_path| {
            const full_path = try std.fs.path.join(allocator, &.{
                base_path,
                coll,
                fragments_dir,
                name_with_ext,
            });

            if (fs.fileExists(full_path)) {
                return full_path;
            }
        }
        return FragmentError.CollectionNotFound;
    } else {
        // Local fragment: relative to collection directory
        const full_path = try std.fs.path.join(allocator, &.{
            collection.path,
            fragments_dir,
            name_with_ext,
        });

        if (fs.fileExists(full_path)) {
            return full_path;
        }
        return FragmentError.FragmentNotFound;
    }
}

/// Load and process a fragment file
pub fn processFragment(
    arena: *ArenaAllocator,
    fragment_path: []const u8,
    fragment_ref: FragmentRef,
    collection: Collection,
    manifest: Manifest,
    level: u8,
) !ProcessedFragment {
    const allocator = arena.allocator();

    // Read fragment file
    const content = fs.readFile(allocator, fragment_path) catch |err| switch (err) {
        error.FileNotFound => return FragmentError.FileNotFound,
        else => return FragmentError.ReadError,
    };

    // Generate heading wrapper
    const identifier = try fragment_ref.identifier(arena, collection);
    const heading_text = try replaceIdentifier(allocator, manifest.heading_wrapper_template, identifier);
    const heading = try formatHeading(allocator, heading_text, level);

    // Normalize content headings (nested one level under wrapper)
    const content_level = @min(level + 1, 6);
    const normalized_content = try heading_mod.normalizeHeadings(arena, content, content_level);

    // Trim leading/trailing whitespace from content
    const trimmed_content = mem.trim(u8, normalized_content, " \t\n\r");

    return ProcessedFragment{
        .heading = heading,
        .content = trimmed_content,
    };
}

/// Replace {identifier} template variable in heading wrapper template
fn replaceIdentifier(
    allocator: mem.Allocator,
    template: []const u8,
    identifier: []const u8,
) ![]const u8 {
    const variable = "{" ++ heading_wrapper_identifier ++ "}";

    const pos = mem.indexOf(u8, template, variable) orelse {
        return template;
    };

    const before = template[0..pos];
    const after = template[pos + variable.len ..];

    return fmt.allocPrint(allocator, "{s}{s}{s}", .{ before, identifier, after });
}

/// Format a heading with the given level (e.g., level=2 -> "## text")
fn formatHeading(allocator: mem.Allocator, text: []const u8, level: u8) ![]const u8 {
    const clamped_level = @min(@max(level, 1), 6);
    const hashes = "######"[0..clamped_level];
    return fmt.allocPrint(allocator, "{s} {s}", .{ hashes, text });
}

// Tests

test "Collection.name" {
    const collection = Collection.init("/home/user/collections/my-collection");
    try std.testing.expectEqualStrings("my-collection", collection.name());
}

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

test "formatHeading level 1" {
    const allocator = std.testing.allocator;
    const result = try formatHeading(allocator, "Test", 1);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("# Test", result);
}

test "formatHeading level 3" {
    const allocator = std.testing.allocator;
    const result = try formatHeading(allocator, "Test", 3);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("### Test", result);
}

test "formatHeading clamp to 6" {
    const allocator = std.testing.allocator;
    const result = try formatHeading(allocator, "Test", 10);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("###### Test", result);
}

test "replaceIdentifier basic" {
    const allocator = std.testing.allocator;
    const result = try replaceIdentifier(allocator, "{identifier}", "my-collection/my-fragment");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("my-collection/my-fragment", result);
}

test "replaceIdentifier with prefix" {
    const allocator = std.testing.allocator;
    const result = try replaceIdentifier(allocator, "Rule: {identifier}", "db/rule");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Rule: db/rule", result);
}

test "replaceIdentifier no variable" {
    const result = try replaceIdentifier(std.testing.allocator, "Static Title", "ignored");
    try std.testing.expectEqualStrings("Static Title", result);
}
