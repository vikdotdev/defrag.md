const std = @import("std");
const config_mod = @import("config.zig");
const cli = @import("cli.zig");
const log = @import("log.zig");
const build_cmd = @import("commands/build.zig");

// Core modules for testing
const path = @import("core/path.zig");
const manifest = @import("core/manifest.zig");
const heading = @import("core/heading.zig");
const fragment = @import("core/fragment.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = config_mod.Config;

const version = "0.1.0";

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    const command = cli.parseArgs(args) catch |parse_err| {
        try printError(parse_err);
        return;
    };

    if (command == .help) {
        try printUsage();
        return;
    }

    const config = Config.load(&arena) catch |load_err| {
        try log.err("Failed to load config: {}", .{load_err});
        return;
    };

    switch (command) {
        .build => |opts| {
            build_cmd.run(&arena, opts, config) catch |run_err| {
                try log.err("Build failed: {}", .{run_err});
            };
        },
        .validate => {
            try log.info("validate not yet implemented", .{});
        },
        .new => {
            try log.info("new not yet implemented", .{});
        },
        .install => {
            try log.info("install not yet implemented", .{});
        },
        .build_link => {
            try log.info("build-link not yet implemented", .{});
        },
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
        \\    install     Install defrag to your system
        \\    build-link  Build and symlink output
        \\    help        Show this help message
        \\
        \\Examples:
        \\    defrag build path/to/manifest
        \\    defrag build --manifest path/to/manifest --out output.md
        \\    defrag build --all
        \\    defrag new my-collection
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
    _ = config_mod;
    _ = cli;
    _ = log;
    _ = build_cmd;
    _ = path;
    _ = manifest;
    _ = heading;
    _ = fragment;
}
