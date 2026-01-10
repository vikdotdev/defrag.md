const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const section_config = "[config]";
const section_fragments = "[fragments]";
const key_heading_wrapper_template = "heading_wrapper_template";
pub const heading_wrapper_identifier = "identifier";

pub const ManifestError = error{
    MissingFragmentsSection,
    InvalidNesting,
    EmptyFragmentName,
    TooManyLevels,
};

pub const ManifestConfig = struct {
    /// Heading wrapper template: e.g. "{identifier}" - heading level added automatically from nesting
    heading_wrapper_template: []const u8 = "{" ++ heading_wrapper_identifier ++ "}",
};

/// A single fragment entry from the manifest
pub const FragmentEntry = struct {
    level: u8, // 1-6
    name: []const u8,
    line_number: usize,
};

/// Parsed manifest
pub const Manifest = struct {
    config: ManifestConfig,
    fragments: []const FragmentEntry,
};

/// Parse a manifest file
pub fn parseManifest(arena: *ArenaAllocator, content: []const u8) !Manifest {
    const allocator = arena.allocator();

    var config = ManifestConfig{};
    var fragments: ArrayList(FragmentEntry) = .empty;

    var in_config = false;
    var in_fragments = false;
    var prev_level: u8 = 0;
    var line_number: usize = 0;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        line_number += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Section headers
        if (trimmed.len >= 2 and trimmed[0] == '[') {
            if (std.mem.eql(u8, trimmed, section_config)) {
                in_config = true;
                in_fragments = false;
                continue;
            }
            if (std.mem.eql(u8, trimmed, section_fragments)) {
                in_config = false;
                in_fragments = true;
                continue;
            }
        }

        // Parse options
        if (in_config) {
            if (parseOption(trimmed)) |opt| {
                if (std.mem.eql(u8, opt.key, key_heading_wrapper_template)) {
                    config.heading_wrapper_template = parseConfigValue(opt.value);
                }
            }
            continue;
        }

        // Parse fragments
        if (in_fragments) {
            const entry = try parseFragmentLine(trimmed, line_number, prev_level);
            prev_level = entry.level;
            try fragments.append(allocator, entry);
        }
    }

    if (!in_fragments and fragments.items.len == 0) {
        return ManifestError.MissingFragmentsSection;
    }

    return Manifest{
        .config = config,
        .fragments = fragments.items,
    };
}

const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};

fn parseConfigValue(value: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, value, " \t");
    // Remove quotes if present
    if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
        return trimmed[1 .. trimmed.len - 1];
    }
    return trimmed;
}

fn parseOption(line: []const u8) ?KeyValue {
    const eq_pos = std.mem.indexOf(u8, line, "=") orelse return null;
    return KeyValue{
        .key = std.mem.trim(u8, line[0..eq_pos], " \t"),
        .value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t"),
    };
}

fn parseFragmentLine(line: []const u8, line_number: usize, prev_level: u8) !FragmentEntry {
    // Count leading pipes
    var level: u8 = 0;
    var i: usize = 0;
    while (i < line.len and line[i] == '|') : (i += 1) {
        level += 1;
    }

    if (level == 0) {
        return ManifestError.InvalidNesting;
    }
    if (level > 6) {
        return ManifestError.TooManyLevels;
    }

    // Validate nesting: can only increase by 1
    if (level > prev_level + 1 and prev_level > 0) {
        // Auto-correct to prev_level + 1
        level = prev_level + 1;
    }

    // Extract fragment name
    const name = std.mem.trim(u8, line[i..], " \t");
    if (name.len == 0) {
        return ManifestError.EmptyFragmentName;
    }

    // Strip inline comment
    const comment_pos = std.mem.indexOf(u8, name, "#");
    const clean_name = if (comment_pos) |pos|
        std.mem.trim(u8, name[0..pos], " \t")
    else
        name;

    if (clean_name.len == 0) {
        return ManifestError.EmptyFragmentName;
    }

    return FragmentEntry{
        .level = level,
        .name = clean_name,
        .line_number = line_number,
    };
}

// Tests

test "parseConfigValue with quotes" {
    const template = parseConfigValue("\"{identifier}\"");
    try std.testing.expectEqualStrings("{identifier}", template);
}

test "parseConfigValue without quotes" {
    const template = parseConfigValue("{identifier}");
    try std.testing.expectEqualStrings("{identifier}", template);
}

test "parse simple manifest" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content =
        \\[config]
        \\heading_wrapper_template = "{identifier}"
        \\
        \\[fragments]
        \\| intro
        \\| setup
    ;

    const manifest = try parseManifest(&arena, content);

    try std.testing.expectEqualStrings("{identifier}", manifest.config.heading_wrapper_template);
    try std.testing.expectEqual(@as(usize, 2), manifest.fragments.len);
    try std.testing.expectEqualStrings("intro", manifest.fragments[0].name);
    try std.testing.expectEqual(@as(u8, 1), manifest.fragments[0].level);
}

test "parse nested fragments" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content =
        \\[fragments]
        \\| parent
        \\|| child
        \\||| grandchild
        \\| sibling
    ;

    const manifest = try parseManifest(&arena, content);

    try std.testing.expectEqual(@as(usize, 4), manifest.fragments.len);
    try std.testing.expectEqual(@as(u8, 1), manifest.fragments[0].level);
    try std.testing.expectEqual(@as(u8, 2), manifest.fragments[1].level);
    try std.testing.expectEqual(@as(u8, 3), manifest.fragments[2].level);
    try std.testing.expectEqual(@as(u8, 1), manifest.fragments[3].level);
}

test "parse with comments" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content =
        \\# This is a comment
        \\[fragments]
        \\| intro # inline comment
        \\# another comment
        \\| setup
    ;

    const manifest = try parseManifest(&arena, content);

    try std.testing.expectEqual(@as(usize, 2), manifest.fragments.len);
    try std.testing.expectEqualStrings("intro", manifest.fragments[0].name);
}

test "auto-correct invalid nesting" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content =
        \\[fragments]
        \\| level1
        \\||| level3_after_1
    ;

    const manifest = try parseManifest(&arena, content);

    try std.testing.expectEqual(@as(u8, 1), manifest.fragments[0].level);
    try std.testing.expectEqual(@as(u8, 2), manifest.fragments[1].level); // corrected from 3 to 2
}

test "missing fragments section" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const content =
        \\[config]
        \\title = "{name}"
    ;

    const result = parseManifest(&arena, content);
    try std.testing.expectError(ManifestError.MissingFragmentsSection, result);
}
