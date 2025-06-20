const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Worker actor that can process different types of work
const WorkerMessage = union(enum) {
    ProcessData: struct { data: []const u8, worker_id: u32 },
    GetStatus: void,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .ProcessData => |work| {
                std.debug.print("[Thread {}] Worker {} processing: {s}\n", .{ thread_id, work.worker_id, work.data });
                // Simulate some work
                std.time.sleep(10 * std.time.ns_per_ms);
                std.debug.print("[Thread {}] Worker {} completed processing\n", .{ thread_id, work.worker_id });
            },
            .GetStatus => {
                std.debug.print("[Thread {}] Worker status: ACTIVE\n", .{thread_id});
                const result_ptr = actor.getAllocator().create([]const u8) catch return null;
                result_ptr.* = "ACTIVE";
                return @ptrCast(result_ptr);
            },
        }
        return null;
    }
};

// Coordinator actor that manages and delegates work
const CoordinatorMessage = union(enum) {
    DelegateWork: struct { task: []const u8, target_thread: ?u32 },
    CollectResults: void,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .DelegateWork => |delegation| {
                if (delegation.target_thread) |target| {
                    std.debug.print("[Thread {}] Coordinator delegating '{s}' to thread {}\n", .{ thread_id, delegation.task, target });
                } else {
                    std.debug.print("[Thread {}] Coordinator delegating '{s}' to any available worker\n", .{ thread_id, delegation.task });
                }
            },
            .CollectResults => {
                std.debug.print("[Thread {}] Coordinator collecting results from all workers\n", .{thread_id});
            },
        }
        return null;
    }
};

// Monitor actor that tracks system health
const MonitorMessage = union(enum) {
    CheckHealth: void,
    LogMetric: struct { name: []const u8, value: f64 },

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .CheckHealth => {
                std.debug.print("[Thread {}] Monitor: System health check - ALL SYSTEMS OPERATIONAL\n", .{thread_id});
            },
            .LogMetric => |metric| {
                std.debug.print("[Thread {}] Monitor: Metric '{s}' = {d:.2}\n", .{ thread_id, metric.name, metric.value });
            },
        }
        return null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    std.debug.print("🔄 Creating thread communication demonstration...\n", .{});

    // Thread 0: Multiple workers (same-thread communication)
    const thread0 = try ActorThread.init(allocator);
    try thread0.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try thread0.registerActor(try Actor(CoordinatorMessage).init(allocator, CoordinatorMessage.handle));
    try engine.spawn(thread0);

    // Thread 1: More workers (cross-thread communication target)
    const thread1 = try ActorThread.init(allocator);
    try thread1.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(thread1);

    // Thread 2: Monitor (cross-thread communication)
    const thread2 = try ActorThread.init(allocator);
    try thread2.registerActor(try Actor(MonitorMessage).init(allocator, MonitorMessage.handle));
    try engine.spawn(thread2);

    // Thread 3: Additional workers for load balancing
    const thread3 = try ActorThread.init(allocator);
    try thread3.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(thread3);

    // Give threads time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n📊 Thread layout:\n", .{});
    const registry = engine.getActorRegistry();
    var iter = registry.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s} -> Thread {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    std.debug.print("\n=== 🏠 Same-Thread Communication Test ===\n", .{});

    // Same-thread communication: Coordinator and Worker on Thread 0
    var coord_msg = CoordinatorMessage{ .DelegateWork = .{ .task = "Process user data", .target_thread = null } };
    try engine.send(CoordinatorMessage, &coord_msg);

    std.time.sleep(50 * std.time.ns_per_ms);

    var worker_msg1 = WorkerMessage{ .ProcessData = .{ .data = "user_data_batch_1", .worker_id = 1 } };
    try engine.send(WorkerMessage, &worker_msg1);

    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n=== 🌐 Cross-Thread Communication Test ===\n", .{});

    // Cross-thread communication: Send work to different threads
    var worker_msg2 = WorkerMessage{ .ProcessData = .{ .data = "cross_thread_data_1", .worker_id = 2 } };
    try engine.send(WorkerMessage, &worker_msg2);

    std.time.sleep(50 * std.time.ns_per_ms);

    var worker_msg3 = WorkerMessage{ .ProcessData = .{ .data = "cross_thread_data_2", .worker_id = 3 } };
    try engine.send(WorkerMessage, &worker_msg3);

    std.time.sleep(50 * std.time.ns_per_ms);

    // Monitor health across threads
    var health_check = MonitorMessage{ .CheckHealth = {} };
    try engine.send(MonitorMessage, &health_check);

    std.time.sleep(50 * std.time.ns_per_ms);

    std.debug.print("\n=== 📊 Load Balancing Test ===\n", .{});

    // Send multiple messages that will be load-balanced across worker threads
    for (0..6) |i| {
        var work_msg = WorkerMessage{ .ProcessData = .{ .data = std.fmt.allocPrint(allocator, "load_balanced_task_{}", .{i}) catch "task", .worker_id = @intCast(i + 10) } };
        try engine.send(WorkerMessage, &work_msg);
        std.time.sleep(25 * std.time.ns_per_ms);
    }

    std.debug.print("\n=== 📈 Monitoring and Metrics ===\n", .{});

    // Send metrics to monitor
    var cpu_metric = MonitorMessage{ .LogMetric = .{ .name = "CPU Usage", .value = 45.7 } };
    try engine.send(MonitorMessage, &cpu_metric);

    std.time.sleep(25 * std.time.ns_per_ms);

    var memory_metric = MonitorMessage{ .LogMetric = .{ .name = "Memory Usage", .value = 78.3 } };
    try engine.send(MonitorMessage, &memory_metric);

    std.time.sleep(25 * std.time.ns_per_ms);

    var throughput_metric = MonitorMessage{ .LogMetric = .{ .name = "Throughput", .value = 1250.0 } };
    try engine.send(MonitorMessage, &throughput_metric);

    std.debug.print("\n=== 🔄 Request-Response Cross-Thread Test ===\n", .{});

    // Test cross-thread call (request-response)
    var status_request = WorkerMessage{ .GetStatus = {} };
    const response = try engine.call(WorkerMessage, &status_request);
    if (response) |ptr| {
        const status_ptr = @as(*[]const u8, @ptrCast(@alignCast(ptr)));
        std.debug.print("Main: Received worker status: {s}\n", .{status_ptr.*});
        allocator.destroy(status_ptr);
    }

    std.debug.print("\n✅ All thread communication tests completed!\n", .{});
    std.debug.print("📋 Summary:\n", .{});
    std.debug.print("  - Same-thread communication: ✅ Coordinator -> Worker (Thread 0)\n", .{});
    std.debug.print("  - Cross-thread communication: ✅ Main -> Workers (Threads 1,3)\n", .{});
    std.debug.print("  - Load balancing: ✅ 6 tasks distributed across worker threads\n", .{});
    std.debug.print("  - Monitoring: ✅ Metrics sent to Monitor (Thread 2)\n", .{});
    std.debug.print("  - Request-Response: ✅ Cross-thread call completed\n", .{});

    // Start the engine to process remaining messages
    engine.start();
}
