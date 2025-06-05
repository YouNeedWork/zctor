# Examples

This chapter provides practical examples demonstrating how to use zctor in real-world scenarios.

## Basic Examples

### Simple Counter Actor

A basic counter that tracks increments and decrements:

```zig
const std = @import("std");
const zctor = @import("zctor");
const ActorEngine = zctor.ActorEngine;
const Actor = zctor.Actor;

const CounterMessage = union(enum) {
    Increment: void,
    Decrement: void,
    Get: void,
    Set: i32,
    
    const Self = @This();
    
    const State = struct {
        value: i32 = 0,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{ .value = 0, .allocator = allocator };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch return null;
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .Increment => {
                state.value += 1;
                std.debug.print("Counter: {}\n", .{state.value});
            },
            .Decrement => {
                state.value -= 1;
                std.debug.print("Counter: {}\n", .{state.value});
            },
            .Get => {
                std.debug.print("Current value: {}\n", .{state.value});
            },
            .Set => |value| {
                state.value = value;
                std.debug.print("Counter set to: {}\n", .{state.value});
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var engine = try ActorEngine.init(gpa.allocator());
    defer engine.deinit();
    
    try engine.spawn(CounterMessage, CounterMessage.handle);
    
    // Send some messages
    var inc = CounterMessage.Increment;
    try engine.send(CounterMessage, &inc);
    
    var set = CounterMessage{ .Set = 42 };
    try engine.send(CounterMessage, &set);
    
    var get = CounterMessage.Get;
    try engine.send(CounterMessage, &get);
    
    engine.start();
}
```

### Echo Server

An echo server that responds to incoming messages:

```zig
const EchoMessage = union(enum) {
    Echo: []const u8,
    Ping: void,
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        _ = actor;
        switch (msg) {
            .Echo => |text| {
                std.debug.print("Echo: {s}\n", .{text});
            },
            .Ping => {
                std.debug.print("Pong!\n");
            },
        }
    }
};
```

## Intermediate Examples

### Request-Response Pattern

Implementing request-response communication between actors:

```zig
const RequestId = u32;

const DatabaseMessage = union(enum) {
    GetUser: struct { id: u32, request_id: RequestId },
    SetUser: struct { id: u32, name: []const u8, request_id: RequestId },
    
    const Self = @This();
    
    const User = struct {
        id: u32,
        name: []const u8,
    };
    
    const State = struct {
        users: std.HashMap(u32, User, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage),
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .users = std.HashMap(u32, User, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage).init(allocator),
                .allocator = allocator,
            };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch return null;
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .GetUser => |req| {
                if (state.users.get(req.id)) |user| {
                    std.debug.print("Found user {}: {s}\n", .{ user.id, user.name });
                } else {
                    std.debug.print("User {} not found\n", .{req.id});
                }
            },
            .SetUser => |req| {
                const user = User{ .id = req.id, .name = req.name };
                state.users.put(req.id, user) catch return null;
                std.debug.print("User {} saved: {s}\n", .{ req.id, req.name });
            },
        }
    }
};

const ClientMessage = union(enum) {
    SendRequest: void,
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        switch (msg) {
            .SendRequest => {
                // Send request to database actor
                var req = DatabaseMessage{ .SetUser = .{ .id = 1, .name = "Alice", .request_id = 123 } };
                actor.getContext().send(DatabaseMessage, &req) catch |err| {
                    std.debug.print("Failed to send request: {}\n", .{err});
                };
            },
        }
    }
};
```

### Publisher-Subscriber Pattern

Event-driven communication using pub-sub:

```zig
const EventMessage = union(enum) {
    Subscribe: struct { topic: []const u8, subscriber_id: u32 },
    Unsubscribe: struct { topic: []const u8, subscriber_id: u32 },
    Publish: struct { topic: []const u8, data: []const u8 },
    
    const Self = @This();
    
    const Subscription = struct {
        topic: []const u8,
        subscriber_id: u32,
    };
    
    const State = struct {
        subscriptions: std.ArrayList(Subscription),
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .subscriptions = std.ArrayList(Subscription).init(allocator),
                .allocator = allocator,
            };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch return null;
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .Subscribe => |sub| {
                const subscription = Subscription{
                    .topic = sub.topic,
                    .subscriber_id = sub.subscriber_id,
                };
                state.subscriptions.append(subscription) catch return null;
                std.debug.print("Subscriber {} subscribed to {s}\n", .{ sub.subscriber_id, sub.topic });
            },
            .Unsubscribe => |unsub| {
                for (state.subscriptions.items, 0..) |subscription, i| {
                    if (subscription.subscriber_id == unsub.subscriber_id and 
                        std.mem.eql(u8, subscription.topic, unsub.topic)) {
                        _ = state.subscriptions.orderedRemove(i);
                        std.debug.print("Subscriber {} unsubscribed from {s}\n", .{ unsub.subscriber_id, unsub.topic });
                        break;
                    }
                }
            },
            .Publish => |pub_msg| {
                std.debug.print("Publishing to {s}: {s}\n", .{ pub_msg.topic, pub_msg.data });
                for (state.subscriptions.items) |subscription| {
                    if (std.mem.eql(u8, subscription.topic, pub_msg.topic)) {
                        std.debug.print("  -> Notifying subscriber {}\n", .{subscription.subscriber_id});
                        // In a real implementation, you'd send the message to the subscriber
                    }
                }
            },
        }
    }
};
```

## Advanced Examples

### Supervisor Pattern

A supervisor that manages child actors and handles failures:

```zig
const SupervisorMessage = union(enum) {
    SpawnChild: struct { name: []const u8 },
    ChildFailed: struct { name: []const u8, error_msg: []const u8 },
    RestartChild: struct { name: []const u8 },
    GetStatus: void,
    
    const Self = @This();
    
    const ChildInfo = struct {
        name: []const u8,
        status: enum { running, failed, restarting },
        restart_count: u32,
    };
    
    const State = struct {
        children: std.HashMap([]const u8, ChildInfo, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .children = std.HashMap([]const u8, ChildInfo, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
                .allocator = allocator,
            };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch return null;
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .SpawnChild => |spawn| {
                const child = ChildInfo{
                    .name = spawn.name,
                    .status = .running,
                    .restart_count = 0,
                };
                state.children.put(spawn.name, child) catch return null;
                std.debug.print("Spawned child: {s}\n", .{spawn.name});
            },
            .ChildFailed => |failed| {
                if (state.children.getPtr(failed.name)) |child| {
                    child.status = .failed;
                    std.debug.print("Child {s} failed: {s}\n", .{ failed.name, failed.error_msg });
                    
                    // Auto-restart if restart count is below threshold
                    if (child.restart_count < 3) {
                        var restart = Self{ .RestartChild = .{ .name = failed.name } };
                        // In a real implementation, you'd send this message back to yourself
                        _ = restart;
                    }
                }
            },
            .RestartChild => |restart| {
                if (state.children.getPtr(restart.name)) |child| {
                    child.status = .restarting;
                    child.restart_count += 1;
                    std.debug.print("Restarting child: {s} (attempt {})\n", .{ restart.name, child.restart_count });
                    
                    // Simulate restart delay and success
                    child.status = .running;
                    std.debug.print("Child {s} restarted successfully\n", .{restart.name});
                }
            },
            .GetStatus => {
                std.debug.print("Supervisor Status:\n");
                var iterator = state.children.iterator();
                while (iterator.next()) |entry| {
                    const child = entry.value_ptr.*;
                    std.debug.print("  {s}: {} (restarts: {})\n", .{ child.name, child.status, child.restart_count });
                }
            },
        }
    }
};
```

### Performance Monitoring

An actor that monitors system performance:

```zig
const MonitorMessage = union(enum) {
    StartMonitoring: void,
    StopMonitoring: void,
    GetMetrics: void,
    RecordMetric: struct { name: []const u8, value: f64 },
    
    const Self = @This();
    
    const Metric = struct {
        name: []const u8,
        value: f64,
        timestamp: i64,
    };
    
    const State = struct {
        metrics: std.ArrayList(Metric),
        monitoring: bool,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .metrics = std.ArrayList(Metric).init(allocator),
                .monitoring = false,
                .allocator = allocator,
            };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch return null;
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .StartMonitoring => {
                state.monitoring = true;
                std.debug.print("Performance monitoring started\n");
            },
            .StopMonitoring => {
                state.monitoring = false;
                std.debug.print("Performance monitoring stopped\n");
            },
            .GetMetrics => {
                std.debug.print("Performance Metrics:\n");
                for (state.metrics.items) |metric| {
                    std.debug.print("  {s}: {d:.2} ({})\n", .{ metric.name, metric.value, metric.timestamp });
                }
            },
            .RecordMetric => |record| {
                if (state.monitoring) {
                    const metric = Metric{
                        .name = record.name,
                        .value = record.value,
                        .timestamp = std.time.timestamp(),
                    };
                    state.metrics.append(metric) catch return null;
                    std.debug.print("Recorded metric {s}: {d:.2}\n", .{ record.name, record.value });
                }
            },
        }
    }
};
```

## Real-World Use Cases

### Chat Server

A simple chat server using multiple actor types:

```zig
// User session actor
const SessionMessage = union(enum) {
    Connect: struct { user_id: u32, username: []const u8 },
    Disconnect: void,
    SendMessage: struct { content: []const u8 },
    ReceiveMessage: struct { from: []const u8, content: []const u8 },
};

// Chat room actor
const RoomMessage = union(enum) {
    Join: struct { user_id: u32, username: []const u8 },
    Leave: struct { user_id: u32 },
    Broadcast: struct { from: []const u8, content: []const u8 },
    GetUsers: void,
};

// Message router actor
const RouterMessage = union(enum) {
    RouteToUser: struct { user_id: u32, message: []const u8 },
    RouteToRoom: struct { room_id: u32, message: []const u8 },
    RegisterUser: struct { user_id: u32, session_ref: *Actor(SessionMessage) },
};
```

### Data Processing Pipeline

A data processing pipeline with multiple stages:

```zig
// Data ingestion actor
const IngestMessage = union(enum) {
    ProcessFile: []const u8,
    ProcessData: []const u8,
};

// Data transformation actor
const TransformMessage = union(enum) {
    Transform: struct { data: []const u8, format: enum { json, csv, xml } },
    ValidateData: []const u8,
};

// Data output actor
const OutputMessage = union(enum) {
    SaveToDatabase: []const u8,
    SaveToFile: struct { filename: []const u8, data: []const u8 },
    SendToApi: struct { endpoint: []const u8, payload: []const u8 },
};
```

## Testing Examples

### Unit Testing Actors

```zig
const testing = std.testing;

test "Counter actor increments correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var engine = try ActorEngine.init(gpa.allocator());
    defer engine.deinit();
    
    try engine.spawn(CounterMessage, CounterMessage.handle);
    
    // Send increment message
    var inc = CounterMessage.Increment;
    try engine.send(CounterMessage, &inc);
    
    // Verify state (in a real test, you'd need a way to inspect actor state)
    // This is a simplified example
}

test "Echo actor responds correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var engine = try ActorEngine.init(gpa.allocator());
    defer engine.deinit();
    
    try engine.spawn(EchoMessage, EchoMessage.handle);
    
    var echo = EchoMessage{ .Echo = "test message" };
    try engine.send(EchoMessage, &echo);
    
    // In a real test, you'd capture output or use a test harness
}
```

## Next Steps

These examples demonstrate the flexibility and power of zctor. To learn more:

- [Best Practices](./07-best-practices.md) - Optimization and design patterns
- [Advanced Topics](./08-advanced-topics.md) - Complex scenarios and performance tuning
- [API Reference](./05-api-reference.md) - Complete API documentation