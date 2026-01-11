const std = @import("std");
const mem = std.mem;

const ArenaAllocator = std.heap.ArenaAllocator;

pub const Command = union(enum) {
    build: BuildOptions,
    validate: ValidateOptions,
    new: NewOptions,
    install: void,
    build_link: BuildLinkOptions,
    help: void,
};

pub const BuildOptions = struct {
    manifest_path: []const u8,
    output_path: ?[]const u8 = null,
    all: bool = false,
};

pub const ValidateOptions = struct {
    manifest_path: []const u8,
};

pub const NewOptions = struct {
    database_name: []const u8,
    no_manifest: bool = false,
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

pub fn parseArgs(args: []const []const u8) ParseError!Command {
    if (args.len < 2) {
        return ParseError.MissingCommand;
    }

    const command = args[1];
    const rest = args[2..];

    if (mem.eql(u8, command, "build")) {
        return .{ .build = try parseBuildOptions(rest) };
    } else if (mem.eql(u8, command, "validate")) {
        return .{ .validate = try parseValidateOptions(rest) };
    } else if (mem.eql(u8, command, "new")) {
        return .{ .new = try parseNewOptions(rest) };
    } else if (mem.eql(u8, command, "install")) {
        return .{ .install = {} };
    } else if (mem.eql(u8, command, "build-link")) {
        return .{ .build_link = try parseBuildLinkOptions(rest) };
    } else if (mem.eql(u8, command, "help") or
        mem.eql(u8, command, "--help") or
        mem.eql(u8, command, "-h"))
    {
        return .{ .help = {} };
    } else {
        return ParseError.UnknownCommand;
    }
}

fn parseBuildOptions(args: []const []const u8) ParseError!BuildOptions {
    var opts = BuildOptions{
        .manifest_path = undefined,
    };
    var has_manifest = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
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
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            // Positional argument: treat as manifest path
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

        if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
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
        .database_name = undefined,
    };
    var has_name = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (mem.eql(u8, arg, "--database") or mem.eql(u8, arg, "-d")) {
            if (i + 1 >= args.len) return ParseError.MissingArgument;
            i += 1;
            opts.database_name = args[i];
            has_name = true;
        } else if (mem.eql(u8, arg, "--no-manifest")) {
            opts.no_manifest = true;
        } else if (mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            opts.database_name = arg;
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

        if (mem.eql(u8, arg, "--manifest") or mem.eql(u8, arg, "-m")) {
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

// Tests

test "parseArgs help" {
    const args = &[_][]const u8{ "defrag", "help" };
    const cmd = try parseArgs(args);
    try std.testing.expect(cmd == .help);
}

test "parseArgs build with manifest" {
    const args = &[_][]const u8{ "defrag", "build", "--manifest", "path/to/manifest" };
    const cmd = try parseArgs(args);
    try std.testing.expect(cmd == .build);
    try std.testing.expectEqualStrings("path/to/manifest", cmd.build.manifest_path);
}

test "parseArgs build with positional" {
    const args = &[_][]const u8{ "defrag", "build", "path/to/manifest" };
    const cmd = try parseArgs(args);
    try std.testing.expect(cmd == .build);
    try std.testing.expectEqualStrings("path/to/manifest", cmd.build.manifest_path);
}

test "parseArgs build --all" {
    const args = &[_][]const u8{ "defrag", "build", "--all" };
    const cmd = try parseArgs(args);
    try std.testing.expect(cmd == .build);
    try std.testing.expect(cmd.build.all);
}

test "parseArgs new with database" {
    const args = &[_][]const u8{ "defrag", "new", "--database", "my-db", "--no-manifest" };
    const cmd = try parseArgs(args);
    try std.testing.expect(cmd == .new);
    try std.testing.expectEqualStrings("my-db", cmd.new.database_name);
    try std.testing.expect(cmd.new.no_manifest);
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
