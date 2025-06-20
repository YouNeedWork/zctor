const std = @import("std");
const context = @import("context.zig");
const xev = @import("xev");
const ActorInterface = @import("actor_interface.zig");
const Actor = @import("actor.zig");
const ActorThread = @import("actor_thread.zig");

allocator: std.mem.Allocator,
actor_threads: [128]*ActorThread,
wg: std.Thread.WaitGroup,
threads: [128]std.Thread,
thread_count: usize,
thread_idx: usize,
// Actor type name -> list of thread indices that have this actor type
actor_registry: std.StringArrayHashMap(std.ArrayList(usize)),
// Round-robin counter for load balancing
round_robin_counter: std.atomic.Value(usize),

const Self = @This();

pub fn init(allocator: std.mem.Allocator) !*Self {
    const self = try allocator.create(Self);
    self.allocator = allocator;

    const cpu_count = try std.Thread.getCpuCount();
    self.thread_count = cpu_count;
    self.thread_idx = 0;

    self.actor_registry = std.StringArrayHashMap(std.ArrayList(usize)).init(allocator);
    self.round_robin_counter = std.atomic.Value(usize).init(0);

    self.wg.reset();
    return self;
}

pub fn deinit(self: *Self) void {
    for (0..self.thread_idx) |i| {
        self.threads[i].join();
    }

    for (0..self.thread_idx) |i| {
        self.actor_threads[i].deinit(self.allocator);
    }

    // Clean up actor registry
    var iter = self.actor_registry.iterator();
    while (iter.next()) |entry| {
        entry.value_ptr.deinit();
    }
    self.actor_registry.deinit();

    self.allocator.destroy(self);
}

pub fn start(self: *Self) void {
    self.wg.wait();
}

pub fn stop(self: *Self) void {
    for (0..self.thread_idx) |i| {
        self.actor_threads[i].stop();
        self.wg.finish();
    }
}

pub fn spawn(self: *Self, actor_thread: *ActorThread) !void {
    if (self.thread_idx >= self.thread_count) {
        return error.TooManyThreads;
    }

    try actor_thread.init_ctx(self, @bitCast(self.thread_idx));
    try actor_thread.run();

    self.actor_threads[self.thread_idx] = actor_thread;
    const current_idx = self.thread_idx;

    // Register all actor types in this thread
    try self.registerActorTypesFromThread(actor_thread, current_idx);

    self.thread_idx += 1;

    const t = try std.Thread.spawn(.{}, thread_run, .{ self, current_idx });
    self.threads[current_idx] = t;
    self.wg.start();
}

/// Register all actor types from a thread in the global registry
fn registerActorTypesFromThread(self: *Self, actor_thread: *ActorThread, thread_idx: usize) !void {
    var iter = actor_thread.actors.iterator();
    while (iter.next()) |entry| {
        const actor_type_name = entry.key_ptr.*;

        // Get or create the thread list for this actor type
        const result = try self.actor_registry.getOrPut(actor_type_name);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList(usize).init(self.allocator);
        }

        // Add this thread to the list for this actor type
        try result.value_ptr.append(thread_idx);
        std.debug.print("Registered actor type '{s}' on thread {}\n", .{ actor_type_name, thread_idx });
    }
}

fn thread_run(self: *Self, thread_idx: usize) void {
    defer self.wg.finish();
    const actor_thread = self.actor_threads[thread_idx];

    actor_thread.start_loop() catch |err| {
        std.debug.print("Thread {} failed to start loop: {}\n", .{ thread_idx, err });
        return;
    };
}

/// Send a message to an actor of type T
/// Uses round-robin load balancing across all threads that have this actor type
pub fn send(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !void {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    const actor_type_name = comptime @typeName(Actor.Actor(T));

    // Get the list of threads that have this actor type
    if (self.actor_registry.get(actor_type_name)) |thread_list| {
        if (thread_list.items.len == 0) {
            return error.ActorNotFound;
        }

        // Use round-robin to select a thread from the available threads
        const counter = self.round_robin_counter.fetchAdd(1, .monotonic);
        const selected_thread_idx = counter % thread_list.items.len;
        const target_thread = thread_list.items[selected_thread_idx];

        // Load balancing: sending to thread target_thread (option selected_thread_idx + 1 of thread_list.items.len)

        return self.actor_threads[target_thread].send(T, typed_ptr);
    }

    return error.ActorNotFound;
}

/// Send a message directly to a specific actor instance
pub fn send_to_actor(_: *Self, actor: *Actor, comptime T: anytype, msg_ptr: *anyopaque) !void {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    return actor.send(typed_ptr);
}

/// Call an actor of type T and wait for response
/// Uses round-robin load balancing across all threads that have this actor type
pub fn call(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !?*anyopaque {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    const actor_type_name = comptime @typeName(Actor.Actor(T));

    // Get the list of threads that have this actor type
    if (self.actor_registry.get(actor_type_name)) |thread_list| {
        if (thread_list.items.len == 0) {
            return error.ActorNotFound;
        }

        // Use round-robin to select a thread from the available threads
        const counter = self.round_robin_counter.fetchAdd(1, .monotonic);
        const selected_thread_idx = counter % thread_list.items.len;
        const target_thread = thread_list.items[selected_thread_idx];

        return self.actor_threads[target_thread].call(T, typed_ptr);
    }

    return error.ActorNotFound;
}

/// Broadcast a message to all threads that have this actor type (useful for pub-sub patterns)
pub fn broadcast(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !void {
    const typed_ptr: *T = @ptrCast(@alignCast(msg_ptr));
    const actor_type_name = comptime @typeName(Actor.Actor(T));

    // Get the list of threads that have this actor type
    if (self.actor_registry.get(actor_type_name)) |thread_list| {
        for (thread_list.items) |thread_idx| {
            try self.actor_threads[thread_idx].send(T, typed_ptr);
        }
    }
}

/// Get the number of active threads
pub fn getThreadCount(self: *Self) usize {
    return self.thread_idx;
}
/// Get actor registry for debugging
pub fn getActorRegistry(self: *Self) *const std.StringArrayHashMap(std.ArrayList(usize)) {
    return &self.actor_registry;
}
