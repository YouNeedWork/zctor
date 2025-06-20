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

    const multi_thread_example = b.addExecutable(.{
        .name = "multi_thread_example",
        .root_source_file = b.path("examples/multi_thread_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    multi_thread_example.root_module.addImport("zctor", mod);
    b.installArtifact(multi_thread_example);

    const broadcast_example = b.addExecutable(.{
        .name = "broadcast_example",
        .root_source_file = b.path("examples/broadcast_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    broadcast_example.root_module.addImport("zctor", mod);
    b.installArtifact(broadcast_example);

    const thread_communication_example = b.addExecutable(.{
        .name = "thread_communication_example",
        .root_source_file = b.path("examples/thread_communication_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    thread_communication_example.root_module.addImport("zctor", mod);
    b.installArtifact(thread_communication_example);

    const pubsub_example = b.addExecutable(.{
        .name = "pubsub_example",
        .root_source_file = b.path("examples/pubsub_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    pubsub_example.root_module.addImport("zctor", mod);
    b.installArtifact(pubsub_example);

    const load_balancing_example = b.addExecutable(.{
        .name = "load_balancing_example",
        .root_source_file = b.path("examples/load_balancing_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    load_balancing_example.root_module.addImport("zctor", mod);
    b.installArtifact(load_balancing_example);

    // Run example steps
    const run_call_example = b.addRunArtifact(call_example);
    const run_call_example_step = b.step("run-call", "Run the call example");
    run_call_example_step.dependOn(&run_call_example.step);

    const run_multi_thread_example = b.addRunArtifact(multi_thread_example);
    const run_multi_thread_example_step = b.step("run-multi", "Run the multi-thread example");
    run_multi_thread_example_step.dependOn(&run_multi_thread_example.step);

    const run_broadcast_example = b.addRunArtifact(broadcast_example);
    const run_broadcast_example_step = b.step("run-broadcast", "Run the broadcast messaging example");
    run_broadcast_example_step.dependOn(&run_broadcast_example.step);

    const run_thread_communication_example = b.addRunArtifact(thread_communication_example);
    const run_thread_communication_example_step = b.step("run-thread-comm", "Run the thread communication example");
    run_thread_communication_example_step.dependOn(&run_thread_communication_example.step);

    const run_pubsub_example = b.addRunArtifact(pubsub_example);
    const run_pubsub_example_step = b.step("run-pubsub", "Run the publisher-subscriber example");
    run_pubsub_example_step.dependOn(&run_pubsub_example.step);

    const run_load_balancing_example = b.addRunArtifact(load_balancing_example);
    const run_load_balancing_example_step = b.step("run-load-balance", "Run the load balancing example");
    run_load_balancing_example_step.dependOn(&run_load_balancing_example.step);
}
