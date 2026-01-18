const log = @import("../log.zig");

pub fn printHelp(version: []const u8) !void {
    try log.info(
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
        \\Run 'defrag <command> --help' for command-specific help.
        \\
        \\Version: {s}
    , .{version});
}
