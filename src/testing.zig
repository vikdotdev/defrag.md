//! Test utilities for e2e subprocess testing.
//! Only imported from test blocks - excluded from release builds.

const std = @import("std");
const mem = std.mem;
const Child = std.process.Child;
const Allocator = mem.Allocator;

pub const fixtures_config = "fixtures/config.json";

/// Result of running defrag subprocess
pub const RunResult = struct {
    exit_code: u8,
    stdout: []const u8,
    stderr: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *RunResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }

    pub fn expectSuccess(self: RunResult) !void {
        if (self.exit_code != 0) {
            std.debug.print("Expected success but got exit code {d}\n", .{self.exit_code});
            std.debug.print("stderr: {s}\n", .{self.stderr});
            return error.TestExpectedEqual;
        }
    }

    pub fn expectFailure(self: RunResult) !void {
        if (self.exit_code == 0) {
            std.debug.print("Expected failure but got success\n", .{});
            std.debug.print("stdout: {s}\n", .{self.stdout});
            return error.TestExpectedEqual;
        }
    }

    pub fn expectStdoutContains(self: RunResult, substring: []const u8) !void {
        if (mem.indexOf(u8, self.stdout, substring) == null) {
            std.debug.print("Expected stdout to contain: {s}\n", .{substring});
            std.debug.print("Actual stdout: {s}\n", .{self.stdout});
            return error.TestExpectedEqual;
        }
    }

    pub fn expectStderrContains(self: RunResult, substring: []const u8) !void {
        if (mem.indexOf(u8, self.stderr, substring) == null) {
            std.debug.print("Expected stderr to contain: {s}\n", .{substring});
            std.debug.print("Actual stderr: {s}\n", .{self.stderr});
            return error.TestExpectedEqual;
        }
    }
};

/// Run defrag with given arguments
pub fn runDefrag(allocator: Allocator, args: []const []const u8) !RunResult {
    // Build full argv: "zig-out/bin/defrag" + args
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, "zig-out/bin/defrag");
    try argv.appendSlice(allocator, args);

    var child = Child.init(argv.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stdout
    var stdout_buf: [64 * 1024]u8 = undefined;
    const stdout_len = child.stdout.?.readAll(&stdout_buf) catch 0;
    const stdout = try allocator.dupe(u8, stdout_buf[0..stdout_len]);
    errdefer allocator.free(stdout);

    // Read stderr
    var stderr_buf: [64 * 1024]u8 = undefined;
    const stderr_len = child.stderr.?.readAll(&stderr_buf) catch 0;
    const stderr = try allocator.dupe(u8, stderr_buf[0..stderr_len]);
    errdefer allocator.free(stderr);

    const term = try child.wait();
    const exit_code: u8 = switch (term) {
        .Exited => |code| code,
        else => 255,
    };

    return .{
        .exit_code = exit_code,
        .stdout = stdout,
        .stderr = stderr,
        .allocator = allocator,
    };
}

pub fn build(allocator: Allocator, manifest: []const u8, output: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "build", "--manifest", manifest, "--out", output, "--config", fixtures_config });
}

pub fn buildWithConfig(allocator: Allocator, config: []const u8, manifest: []const u8, output: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "build", "--manifest", manifest, "--out", output, "--config", config });
}

pub fn validate(allocator: Allocator, manifest: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "validate", "--manifest", manifest, "--config", fixtures_config });
}

pub fn newWithConfig(allocator: Allocator, name: []const u8, config_path: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "new", name, "--config", config_path });
}

pub fn newNoManifestWithConfig(allocator: Allocator, name: []const u8, config_path: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "new", "--no-manifest", name, "--config", config_path });
}

pub fn writeTestConfig(allocator: Allocator, config_path: []const u8, store_path: []const u8) !void {
    const content = try std.fmt.allocPrint(allocator, "{{\"stores\": [{{\"path\": \"{s}\", \"default\": true}}]}}", .{store_path});
    defer allocator.free(content);
    const file = try std.fs.cwd().createFile(config_path, .{});
    defer file.close();
    try file.writeAll(content);
}

pub fn init(allocator: Allocator, store_path: []const u8, config_path: []const u8) !RunResult {
    return runDefrag(allocator, &.{ "init", store_path, "--config", config_path });
}

// ============================================================================
// File/Directory helpers
// ============================================================================

/// Get path to temp output: test/tmp/{name}
pub fn tmpPath(allocator: Allocator, name: []const u8) ![]const u8 {
    std.fs.cwd().makePath("zig-out/defragtest") catch {};
    return std.fs.path.join(allocator, &.{ "zig-out/defragtest", name });
}

/// Assert that a file exists at the given path
pub fn expectFileExists(path: []const u8) !void {
    std.fs.cwd().access(path, .{}) catch {
        std.debug.print("Expected file to exist: {s}\n", .{path});
        return error.TestExpectedEqual;
    };
}

/// Assert that a file does NOT exist at the given path
pub fn expectFileNotExists(path: []const u8) !void {
    std.fs.cwd().access(path, .{}) catch return;
    std.debug.print("Expected file NOT to exist: {s}\n", .{path});
    return error.TestExpectedEqual;
}

/// Assert that a file contains a specific substring
pub fn expectFileContains(allocator: Allocator, path: []const u8, substring: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open {s}: {}\n", .{ path, err });
        return err;
    };
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    if (mem.indexOf(u8, content, substring) == null) {
        std.debug.print("Expected file to contain: {s}\n", .{substring});
        std.debug.print("File path: {s}\n", .{path});
        return error.TestExpectedEqual;
    }
}

/// Assert that a file does NOT contain a specific substring
pub fn expectFileNotContains(allocator: Allocator, path: []const u8, substring: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open {s}: {}\n", .{ path, err });
        return err;
    };
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    if (mem.indexOf(u8, content, substring) != null) {
        std.debug.print("Expected file NOT to contain: {s}\n", .{substring});
        return error.TestExpectedEqual;
    }
}

/// Assert that a directory exists at the given path
pub fn expectDirExists(path: []const u8) !void {
    var dir = std.fs.cwd().openDir(path, .{}) catch {
        std.debug.print("Expected directory to exist: {s}\n", .{path});
        return error.TestExpectedEqual;
    };
    dir.close();
}

/// Delete a file (ignore errors if doesn't exist)
pub fn cleanup(path: []const u8) void {
    std.fs.cwd().deleteFile(path) catch {};
}

/// Delete a directory tree recursively (ignore errors if doesn't exist)
pub fn cleanupDir(path: []const u8) void {
    std.fs.cwd().deleteTree(path) catch {};
}
