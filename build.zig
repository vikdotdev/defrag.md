const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build cmark C library
    const cmark_dep = b.dependency("cmark", .{});
    const cmark_lib = b.addLibrary(.{
        .name = "cmark",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    // Add cmark source files
    const cmark_sources = &[_][]const u8{
        "blocks.c",
        "buffer.c",
        "cmark.c",
        "cmark_ctype.c",
        "commonmark.c",
        "houdini_href_e.c",
        "houdini_html_e.c",
        "houdini_html_u.c",
        "html.c",
        "inlines.c",
        "iterator.c",
        "latex.c",
        "man.c",
        "node.c",
        "references.c",
        "render.c",
        "scanners.c",
        "utf8.c",
        "xml.c",
    };

    cmark_lib.addCSourceFiles(.{
        .root = cmark_dep.path("src"),
        .files = cmark_sources,
        .flags = &.{"-std=c99"},
    });

    // Add include paths for cmark headers
    cmark_lib.addIncludePath(cmark_dep.path("src"));
    cmark_lib.addIncludePath(b.path("src/cmark_compat"));

    // Link libc
    cmark_lib.linkLibC();

    // Create module for our Zig code
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add cmark include path and link library to root module
    root_module.addIncludePath(cmark_dep.path("src"));
    root_module.addIncludePath(b.path("src/cmark_compat"));
    root_module.linkLibrary(cmark_lib);

    const exe = b.addExecutable(.{
        .name = "defrag",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    // Run command: `zig build run -- <args>`
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run defrag");
    run_step.dependOn(&run_cmd.step);

    // Tests: `zig build test`
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addIncludePath(cmark_dep.path("src"));
    test_module.addIncludePath(b.path("src/cmark_compat"));
    test_module.linkLibrary(cmark_lib);

    const exe_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
