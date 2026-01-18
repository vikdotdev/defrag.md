const std = @import("std");
const mem = std.mem;

pub const ParseResult = struct {
    command: Command,
    config_path: ?[]const u8 = null,
};

pub const ParseContext = struct {
    command_name: ?[]const u8 = null,
    bad_option: ?[]const u8 = null,
    missing_arg: ?[]const u8 = null,
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
    manifest_path: ?[]const u8 = null,
    all: bool = false,
    store: ?[]const u8 = null,
};

pub const NewOptions = struct {
    collection_name: []const u8,
    no_manifest: bool = false,
    store: ?[]const u8 = null,
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
    MissingPositional,
    MissingOptionValue,
    MissingOption,
    UnknownOption,
    HelpRequested,
};

pub fn parseArgs(args: []const []const u8, parse_ctx: *ParseContext) ParseError!ParseResult {
    var result = ParseResult{ .command = undefined };

    if (args.len < 2) {
        return ParseError.MissingCommand;
    }

    const command = args[1];
    const rest = args[2..];

    parse_ctx.command_name = command;

    for (rest, 0..) |arg, i| {
        if (mem.eql(u8, arg, "--config")) {
            if (i + 1 >= rest.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            result.config_path = rest[i + 1];
            break;
        }
    }

    if (mem.eql(u8, command, "build")) {
        result.command = .{ .build = try parseBuildOptions(rest, parse_ctx) };
    } else if (mem.eql(u8, command, "validate")) {
        result.command = .{ .validate = try parseValidateOptions(rest, parse_ctx) };
    } else if (mem.eql(u8, command, "new")) {
        result.command = .{ .new = try parseNewOptions(rest, parse_ctx) };
    } else if (mem.eql(u8, command, "init")) {
        result.command = .{ .init = try parseInitOptions(rest, parse_ctx) };
    } else if (mem.eql(u8, command, "build-link")) {
        result.command = .{ .build_link = try parseBuildLinkOptions(rest, parse_ctx) };
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

fn parseBuildOptions(args: []const []const u8, parse_ctx: *ParseContext) ParseError!BuildOptions {
    var opts = BuildOptions{};
    var has_manifest = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.manifest_path = args[i];
            has_manifest = true;
        } else if (mem.eql(u8, arg, "--out") or mem.eql(u8, arg, "-o")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.output_path = args[i];
        } else if (mem.eql(u8, arg, "--all") or mem.eql(u8, arg, "-a")) {
            opts.all = true;
        } else if (mem.eql(u8, arg, "--store") or mem.eql(u8, arg, "-s")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.store = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            parse_ctx.bad_option = arg;
            return ParseError.UnknownOption;
        } else {
            opts.manifest_path = arg;
            has_manifest = true;
        }
    }

    if (!has_manifest and !opts.all) {
        parse_ctx.missing_arg = "manifest";
        return ParseError.MissingPositional;
    }

    return opts;
}

fn parseValidateOptions(args: []const []const u8, parse_ctx: *ParseContext) ParseError!ValidateOptions {
    var opts = ValidateOptions{};
    var has_manifest = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.manifest_path = args[i];
            has_manifest = true;
        } else if (mem.eql(u8, arg, "--all") or mem.eql(u8, arg, "-a")) {
            opts.all = true;
        } else if (mem.eql(u8, arg, "--store") or mem.eql(u8, arg, "-s")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.store = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            parse_ctx.bad_option = arg;
            return ParseError.UnknownOption;
        } else {
            opts.manifest_path = arg;
            has_manifest = true;
        }
    }

    if (!has_manifest and !opts.all) {
        parse_ctx.missing_arg = "manifest";
        return ParseError.MissingPositional;
    }

    return opts;
}

fn parseNewOptions(args: []const []const u8, parse_ctx: *ParseContext) ParseError!NewOptions {
    var opts = NewOptions{
        .collection_name = undefined,
    };
    var has_name = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--collection") or mem.eql(u8, arg, "-c")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.collection_name = args[i];
            has_name = true;
        } else if (mem.eql(u8, arg, "--store") or mem.eql(u8, arg, "-s")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.store = args[i];
        } else if (mem.eql(u8, arg, "--no-manifest")) {
            opts.no_manifest = true;
        } else if (mem.startsWith(u8, arg, "-")) {
            parse_ctx.bad_option = arg;
            return ParseError.UnknownOption;
        } else {
            opts.collection_name = arg;
            has_name = true;
        }
    }

    if (!has_name) {
        parse_ctx.missing_arg = "collection_name";
        return ParseError.MissingPositional;
    }

    return opts;
}

fn parseBuildLinkOptions(args: []const []const u8, parse_ctx: *ParseContext) ParseError!BuildLinkOptions {
    var manifest_path: ?[]const u8 = null;
    var link_path: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else if (mem.eql(u8, arg, "--config")) {
            i += 1;
        } else if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            manifest_path = args[i];
        } else if (mem.eql(u8, arg, "--link") or mem.eql(u8, arg, "-l")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            link_path = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            parse_ctx.bad_option = arg;
            return ParseError.UnknownOption;
        }
    }

    if (manifest_path == null) {
        parse_ctx.missing_arg = "--manifest";
        return ParseError.MissingOption;
    }
    if (link_path == null) {
        parse_ctx.missing_arg = "--link";
        return ParseError.MissingOption;
    }

    return BuildLinkOptions{
        .manifest_path = manifest_path.?,
        .link_path = link_path.?,
    };
}

fn parseInitOptions(args: []const []const u8, parse_ctx: *ParseContext) ParseError!InitOptions {
    var opts = InitOptions{ .store_path = undefined };
    var has_path = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            return ParseError.HelpRequested;
        } else if (mem.eql(u8, arg, "--config")) {
            if (i + 1 >= args.len) {
                parse_ctx.missing_arg = arg;
                return ParseError.MissingOptionValue;
            }
            i += 1;
            opts.config_path = args[i];
        } else if (mem.startsWith(u8, arg, "-")) {
            parse_ctx.bad_option = arg;
            return ParseError.UnknownOption;
        } else {
            opts.store_path = arg;
            has_path = true;
        }
    }

    if (!has_path) {
        parse_ctx.missing_arg = "store_path";
        return ParseError.MissingPositional;
    }
    return opts;
}

test "parseArgs help" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "help" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .help);
    try std.testing.expect(result.config_path == null);
}

test "parseArgs build with manifest" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "build", "--manifest", "path/to/manifest" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("path/to/manifest", result.command.build.manifest_path.?);
}

test "parseArgs build with positional" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "build", "path/to/manifest" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("path/to/manifest", result.command.build.manifest_path.?);
}

test "parseArgs build --all" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "build", "--all" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .build);
    try std.testing.expect(result.command.build.all);
}

test "parseArgs build --all -s store" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "build", "--all", "-s", "my-store" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .build);
    try std.testing.expect(result.command.build.all);
    try std.testing.expectEqualStrings("my-store", result.command.build.store.?);
}

test "parseArgs validate --all -s store" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "validate", "--all", "-s", "my-store" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .validate);
    try std.testing.expect(result.command.validate.all);
    try std.testing.expectEqualStrings("my-store", result.command.validate.store.?);
}

test "parseArgs new with collection" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "new", "--collection", "my-collection", "--no-manifest" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .new);
    try std.testing.expectEqualStrings("my-collection", result.command.new.collection_name);
    try std.testing.expect(result.command.new.no_manifest);
}

test "parseArgs new -s store" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "new", "my-collection", "-s", "my-store" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .new);
    try std.testing.expectEqualStrings("my-collection", result.command.new.collection_name);
    try std.testing.expectEqualStrings("my-store", result.command.new.store.?);
}

test "parseArgs with config" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "build", "--all", "--config", "test/config.json" };
    const result = try parseArgs(args, &parse_ctx);
    try std.testing.expect(result.command == .build);
    try std.testing.expectEqualStrings("test/config.json", result.config_path.?);
}

test "parseArgs missing command" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{"defrag"};
    const result = parseArgs(args, &parse_ctx);
    try std.testing.expectError(ParseError.MissingCommand, result);
}

test "parseArgs unknown command" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "unknown" };
    const result = parseArgs(args, &parse_ctx);
    try std.testing.expectError(ParseError.UnknownCommand, result);
}

test "parseArgs context captures command name" {
    var parse_ctx = ParseContext{};
    const args = &[_][]const u8{ "defrag", "init" };
    _ = parseArgs(args, &parse_ctx) catch {};
    try std.testing.expectEqualStrings("init", parse_ctx.command_name.?);
}
