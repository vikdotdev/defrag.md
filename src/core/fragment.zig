const std = @import("std");
const path_mod = @import("path.zig");
const heading_mod = @import("heading.zig");
const manifest_mod = @import("manifest.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Collection = path_mod.Collection;
const FragmentRef = path_mod.FragmentRef;
const Manifest = manifest_mod.Manifest;
const heading_wrapper_identifier = manifest_mod.heading_wrapper_identifier;

const max_fragment_size = 10 * 1024 * 1024; // 10MB

pub const FragmentError = error{
    FileNotFound,
    ReadError,
};

/// A processed fragment ready for output
pub const ProcessedFragment = struct {
    heading: []const u8,
    content: []const u8,
};

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
    const content = readFile(allocator, fragment_path) catch |err| switch (err) {
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
    const trimmed_content = std.mem.trim(u8, normalized_content, " \t\n\r");

    return ProcessedFragment{
        .heading = heading,
        .content = trimmed_content,
    };
}

/// Replace {identifier} template variable in heading wrapper template
fn replaceIdentifier(
    allocator: std.mem.Allocator,
    template: []const u8,
    identifier: []const u8,
) ![]const u8 {
    const variable = "{" ++ heading_wrapper_identifier ++ "}";

    const pos = std.mem.indexOf(u8, template, variable) orelse {
        // No variable, return template as-is
        return template;
    };

    const before = template[0..pos];
    const after = template[pos + variable.len ..];

    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ before, identifier, after });
}

/// Format a heading with the given level (e.g., level=2 -> "## text")
fn formatHeading(
    allocator: std.mem.Allocator,
    text: []const u8,
    level: u8,
) ![]const u8 {
    const clamped_level = @min(@max(level, 1), 6);
    const hashes = "######"[0..clamped_level];
    return std.fmt.allocPrint(allocator, "{s} {s}", .{ hashes, text });
}

fn readFile(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, max_fragment_size);
}

// Tests

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
    // No allocation since we return template as-is
    try std.testing.expectEqualStrings("Static Title", result);
}
