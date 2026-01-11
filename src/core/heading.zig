const std = @import("std");
const c = @cImport(@cInclude("cmark.h"));

const ArenaAllocator = std.heap.ArenaAllocator;

const max_heading_level = 6;

/// Normalize headings in markdown content to start at target_level.
/// Uses cmark for proper CommonMark parsing.
/// Returns modified markdown with adjusted heading levels.
pub fn normalizeHeadings(arena: *ArenaAllocator, content: []const u8, target_level: u8) ![]const u8 {
    const allocator = arena.allocator();

    // Parse document
    const doc = c.cmark_parse_document(content.ptr, content.len, c.CMARK_OPT_DEFAULT) orelse {
        return content; // Parse failed, return as-is
    };
    defer c.cmark_node_free(doc);

    // Pass 1: Find minimum heading level
    const min_level = findMinHeadingLevel(doc);
    if (min_level == 0) {
        return content; // No headings found
    }

    // Calculate shift
    const shift: i32 = @as(i32, target_level) - @as(i32, min_level);
    if (shift == 0) {
        return content;
    }

    // Pass 2: Adjust all heading levels
    adjustHeadingLevels(doc, shift);

    // Render back to CommonMark
    const rendered = c.cmark_render_commonmark(doc, c.CMARK_OPT_DEFAULT, 0);
    if (rendered == null) {
        return content;
    }
    defer std.c.free(rendered);

    // Copy to arena-allocated memory
    const len = std.mem.len(rendered);
    const result = try allocator.alloc(u8, len);
    @memcpy(result, rendered[0..len]);

    return result;
}

fn findMinHeadingLevel(doc: *c.cmark_node) u8 {
    var min_level: u8 = max_heading_level + 1;

    const iter = c.cmark_iter_new(doc);
    defer c.cmark_iter_free(iter);

    while (c.cmark_iter_next(iter) != c.CMARK_EVENT_DONE) {
        const node = c.cmark_iter_get_node(iter);
        if (c.cmark_node_get_type(node) == c.CMARK_NODE_HEADING) {
            const level: u8 = @intCast(c.cmark_node_get_heading_level(node));
            if (level < min_level) {
                min_level = level;
            }
        }
    }

    return if (min_level > max_heading_level) 0 else min_level;
}

fn adjustHeadingLevels(doc: *c.cmark_node, shift: i32) void {
    const iter = c.cmark_iter_new(doc);
    defer c.cmark_iter_free(iter);

    var ev = c.cmark_iter_next(iter);
    while (ev != c.CMARK_EVENT_DONE) : (ev = c.cmark_iter_next(iter)) {
        // Only process on ENTER, not EXIT
        if (ev != c.CMARK_EVENT_ENTER) continue;

        const node = c.cmark_iter_get_node(iter);
        if (c.cmark_node_get_type(node) == c.CMARK_NODE_HEADING) {
            const current = c.cmark_node_get_heading_level(node);
            var new_level = current + shift;

            // Clamp to valid range
            if (new_level < 1) new_level = 1;
            if (new_level > max_heading_level) new_level = max_heading_level;

            _ = c.cmark_node_set_heading_level(node, @intCast(new_level));
        }
    }
}

test "normalizeHeadings no change needed" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "# Heading\n\nSome text\n";
    const result = try normalizeHeadings(&arena, content, 1);
    try std.testing.expect(std.mem.indexOf(u8, result, "# Heading") != null);
}

test "normalizeHeadings shift up" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "# Heading\n\n## Subheading\n";
    const result = try normalizeHeadings(&arena, content, 2);
    try std.testing.expect(std.mem.indexOf(u8, result, "## Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "### Subheading") != null);
}

test "normalizeHeadings shift down" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "### Heading\n\n#### Subheading\n";
    const result = try normalizeHeadings(&arena, content, 1);
    try std.testing.expect(std.mem.indexOf(u8, result, "# Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "## Subheading") != null);
}

test "normalizeHeadings clamp to H6" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "# Heading\n\n## Subheading\n";
    const result = try normalizeHeadings(&arena, content, 6);
    try std.testing.expect(std.mem.indexOf(u8, result, "###### Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "###### Subheading") != null);
}

test "normalizeHeadings handles setext headings" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "Heading\n=======\n\nSubheading\n----------\n";
    const result = try normalizeHeadings(&arena, content, 2);
    // cmark converts setext to ATX in output
    try std.testing.expect(std.mem.indexOf(u8, result, "## Heading") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "### Subheading") != null);
}

test "normalizeHeadings no headings" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content = "Just some text\n\nNo headings here\n";
    const result = try normalizeHeadings(&arena, content, 2);
    try std.testing.expectEqualStrings(content, result);
}
