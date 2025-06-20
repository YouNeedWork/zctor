const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zctor", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const xev = b.dependency("libxev", .{ .target = target, .optimize = optimize });
    mod.addImport("xev", xev.module("xev"));

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zctor",
        .root_module = mod,
    });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_one_shot_step = b.addTest(.{
        .root_source_file = b.path("src/one_shot.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_test = b.addRunArtifact(test_one_shot_step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_test.step);

    // Documentation generation step
    const docs_cmd = b.addSystemCommand(&[_][]const u8{
        "python3",
        "docs/generate_docs.py",
        "src",
        "docs",
    });

    // Book generation step
    const book_cmd = b.addSystemCommand(&[_][]const u8{
        "python3",
        "docs/generate_book.py",
        "docs",
        "-o",
        "docs/zctor-complete-book.md",
    });

    const docs_step = b.step("docs", "Generate API documentation");
    docs_step.dependOn(&docs_cmd.step);

    const book_step = b.step("book", "Generate complete documentation book");
    book_step.dependOn(&book_cmd.step);

    const all_docs_step = b.step("docs-all", "Generate all documentation");
    all_docs_step.dependOn(&docs_cmd.step);
    all_docs_step.dependOn(&book_cmd.step);

    // Add example executables
    const call_example = b.addExecutable(.{
        .name = "call_example",
        .root_source_file = b.path("examples/call_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    call_example.root_module.addImport("zctor", mod);
    b.installArtifact(call_example);

    // Run example step
    const run_call_example = b.addRunArtifact(call_example);
    const run_call_example_step = b.step("run-call", "Run the call example");
    run_call_example_step.dependOn(&run_call_example.step);
}
