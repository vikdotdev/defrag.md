const std = @import("std");
const mem = std.mem;

pub const ParseResult = struct {
    command: Command,
    config_path: ?[]const u8 = null,
};

pub const Command = union(enum) {
    build: BuildOptions,
    validate: ValidateOptions,
    new: NewOptions,
    init: InitOptions,
    build_link: BuildLinkOptions,
    help: void,
};

pub const BuildOptions = struct {
    manifest_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
    all: bool = false,
    store: ?[]const u8 = null,
};

pub const ValidateOptions = struct {
    manifest_path: []const u8,
};

pub const NewOptions = struct {
    collection_name: []const u8,
    no_manifest: bool = false,
};

pub const InitOptions = struct {
    store_path: []const u8,
    config_path: ?[]const u8 = null,
};

pub const BuildLinkOptions = struct {
    manifest_path: []const u8,
    link_path: []const u8,
};

pub const ParseError = error{
    MissingCommand,
    UnknownCommand,
    MissingArgument,
    UnknownOption,
};

pub fn parseArgs(args: []const []const u8) ParseError!ParseResult {
    var result = ParseResult{ .command = undefined };

    if (args.len < 2) {
        return ParseError.MissingCommand;
    }

    const command = args[1];
    const rest = args[2..];

    for (rest, 0..) |arg, i| {
        if (mem.eql(u8, arg, "--config")) {
            if (i + 1 >= rest.len) return ParseError.MissingArgument;
            result.config_path = rest[i + 1];
            break;
        }
    }

    if (mem.eql(u8, command, "build")) {
        result.command = .{ .build = try parseBuildOptions(rest) };
    } else if (mem.eql(u8, command, "validate")) {
        result.command = .{ .validate = try parseValidateOptions(rest) };
    } else if (mem.eql(u8, command, "new")) {
        result.command = .{ .new = try parseNewOptions(rest) };
    } else if (mem.eql(u8, command, "init")) {
        result.command = .{ .init = try parseInitOptions(rest) };
    } else if (mem.eql(u8, command, "build-link")) {
        result.command = .{ .build_link = try parseBuildLinkOptions(rest) };
    } else if (mem.eql(u8, command, "help") or
        mem.eql(u8, command, "--help") or
        mem.eql(u8, command, "-h"))
    {
        result.command = .{ .help = {} };
    } else {
        return ParseError.UnknownCommand;
    }

    return result;
}

fn parseBuildOptions(args: []const []const u8) ParseError!BuildOptions {
    var opts = BuildOptions{};
    var has_manifest = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.manifest_path = args[i];
            has_manifest = true;
        } else if (mem.eql(u8, arg, "--out") or mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.output_path = args[i];
        } else if (mem.eql(u8, arg, "--all") or mem.eql(u8, arg, "-a")) {
            opts.all = true;
        } else if (mem.eql(u8, arg, "--store") or mem.eql(u8, arg, "-s")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.store = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            opts.manifest_path = arg;
            has_manifest = true;
        }
    }

    if (!has_manifest and !opts.all) {
        return ParseError.MissingArgument;
    }

    return opts;
}

fn parseValidateOptions(args: []const []const u8) ParseError!ValidateOptions {
    var opts = ValidateOptions{
        .manifest_path = undefined,
    };
    var has_manifest = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.manifest_path = args[i];
            has_manifest = true;
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            opts.manifest_path = arg;
            has_manifest = true;
        }
    }

    if (!has_manifest) {
        return ParseError.MissingArgument;
    }

    return opts;
}

fn parseNewOptions(args: []const []const u8) ParseError!NewOptions {
    var opts = NewOptions{
        .collection_name = undefined,
    };
    var has_name = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--collection") or mem.eql(u8, arg, "-c")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.collection_name = args[i];
            has_name = true;
        } else if (mem.eql(u8, arg, "--no-manifest")) {
            opts.no_manifest = true;
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            opts.collection_name = arg;
            has_name = true;
        }
    }

    if (!has_name) {
        return ParseError.MissingArgument;
    }

    return opts;
}

fn parseBuildLinkOptions(args: []const []const u8) ParseError!BuildLinkOptions {
    var manifest_path: ?[]const u8 = null;
    var link_path: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            manifest_path = args[i];
        } else if (mem.eql(u8, arg, "--link") or mem.eql(u8, arg, "-l")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            link_path = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        }
    }

    if (manifest_path == null or link_path == null) {
        return ParseError.MissingArgument;
    }

    return BuildLinkOptions{
        .manifest_path = manifest_path.?,
        .link_path = link_path.?,
    };
}

fn parseInitOptions(args: []const []const u8) ParseError!InitOptions {
    var opts = InitOptions{ .store_path = undefined };
    var has_path = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.config_path = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            opts.store_path = arg;
            has_path = true;
        }
    }

    if (!has_path) return ParseError.MissingArgument;
    return opts;
}

test "parseArgs help" {
    const args = &[_][]const u8{ "defrag", "help" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .help);
    try std.testing.expect(result.config_path == null);
}

test "parseArgs build with manifest" {
    const args = &[_][]const u8{ "defrag", "build", "--manifest", "path/to/manifest" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("path/to/manifest", result.command.build.manifest_path.?);
}

test "parseArgs build with positional" {
    const args = &[_][]const u8{ "defrag", "build", "path/to/manifest" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("path/to/manifest", result.command.build.manifest_path.?);
}

test "parseArgs build --all" {
    const args = &[_][]const u8{ "defrag", "build", "--all" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .build);
    try std.testing.expect(result.command.build.all);
}

test "parseArgs build --all -s store" {
    const args = &[_][]const u8{ "defrag", "build", "--all", "-s", "my-store" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .build);
    try std.testing.expect(result.command.build.all);
    try std.testing.expectEqualStrings("my-store", result.command.build.store.?);
}

test "parseArgs new with collection" {
    const args = &[_][]const u8{ "defrag", "new", "--collection", "my-collection", "--no-manifest" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .new);
    try std.testing.expectEqualStrings("my-collection", result.command.new.collection_name);
    try std.testing.expect(result.command.new.no_manifest);
}

test "parseArgs with config" {
    const args = &[_][]const u8{ "defrag", "build", "--all", "--config", "test/config.json" };
    const result = try parseArgs(args);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("test/config.json", result.config_path.?);
}

test "parseArgs missing command" {
    const args = &[_][]const u8{"defrag"};
    const result = parseArgs(args);
    try std.testing.expectError(ParseError.MissingCommand, result);
}

test "parseArgs unknown command" {
    const args = &[_][]const u8{ "defrag", "unknown" };
    const result = parseArgs(args);
    try std.testing.expectError(ParseError.UnknownCommand, result);
}
