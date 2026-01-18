const std = @import("std");
const mem = std.mem;
const build_options = @import("build_options");
const cli = @import("cli.zig");
const build_cmd = @import("commands/build.zig");
const validate_cmd = @import("commands/validate.zig");
const new_cmd = @import("commands/new.zig");
const init_cmd = @import("commands/init.zig");
const build_link_cmd = @import("commands/build_link.zig");
const help_cmd = @import("commands/help.zig");
const paths = @import("paths.zig");
const log = @import("log.zig");
const manifest = @import("core/manifest.zig");
const heading = @import("core/heading.zig");
const fragment = @import("core/fragment.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = @import("config.zig").Config;

const version = build_options.version;

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(arena.allocator());
    var parse_ctx = cli.ParseContext{};
    const parse_result = cli.parseArgs(args, &parse_ctx) catch |parse_err| {
        try printError(parse_err, parse_ctx);
        const exit_code: u8 = if (parse_err == cli.ParseError.HelpRequested) 0 else 1;
        std.process.exit(exit_code);
    };

    if (parse_result.command == .help) {
        try help_cmd.printHelp(version);
        return;
    }

    if (parse_result.command == .init) {
        init_cmd.run(allocator, parse_result.command.init) catch {
            std.process.exit(1);
        };
        return;
    }

    const config = Config.loadWithPath(allocator, parse_result.config_path) catch |err| {
        try log.err("Failed to load config: {}", .{err});
        std.process.exit(1);
    };

    switch (parse_result.command) {
        .build => |opts| {
            build_cmd.run(allocator, opts, config) catch {
                std.process.exit(1);
            };
        },
        .validate => |opts| {
            validate_cmd.run(allocator, opts, config) catch {
                std.process.exit(1);
            };
        },
        .new => |opts| {
            new_cmd.run(allocator, opts, config) catch {
                std.process.exit(1);
            };
        },
        .build_link => |opts| {
            build_link_cmd.run(allocator, opts, config) catch {
                std.process.exit(1);
            };
        },
        .init => unreachable,
        .help => unreachable,
    }
}

fn printError(parse_err: cli.ParseError, parse_ctx: cli.ParseContext) !void {
    switch (parse_err) {
        cli.ParseError.MissingCommand => {
            try log.err("Missing command", .{});
            try help_cmd.printHelp(version);
        },
        cli.ParseError.UnknownCommand => {
            try log.err("Unknown command: {s}", .{parse_ctx.command_name orelse "unknown"});
            try help_cmd.printHelp(version);
        },
        cli.ParseError.MissingPositional => {
            if (parse_ctx.missing_arg) |arg| {
                try log.err("Missing argument: <{s}>", .{arg});
            } else {
                try log.err("Missing required argument", .{});
            }
            if (parse_ctx.command_name) |cmd| {
                try printCommandHelp(cmd);
            }
        },
        cli.ParseError.MissingOptionValue => {
            if (parse_ctx.missing_arg) |arg| {
                try log.err("Missing value for {s}", .{arg});
            } else {
                try log.err("Missing option value", .{});
            }
            if (parse_ctx.command_name) |cmd| {
                try printCommandHelp(cmd);
            }
        },
        cli.ParseError.MissingOption => {
            if (parse_ctx.missing_arg) |arg| {
                try log.err("Missing option: {s}", .{arg});
            } else {
                try log.err("Missing required option", .{});
            }
            if (parse_ctx.command_name) |cmd| {
                try printCommandHelp(cmd);
            }
        },
        cli.ParseError.UnknownOption => {
            if (parse_ctx.bad_option) |opt| {
                try log.err("Unknown option: {s}", .{opt});
            } else {
                try log.err("Unknown option", .{});
            }
            if (parse_ctx.command_name) |cmd| {
                try printCommandHelp(cmd);
            }
        },
        cli.ParseError.HelpRequested => {
            if (parse_ctx.command_name) |cmd| {
                try printCommandHelp(cmd);
            } else {
                try help_cmd.printHelp(version);
            }
        },
    }
}

fn printCommandHelp(command: []const u8) !void {
    if (mem.eql(u8, command, "init")) {
        try init_cmd.printHelp(version);
    } else if (mem.eql(u8, command, "build")) {
        try build_cmd.printHelp(version);
    } else if (mem.eql(u8, command, "validate")) {
        try validate_cmd.printHelp(version);
    } else if (mem.eql(u8, command, "new")) {
        try new_cmd.printHelp(version);
    } else if (mem.eql(u8, command, "build-link")) {
        try build_link_cmd.printHelp(version);
    } else {
        try help_cmd.printHelp(version);
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
    _ = help_cmd;
    _ = build_link_cmd;
    _ = paths;
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

    var result = try t.build(allocator, "fixtures/collections/basic/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/basic/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileNotContains(allocator, output, "commented-rule");
}

test "build: code blocks preserved" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-code-blocks.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/with_code_blocks/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/no_eof_newline/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: nested 2 levels" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-nested.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/nested/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/nested_complex/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/nonexistent/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/missing_rule/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileContains(allocator, output, "missing_rule/existing-rule");
}

test "build: invalid nesting auto-corrects" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-invalid-nesting.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/invalid_nesting/default.manifest", output);
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

    var result = try t.build(allocator, "fixtures/collections/too_many_levels/default.manifest", output);
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
        "fixtures/collections/collection_inclusion/default.manifest",
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

    var result = try t.build(allocator, "fixtures/collections/nesting_warning/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: multiple level jumps" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "e2e-build-multi-jump.md");
    defer allocator.free(output);
    defer t.cleanup(output);

    var result = try t.build(allocator, "fixtures/collections/multiple_level_jumps/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

test "build: auto-create build dir" {
    const allocator = std.testing.allocator;
    const output = try t.tmpPath(allocator, "auto-create-subdir/output.md");
    defer allocator.free(output);
    defer t.cleanupDir("zig-out/defragtest/auto-create-subdir");

    var result = try t.build(allocator, "fixtures/collections/basic/default.manifest", output);
    defer result.deinit();

    try result.expectSuccess();
    try t.expectFileExists(output);
}

// Validate command tests

test "validate: basic - valid manifest passes" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/basic/default.manifest");
    defer result.deinit();

    try result.expectSuccess();
    try result.expectStderrContains("is valid!");
}

test "validate: missing manifest error" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/nonexistent/default.manifest");
    defer result.deinit();

    try result.expectFailure();
}

test "validate: missing rule reports error" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/missing_rule/default.manifest");
    defer result.deinit();

    try result.expectFailure();
}

test "validate: nested fragments" {
    const allocator = std.testing.allocator;

    var result = try t.validate(allocator, "fixtures/collections/invalid_nesting/default.manifest");
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

    const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "default.manifest" });
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

    const manifest_path = try std.fs.path.join(allocator, &.{ collection_path, "default.manifest" });
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
