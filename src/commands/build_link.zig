const std = @import("std");
const fs = @import("../fs.zig");
const log = @import("../log.zig");
const build_cmd = @import("build.zig");

const ArenaAllocator = std.heap.ArenaAllocator;
const Config = @import("../config.zig").Config;
const BuildOptions = @import("../cli.zig").BuildOptions;
const BuildLinkOptions = @import("../cli.zig").BuildLinkOptions;

pub const BuildLinkError = error{
    BuildFailed,
    LinkFailed,
};

pub fn run(arena: *ArenaAllocator, options: BuildLinkOptions, config: Config) !void {
    const allocator = arena.allocator();

    // Build the manifest first
    const build_options = BuildOptions{
        .manifest_path = options.manifest_path,
    };
    build_cmd.run(arena, build_options, config) catch {
        return BuildLinkError.BuildFailed;
    };

    // Determine the built file path (same logic as build command)
    const manifest_dir = std.fs.path.dirname(options.manifest_path) orelse ".";
    const collection_name = try getCollectionName(allocator, manifest_dir);
    const manifest_prefix = getManifestPrefix(options.manifest_path);
    const build_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}.{s}{s}",
        .{ Config.build_dir, collection_name, manifest_prefix, fs.md_ext },
    );

    // Get absolute path to build file
    var abs_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_build_path = std.fs.cwd().realpath(build_path, &abs_buf) catch {
        try log.err("Built file not found: {s}", .{build_path});
        return BuildLinkError.LinkFailed;
    };

    // Remove existing link/file
    std.fs.cwd().deleteFile(options.link_path) catch |err| {
        if (err != error.FileNotFound) {
            try log.err("Failed to remove existing file: {s}", .{options.link_path});
            return BuildLinkError.LinkFailed;
        }
    };

    // Ensure parent directory exists
    try fs.ensureParentDir(options.link_path);

    // Create symlink
    std.fs.cwd().symLink(abs_build_path, options.link_path, .{}) catch {
        try log.err("Failed to create symlink: {s}", .{options.link_path});
        return BuildLinkError.LinkFailed;
    };

    try log.info("Linked: {s} -> {s}", .{ options.link_path, build_path });
}

fn getCollectionName(allocator: std.mem.Allocator, manifest_dir: []const u8) ![]const u8 {
    if (!std.mem.eql(u8, manifest_dir, ".")) {
        return std.fs.path.basename(manifest_dir);
    }
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &buf);
    return allocator.dupe(u8, std.fs.path.basename(cwd));
}

fn getManifestPrefix(manifest_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(manifest_path);
    if (std.mem.endsWith(u8, basename, Config.manifest_ext)) {
        return basename[0 .. basename.len - Config.manifest_ext.len];
    }
    return basename;
}
