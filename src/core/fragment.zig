const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const fs = @import("../fs.zig");
const headings = @import("heading.zig");

const Config = @import("../config.zig").Config;
const Manifest = @import("manifest.zig").Manifest;

/// A collection directory (contains manifest and fragments/)
pub const Collection = struct {
    path: []const u8,
    resolved_name: []const u8,

    pub fn init(allocator: mem.Allocator, path: []const u8) !Collection {
        const resolved_name = if (mem.eql(u8, path, "."))
            try resolveCurrentDirName(allocator)
        else
            std.fs.path.basename(path);

        return .{ .path = path, .resolved_name = resolved_name };
    }

    pub fn name(self: Collection) []const u8 {
        return self.resolved_name;
    }

    fn resolveCurrentDirName(allocator: mem.Allocator) ![]const u8 {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = try std.fs.cwd().realpath(".", &buf);
        return allocator.dupe(u8, std.fs.path.basename(cwd));
    }
};

/// A processed fragment ready for output
pub const Fragment = struct {
    heading: []const u8,
    content: []const u8,

    pub const Error = error{
        CollectionNotFound,
        FragmentNotFound,
        FileNotFound,
        ReadError,
    };

    /// A fragment identifier like "fragment" or "other-collection/fragment"
    pub const Id = struct {
        collection: ?[]const u8,
        name: []const u8,
        raw: []const u8,

        pub fn parse(raw: []const u8) Id {
            return parseFragmentId(raw);
        }

        pub fn full(self: Id, allocator: mem.Allocator, current_collection: Collection) ![]const u8 {
            return fullFragmentId(self, allocator, current_collection);
        }
    };

    pub fn resolve(
        allocator: mem.Allocator,
        collection: Collection,
        id: Id,
        config: Config,
    ) ![]const u8 {
        return resolveFragment(allocator, collection, id, config);
    }

    pub fn process(
        allocator: mem.Allocator,
        path: []const u8,
        id: Id,
        collection: Collection,
        manifest: Manifest,
        level: u8,
    ) !Fragment {
        return processFragment(allocator, path, id, collection, manifest, level);
    }
};

fn parseFragmentId(raw: []const u8) Fragment.Id {
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

fn fullFragmentId(id: Fragment.Id, allocator: mem.Allocator, current_collection: Collection) ![]const u8 {
    if (id.collection != null) {
        return id.raw;
    }
    return fmt.allocPrint(allocator, "{s}/{s}", .{ current_collection.name(), id.name });
}

fn resolveFragment(
    allocator: mem.Allocator,
    collection: Collection,
    id: Fragment.Id,
    config: Config,
) ![]const u8 {
    const name_with_ext = try fs.ensureMdExtension(allocator, id.name);

    if (id.collection) |coll| {
        for (config.paths) |base_path| {
            const full_path = try std.fs.path.join(allocator, &.{
                base_path,
                coll,
                Config.fragments_dir,
                name_with_ext,
            });

            if (fs.fileExists(full_path)) {
                return full_path;
            }
        }
        return Fragment.Error.CollectionNotFound;
    } else {
        const full_path = try std.fs.path.join(allocator, &.{
            collection.path,
            Config.fragments_dir,
            name_with_ext,
        });

        if (fs.fileExists(full_path)) {
            return full_path;
        }
        return Fragment.Error.FragmentNotFound;
    }
}

fn processFragment(
    allocator: mem.Allocator,
    path: []const u8,
    id: Fragment.Id,
    collection: Collection,
    manifest: Manifest,
    level: u8,
) !Fragment {
    const content = fs.readFile(allocator, path) catch |err| switch (err) {
        error.FileNotFound => return Fragment.Error.FileNotFound,
        else => return Fragment.Error.ReadError,
    };

    const fragment_id = try id.full(allocator, collection);
    const heading_text = try replaceIdentifier(allocator, manifest.heading_wrapper_template, fragment_id);
    const heading = try formatHeading(allocator, heading_text, level);

    const content_level = @min(level + 1, 6);
    const normalized_content = try headings.normalizeHeadings(allocator, content, content_level);
    const trimmed_content = mem.trim(u8, normalized_content, " \t\n\r");

    return .{
        .heading = heading,
        .content = trimmed_content,
    };
}

fn replaceIdentifier(
    allocator: mem.Allocator,
    template: []const u8,
    ident: []const u8,
) ![]const u8 {
    const variable = "{" ++ Manifest.heading_template_variable_id ++ "}";

    const pos = mem.indexOf(u8, template, variable) orelse {
        return template;
    };

    const before = template[0..pos];
    const after = template[pos + variable.len ..];

    return fmt.allocPrint(allocator, "{s}{s}{s}", .{ before, ident, after });
}

fn formatHeading(allocator: mem.Allocator, text: []const u8, level: u8) ![]const u8 {
    const clamped_level = @min(@max(level, 1), 6);
    const hashes = "######"[0..clamped_level];
    return fmt.allocPrint(allocator, "{s} {s}", .{ hashes, text });
}

test "Collection.name" {
    const collection = try Collection.init(std.testing.allocator, "/home/user/collections/my-collection");
    try std.testing.expectEqualStrings("my-collection", collection.name());
}

test "Fragment.Id.parse local" {
    const id = Fragment.Id.parse("my-fragment");
    try std.testing.expect(id.collection == null);
    try std.testing.expectEqualStrings("my-fragment", id.name);
}

test "Fragment.Id.parse cross-collection" {
    const id = Fragment.Id.parse("other-collection/my-fragment");
    try std.testing.expectEqualStrings("other-collection", id.collection.?);
    try std.testing.expectEqualStrings("my-fragment", id.name);
}

test "Fragment.Id.full local" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const collection = try Collection.init(allocator, "/path/to/my-collection");
    const fragment_id = Fragment.Id.parse("my-fragment");
    const full = try fragment_id.full(allocator, collection);
    try std.testing.expectEqualStrings("my-collection/my-fragment", full);
}

test "Fragment.Id.full cross-collection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const collection = try Collection.init(allocator, "/path/to/current-collection");
    const fragment_id = Fragment.Id.parse("other-collection/my-fragment");
    const full = try fragment_id.full(allocator, collection);
    try std.testing.expectEqualStrings("other-collection/my-fragment", full);
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
    const result = try replaceIdentifier(allocator, "{fragment_id}", "my-collection/my-fragment");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("my-collection/my-fragment", result);
}

test "replaceIdentifier preserves surrounding text" {
    const allocator = std.testing.allocator;
    const result = try replaceIdentifier(allocator, "Title: {fragment_id} (docs)", "db/rule");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Title: db/rule (docs)", result);
}

test "replaceIdentifier no variable" {
    const result = try replaceIdentifier(std.testing.allocator, "Static Title", "ignored");
    try std.testing.expectEqualStrings("Static Title", result);
}
