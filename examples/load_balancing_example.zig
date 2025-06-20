const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Simple worker that processes different types of work
const WorkerMessage = union(enum) {
    ProcessTask: struct { task_id: u32, task_type: []const u8, complexity: u32 },
    GetStats: void,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;

        // Get or initialize worker stats
        const stats = actor.getState(WorkerStats) orelse blk: {
            const new_stats = actor.getAllocator().create(WorkerStats) catch return null;
            new_stats.* = WorkerStats{ .tasks_processed = 0, .total_complexity = 0 };
            actor.setState(new_stats);
            break :blk new_stats;
        };

        switch (msg) {
            .ProcessTask => |task| {
                std.debug.print("[Thread {}] 🔄 Processing {s} task {} (complexity: {})\n", .{ thread_id, task.task_type, task.task_id, task.complexity });

                // Simulate processing time based on complexity
                const processing_time = task.complexity * 10; // 10ms per complexity unit
                std.time.sleep(processing_time * std.time.ns_per_ms);

                stats.tasks_processed += 1;
                stats.total_complexity += task.complexity;

                std.debug.print("[Thread {}] ✅ Completed {s} task {} (total processed: {})\n", .{ thread_id, task.task_type, task.task_id, stats.tasks_processed });
            },
            .GetStats => {
                std.debug.print("[Thread {}] 📊 Worker Stats: {} tasks, {} total complexity\n", .{ thread_id, stats.tasks_processed, stats.total_complexity });
                const result_ptr = actor.getAllocator().create(WorkerStats) catch return null;
                result_ptr.* = stats.*;
                return @ptrCast(result_ptr);
            },
        }
        return null;
    }
};

const WorkerStats = struct {
    tasks_processed: u32,
    total_complexity: u32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    std.debug.print("⚖️  Creating load balancing demonstration...\n", .{});

    // Create multiple worker threads (same actor type, different instances)
    const worker_thread1 = try ActorThread.init(allocator);
    try worker_thread1.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread1);

    const worker_thread2 = try ActorThread.init(allocator);
    try worker_thread2.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread2);

    const worker_thread3 = try ActorThread.init(allocator);
    try worker_thread3.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread3);

    const worker_thread4 = try ActorThread.init(allocator);
    try worker_thread4.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread4);

    const worker_thread5 = try ActorThread.init(allocator);
    try worker_thread5.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread5);

    // Give threads time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n📊 Load balancing setup:\n", .{});
    const registry = engine.getActorRegistry();
    var iter = registry.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s} -> Threads: [", .{entry.key_ptr.*});
        for (entry.value_ptr.items, 0..) |thread_id, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{}", .{thread_id});
        }
        std.debug.print("]\n", .{});
    }

    std.debug.print("\n=== 🔄 Computational Task Load Balancing ===\n", .{});

    // Send multiple computational tasks that will be load-balanced across worker threads
    const compute_tasks = [_]struct { id: u32, complexity: u32 }{
        .{ .id = 1, .complexity = 3 },
        .{ .id = 2, .complexity = 1 },
        .{ .id = 3, .complexity = 5 },
        .{ .id = 4, .complexity = 2 },
        .{ .id = 5, .complexity = 4 },
        .{ .id = 6, .complexity = 1 },
        .{ .id = 7, .complexity = 3 },
        .{ .id = 8, .complexity = 2 },
    };

    for (compute_tasks) |task| {
        var task_msg = WorkerMessage{ .ProcessTask = .{ .task_id = task.id, .task_type = "compute", .complexity = task.complexity } };
        try engine.send(WorkerMessage, &task_msg);
        std.time.sleep(10 * std.time.ns_per_ms); // Small delay between submissions
    }

    // Wait for tasks to complete
    std.time.sleep(300 * std.time.ns_per_ms);

    std.debug.print("\n=== 🖼️  Image Processing Load Balancing ===\n", .{});

    // Send image processing tasks
    var resize_task = WorkerMessage{ .ProcessTask = .{ .task_id = 101, .task_type = "image-resize", .complexity = 3 } };
    try engine.send(WorkerMessage, &resize_task);

    var filter_task = WorkerMessage{ .ProcessTask = .{ .task_id = 102, .task_type = "image-filter", .complexity = 4 } };
    try engine.send(WorkerMessage, &filter_task);

    var compress_task = WorkerMessage{ .ProcessTask = .{ .task_id = 103, .task_type = "image-compress", .complexity = 2 } };
    try engine.send(WorkerMessage, &compress_task);

    var resize_task2 = WorkerMessage{ .ProcessTask = .{ .task_id = 104, .task_type = "image-resize", .complexity = 3 } };
    try engine.send(WorkerMessage, &resize_task2);

    std.time.sleep(200 * std.time.ns_per_ms);

    std.debug.print("\n=== 🗄️  Database Operations Load Balancing ===\n", .{});

    // Send database operations
    var query1 = WorkerMessage{ .ProcessTask = .{ .task_id = 1001, .task_type = "db-query", .complexity = 2 } };
    try engine.send(WorkerMessage, &query1);

    var insert1 = WorkerMessage{ .ProcessTask = .{ .task_id = 5001, .task_type = "db-insert", .complexity = 1 } };
    try engine.send(WorkerMessage, &insert1);

    var update1 = WorkerMessage{ .ProcessTask = .{ .task_id = 3001, .task_type = "db-update", .complexity = 2 } };
    try engine.send(WorkerMessage, &update1);

    var query2 = WorkerMessage{ .ProcessTask = .{ .task_id = 1002, .task_type = "db-query", .complexity = 2 } };
    try engine.send(WorkerMessage, &query2);

    var insert2 = WorkerMessage{ .ProcessTask = .{ .task_id = 5002, .task_type = "db-insert", .complexity = 1 } };
    try engine.send(WorkerMessage, &insert2);

    std.time.sleep(200 * std.time.ns_per_ms);

    std.debug.print("\n=== 📊 Collecting Statistics ===\n", .{});

    // Collect stats from workers (this will hit different threads due to load balancing)
    for (0..5) |i| {
        var stats_request = WorkerMessage{ .GetStats = {} };
        const response = try engine.call(WorkerMessage, &stats_request);
        if (response) |ptr| {
            const stats_ptr = @as(*WorkerStats, @ptrCast(@alignCast(ptr)));
            std.debug.print("Worker {}: {} tasks processed, {} total complexity\n", .{ i + 1, stats_ptr.tasks_processed, stats_ptr.total_complexity });
            allocator.destroy(stats_ptr);
        }
        std.time.sleep(50 * std.time.ns_per_ms);
    }

    std.debug.print("\n✅ Load balancing demonstration completed!\n", .{});
    std.debug.print("📋 Summary:\n", .{});
    std.debug.print("  - Computational Tasks: ✅ 8 tasks distributed across 5 worker threads\n", .{});
    std.debug.print("  - Image Processing: ✅ 4 operations distributed across worker threads\n", .{});
    std.debug.print("  - Database Operations: ✅ 5 operations distributed across worker threads\n", .{});
    std.debug.print("  - Statistics Collection: ✅ Round-robin stats gathering from 5 workers\n", .{});
    std.debug.print("  - Load Balancing: ✅ Automatic distribution via round-robin\n", .{});

    // Start the engine to process remaining messages
    engine.start();
}
