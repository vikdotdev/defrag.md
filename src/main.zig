const std = @import("std");
const cli = @import("cli.zig");
const build_cmd = @import("commands/build.zig");
const validate_cmd = @import("commands/validate.zig");
const new_cmd = @import("commands/new.zig");
const init_cmd = @import("commands/init.zig");
const build_link_cmd = @import("commands/build_link.zig");
const fs = @import("fs.zig");
const log = @import("log.zig");
const manifest = @import("core/manifest.zig");
const heading = @import("core/heading.zig");
const fragment = @import("core/fragment.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = @import("config.zig").Config;

const version = "0.1.0";

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    const parse_result = cli.parseArgs(args) catch |parse_err| {
        try printError(parse_err);
        std.process.exit(1);
    };

    if (parse_result.command == .help) {
        try printUsage();
        return;
    }

    const allocator = arena.allocator();

    if (parse_result.command == .init) {
        init_cmd.run(allocator, parse_result.command.init) catch {
            std.process.exit(1);
        };
        return;
    }

    const config = if (parse_result.config_path) |path|
        Config.loadFromPath(allocator, path)
    else
        Config.load(allocator);

    const loaded_config = config catch |load_err| {
        try log.err("Failed to load config: {}", .{load_err});
        std.process.exit(1);
    };

    switch (parse_result.command) {
        .build => |opts| {
            build_cmd.run(allocator, opts, loaded_config) catch {
                std.process.exit(1);
            };
        },
        .validate => |opts| {
            validate_cmd.run(allocator, opts, loaded_config) catch {
                std.process.exit(1);
            };
        },
        .new => |opts| {
            new_cmd.run(allocator, opts, loaded_config) catch {
                std.process.exit(1);
            };
        },
        .build_link => |opts| {
            build_link_cmd.run(allocator, opts, loaded_config) catch {
                std.process.exit(1);
            };
        },
        .init => unreachable,
        .help => unreachable,
    }
}

fn printUsage() !void {
    const usage =
        \\defrag - Build and manage AI instruction rulesets
        \\
        \\Usage:
        \\    defrag <command> [options]
        \\
        \\Commands:
        \\    build       Build documentation from a manifest
        \\    validate    Validate a manifest
        \\    new         Create a new collection
        \\    init        Create a new store
        \\    build-link  Build and symlink output
        \\    help        Show this help message
        \\
        \\Examples:
        \\    defrag build path/to/manifest
        \\    defrag build --manifest path/to/manifest --out output.md
        \\    defrag build --all --config custom/config.json
        \\    defrag new my-collection
        \\    defrag init ~/my-store
        \\
        \\Version:
    ;
    try log.info("{s} {s}", .{ usage, version });
}

fn printError(parse_err: cli.ParseError) !void {
    switch (parse_err) {
        cli.ParseError.MissingCommand => {
            try log.err("Missing command", .{});
            try printUsage();
        },
        cli.ParseError.UnknownCommand => {
            try log.err("Unknown command", .{});
            try printUsage();
        },
        cli.ParseError.MissingArgument => {
            try log.err("Missing required argument", .{});
        },
        cli.ParseError.UnknownOption => {
            try log.err("Unknown option", .{});
        },
    }
}

test {
    _ = @import("config.zig");
    _ = @import("testing.zig");
    _ = cli;
    _ = log;
    _ = build_cmd;
    _ = validate_cmd;
    _ = new_cmd;
    _ = init_cmd;
    _ = build_link_cmd;
    _ = fs;
    _ = manifest;
    _ = heading;
    _ = fragment;
}

// ============================================================================
// Integration Tests
// ============================================================================

const t = @import("testing.zig");

// Build command tests

test "build: basic - simple manifest with 2 rules" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-basic.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/basic/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try result.expectStderrContains("Built:");
    try t.expectFileContains(allocator, output, "# basic/rule1");
    try t.expectFileContains(allocator, output, "# basic/rule2");
}

test "build: comment handling - manifest comments ignored" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-comments.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/basic/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileNotContains(allocator, output, "commented-rule");
}

test "build: code blocks preserved" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-code-blocks.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/with_code_blocks/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "```");
    try t.expectFileContains(allocator, output, "def hello():");
}

test "build: no EOF newline handled" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-no-eof.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/no_eof_newline/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: nested 2 levels" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-nested.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/nested/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "# nested/parent");
    try t.expectFileContains(allocator, output, "## nested/child1");
    try t.expectFileContains(allocator, output, "## nested/child2");
}

test "build: nested complex 3 levels" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-nested-complex.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/nested_complex/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "# nested_complex/");
    try t.expectFileContains(allocator, output, "## nested_complex/");
    try t.expectFileContains(allocator, output, "### nested_complex/");
}

test "build: missing manifest error" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-missing-manifest.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/nonexistent/manifest", output);
    defer result.deinit();

    try result.expectFailure();
    try result.expectStderrContains("Manifest file not found");
    try t.expectFileNotExists(output);
}

test "build: missing rule warns but continues" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-missing-rule.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/missing_rule/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "missing_rule/existing-rule");
}

test "build: invalid nesting auto-corrects" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-invalid-nesting.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/invalid_nesting/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "invalid_nesting/parent");
    try t.expectFileContains(allocator, output, "invalid_nesting/deep-child");
}

test "build: too many levels error" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-too-many-levels.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/too_many_levels/manifest", output);
    defer result.deinit();

    try result.expectFailure();
}

test "build: cross-collection inclusion" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-cross-db.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.buildWithConfig(
        allocator,
        "fixtures/config.json",
        "fixtures/collections/collection_inclusion/manifest",
        output,
    );
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "collection_inclusion/local-rule");
    try t.expectFileContains(allocator, output, "basic/rule1");
}

test "build: nesting warning" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-nesting-warning.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/nesting_warning/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: multiple level jumps" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-multi-jump.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/multiple_level_jumps/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: auto-create build dir" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "auto-create-subdir/output.md");
    defer allocator.free(output);
    defer t.cleanupDir("zig-out/defragtest/auto-create-subdir");

    var result = try t.build(allocator, "fixtures/collections/basic/manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

// Validate command tests

test "validate: basic - valid manifest passes" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/basic/manifest");
    defer result.deinit();

    try result.expectSuccess();
    try result.expectStderrContains("is valid!");
}

test "validate: missing manifest error" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/nonexistent/manifest");
    defer result.deinit();

    try result.expectFailure();
}

test "validate: missing rule reports error" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/missing_rule/manifest");
    defer result.deinit();

    try result.expectFailure();
}

test "validate: nested fragments" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/invalid_nesting/manifest");
    defer result.deinit();

    try result.expectSuccess();
}

// New command tests

test "new: basic creation" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-new-store");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    var result = try t.new(allocator, "my-collection", store_path);
    defer result.deinit();

    try result.expectSuccess();

    const collection_path = try std.fs.path.join(allocator, &.{ store_path, "collections", "my-collection" });
    defer allocator.free(collection_path);
    try t.expectDirExists(collection_path);

    const fragments_dir = try std.fs.path.join(allocator, &.{ collection_path, "fragments" });
    defer allocator.free(fragments_dir);
    try t.expectDirExists(fragments_dir);

    const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "manifest" });
    defer allocator.free(manifest_path);
    try t.expectFileExists(manifest_path);

    const example_path = try std.fs.path.join(allocator, &.{ fragments_dir, "example.md" });
    defer allocator.free(example_path);
    try t.expectFileExists(example_path);
}

test "new: missing collection name error" {
    const allocator = std.testing.allocator;

    var result = try t.runDefrag(allocator, &.{"new"});
    defer result.deinit();

    try result.expectFailure();
}

test "new: collection exists error" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-exists-store");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    const collection_path = try std.fs.path.join(allocator, &.{ store_path, "collections", "existing" });
    defer allocator.free(collection_path);
    try std.fs.cwd().makePath(collection_path);

    var result = try t.new(allocator, "existing", store_path);
    defer result.deinit();

    try result.expectFailure();
}

test "new: no-manifest option" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-no-manifest-store");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    var result = try t.newNoManifest(allocator, "no-manifest-collection", store_path);
    defer result.deinit();

    try result.expectSuccess();

    const collection_path = try std.fs.path.join(allocator, &.{ store_path, "collections", "no-manifest-collection" });
    defer allocator.free(collection_path);
    try t.expectDirExists(collection_path);

    const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "manifest" });
    defer allocator.free(manifest_path);
    try t.expectFileNotExists(manifest_path);
}

// Init command tests

test "init: creates store structure" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-init-store");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    const config_path = try t.tmpPath(allocator, "test-init-config.json");
    defer allocator.free(config_path);
    defer t.cleanup(config_path);

    var result = try t.init(allocator, store_path, config_path);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectDirExists(store_path);

    const collections_dir = try std.fs.path.join(allocator, &.{ store_path, "collections" });
    defer allocator.free(collections_dir);
    try t.expectDirExists(collections_dir);

    const build_dir = try std.fs.path.join(allocator, &.{ store_path, "build" });
    defer allocator.free(build_dir);
    try t.expectDirExists(build_dir);
}

test "init: creates gitignore" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-init-gitignore");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    const config_path = try t.tmpPath(allocator, "test-init-gitignore-config.json");
    defer allocator.free(config_path);
    defer t.cleanup(config_path);

    var result = try t.init(allocator, store_path, config_path);
    defer result.deinit();

    try result.expectSuccess();

    const gitignore_path = try std.fs.path.join(allocator, &.{ store_path, ".gitignore" });
    defer allocator.free(gitignore_path);
    try t.expectFileExists(gitignore_path);
    try t.expectFileContains(allocator, gitignore_path, "build/");
}

test "init: creates config file" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-init-config-create");
    defer allocator.free(store_path);
    defer t.cleanupDir(store_path);

    const config_path = try t.tmpPath(allocator, "test-init-new-config.json");
    defer allocator.free(config_path);
    defer t.cleanup(config_path);

    var result = try t.init(allocator, store_path, config_path);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(config_path);
    try t.expectFileContains(allocator, config_path, "stores");
    try t.expectFileContains(allocator, config_path, "default");
}

test "init: store already exists error" {
    const allocator = std.testing.allocator;
    const store_path = try t.tmpPath(allocator, "test-init-exists");
    defer allocator.free(store_path);

    try std.fs.cwd().makePath(store_path);
    defer t.cleanupDir(store_path);

    const config_path = try t.tmpPath(allocator, "test-init-exists-config.json");
    defer allocator.free(config_path);
    defer t.cleanup(config_path);

    var result = try t.init(allocator, store_path, config_path);
    defer result.deinit();

    try result.expectFailure();
    try result.expectStderrContains("already exists");
}
