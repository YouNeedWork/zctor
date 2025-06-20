# Multi-Threading in zctor

This document provides a comprehensive guide to zctor's multi-threading capabilities, including architecture, patterns, and best practices.

## Overview

zctor provides a sophisticated multi-threading actor framework with:

- **True Parallelism**: Actors run on separate OS threads
- **Intelligent Routing**: Automatic message routing based on actor registry
- **Load Balancing**: Round-robin distribution across multiple instances
- **Cross-Thread Communication**: Seamless messaging between threads
- **Type Safety**: Compile-time guarantees for message types

## Architecture

### Core Components

```
┌─────────────────┐
│   ActorEngine   │  ← Manages entire system
├─────────────────┤
│ Actor Registry  │  ← Maps actor types to threads
│ Load Balancer   │  ← Round-robin distribution
│ Thread Manager  │  ← Spawns and manages threads
└─────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌─────────┐ ┌─────────┐
│Thread 0 │ │Thread 1 │  ← Individual actor threads
├─────────┤ ├─────────┤
│Actor A  │ │Actor A  │  ← Same type, different instances
│Actor B  │ │Actor C  │  ← Different types
└─────────┘ └─────────┘
```

### Actor Registry

The actor registry maps actor types to available threads:

```zig
// Registry structure
HashMap<String, ArrayList<usize>>
// Example:
"Actor(WorkerMessage)" -> [0, 1, 2, 3, 4]  // 5 worker threads
"Actor(MonitorMessage)" -> [5]              // 1 monitor thread
```

### Message Routing

1. **Type Resolution**: Determine actor type from message
2. **Registry Lookup**: Find threads that have this actor type
3. **Load Balancing**: Select thread using round-robin
4. **Message Delivery**: Send to selected thread's mailbox

## Threading Patterns

### 1. Single Actor Type, Multiple Instances

**Use Case**: Load balancing identical workers

```zig
// Create multiple worker instances
for (0..5) |i| {
    const worker_thread = try ActorThread.init(allocator);
    try worker_thread.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread);
}

// Messages automatically load-balanced
try engine.send(WorkerMessage, &task1); // → Thread 0
try engine.send(WorkerMessage, &task2); // → Thread 1
try engine.send(WorkerMessage, &task3); // → Thread 2
```

**Registry**: `WorkerMessage -> [0, 1, 2, 3, 4]`

### 2. Different Actor Types, Separate Threads

**Use Case**: Service separation and isolation

```zig
// Database service on Thread 0
const db_thread = try ActorThread.init(allocator);
try db_thread.registerActor(try Actor(DatabaseMessage).init(allocator, DatabaseMessage.handle));
try engine.spawn(db_thread);

// Web service on Thread 1
const web_thread = try ActorThread.init(allocator);
try web_thread.registerActor(try Actor(WebMessage).init(allocator, WebMessage.handle));
try engine.spawn(web_thread);

// Monitor service on Thread 2
const monitor_thread = try ActorThread.init(allocator);
try monitor_thread.registerActor(try Actor(MonitorMessage).init(allocator, MonitorMessage.handle));
try engine.spawn(monitor_thread);
```

**Registry**:
```
DatabaseMessage -> [0]
WebMessage -> [1]
MonitorMessage -> [2]
```

### 3. Mixed Pattern: Multiple Types + Multiple Instances

**Use Case**: Complex systems with both service separation and load balancing

```zig
// Multiple workers for CPU-intensive tasks
for (0..3) |i| {
    const worker_thread = try ActorThread.init(allocator);
    try worker_thread.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread);
}

// Multiple database connections
for (0..2) |i| {
    const db_thread = try ActorThread.init(allocator);
    try db_thread.registerActor(try Actor(DatabaseMessage).init(allocator, DatabaseMessage.handle));
    try engine.spawn(db_thread);
}

// Single monitor
const monitor_thread = try ActorThread.init(allocator);
try monitor_thread.registerActor(try Actor(MonitorMessage).init(allocator, MonitorMessage.handle));
try engine.spawn(monitor_thread);
```

**Registry**:
```
WorkerMessage -> [0, 1, 2]      // Load balanced
DatabaseMessage -> [3, 4]       // Load balanced
MonitorMessage -> [5]           // Single instance
```

## Messaging Patterns

### 1. Fire-and-Forget (`send`)

**Characteristics**:
- Asynchronous
- No return value
- Load balanced automatically
- Best performance

```zig
var task = WorkerMessage{ .ProcessData = .{ .data = "example", .id = 123 } };
try engine.send(WorkerMessage, &task);
// Message sent to one of the available worker threads
```

### 2. Request-Response (`call`)

**Characteristics**:
- Synchronous
- Returns a value
- Load balanced automatically
- Blocks until response

```zig
var request = CalculatorMessage{ .Add = .{ .a = 10, .b = 5 } };
const response = try engine.call(CalculatorMessage, &request);
if (response) |ptr| {
    const result = @as(*i32, @ptrCast(@alignCast(ptr)));
    std.debug.print("Result: {}\n", .{result.*});
    allocator.destroy(result);
}
```

### 3. Broadcast (`broadcast`)

**Characteristics**:
- One-to-many
- Sent to ALL instances of actor type
- Asynchronous
- No return values

```zig
var notification = NotificationMessage{ .Alert = "System maintenance in 5 minutes" };
try engine.broadcast(NotificationMessage, &notification);
// Sent to ALL NotificationMessage actors across all threads
```

## Load Balancing

### Round-Robin Algorithm

zctor uses a round-robin algorithm for load balancing:

```zig
// Internal implementation (simplified)
const counter = self.round_robin_counter.fetchAdd(1, .monotonic);
const selected_thread_idx = counter % thread_list.items.len;
const target_thread = thread_list.items[selected_thread_idx];
```

### Load Balancing Visualization

```
Threads: [0, 1, 2, 3, 4]
Counter: 0, 1, 2, 3, 4, 5, 6, 7, 8, ...

Task 1: counter=0 → 0 % 5 = 0 → Thread 0
Task 2: counter=1 → 1 % 5 = 1 → Thread 1
Task 3: counter=2 → 2 % 5 = 2 → Thread 2
Task 4: counter=3 → 3 % 5 = 3 → Thread 3
Task 5: counter=4 → 4 % 5 = 4 → Thread 4
Task 6: counter=5 → 5 % 5 = 0 → Thread 0 (wrap around)
```

### Benefits

1. **Even Distribution**: Tasks spread evenly across threads
2. **Automatic**: No manual thread selection required
3. **Scalable**: Works with any number of threads
4. **Fair**: No thread gets overloaded

## Thread Safety

### Actor State

Each actor instance has its own state, isolated from other instances:

```zig
// Thread-safe: each actor has separate state
const MyState = struct {
    counter: u32 = 0,
    data: []const u8 = "",
};

pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
    // Get this actor's state (thread-local)
    const state = actor.getState(MyState) orelse blk: {
        const new_state = actor.getAllocator().create(MyState) catch return null;
        new_state.* = MyState{};
        actor.setState(new_state);
        break :blk new_state;
    };
    
    // Safe to modify - only this thread accesses this state
    state.counter += 1;
    
    // ... handle message
}
```

### Message Passing

Messages are copied between threads, ensuring no shared mutable state:

```zig
// Message is copied to target thread's mailbox
var msg = WorkerMessage{ .ProcessData = .{ .data = "safe", .id = 123 } };
try engine.send(WorkerMessage, &msg);
// Original 'msg' can be safely modified or destroyed
```

### Allocator Usage

Each actor has its own allocator for thread-safe memory management:

```zig
pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
    // Thread-safe allocator
    const allocator = actor.getAllocator();
    
    // Safe to allocate on this thread
    const result = allocator.create(i32) catch return null;
    result.* = 42;
    
    return @ptrCast(result);
}
```

## Performance Considerations

### Thread Count

**Optimal thread count** typically equals CPU core count:

```zig
// Get CPU core count
const cpu_count = std.Thread.getCpuCount() catch 4;

// Create worker threads
for (0..cpu_count) |i| {
    const worker_thread = try ActorThread.init(allocator);
    try worker_thread.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread);
}
```

### Message Size

- **Small messages**: Better performance, less memory usage
- **Large messages**: Consider using pointers or references
- **Complex data**: Use efficient serialization

### Batching

For high-throughput scenarios, consider message batching:

```zig
const BatchMessage = union(enum) {
    ProcessBatch: struct { items: []WorkItem },
    ProcessSingle: WorkItem,
};
```

## Best Practices

### 1. Actor Design

- **Single Responsibility**: Each actor type should have one clear purpose
- **Stateless When Possible**: Easier to scale and debug
- **Immutable Messages**: Prevent data races

### 2. Thread Organization

- **Separate by Function**: Different services on different threads
- **Load Balance by Load**: CPU-intensive tasks across multiple threads
- **Isolate Critical Services**: Important services on dedicated threads

### 3. Error Handling

```zig
pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
    switch (msg) {
        .ProcessData => |data| {
            // Handle errors gracefully
            processData(data) catch |err| {
                std.debug.print("Error processing data: {}\n", .{err});
                return null;
            };
        },
    }
    return null;
}
```

### 4. Resource Management

- **Clean up responses**: Always destroy response pointers from `call()`
- **Manage actor state**: Use `resetState()` when appropriate
- **Monitor memory usage**: Watch for memory leaks in long-running actors

## Debugging Multi-Threading

### Thread Identification

Use thread IDs to track message flow:

```zig
pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
    const thread_id = actor.getContext().thread_id;
    std.debug.print("[Thread {}] Processing message\n", .{thread_id});
    // ...
}
```

### Registry Inspection

Check actor registry for debugging:

```zig
const registry = engine.getActorRegistry();
var iter = registry.iterator();
while (iter.next()) |entry| {
    std.debug.print("Actor type: {s}\n", .{entry.key_ptr.*});
    std.debug.print("Threads: [");
    for (entry.value_ptr.items, 0..) |thread_id, i| {
        if (i > 0) std.debug.print(", ");
        std.debug.print("{}", .{thread_id});
    }
    std.debug.print("]\n");
}
```

### Load Balancing Verification

Enable load balancing debug output:

```zig
// In actor_engine.zig send() method
std.debug.print("Load balancing: sending to thread {} (option {} of {})\n", 
    .{ target_thread, selected_thread_idx + 1, thread_list.items.len });
```

## Common Patterns

### Worker Pool

```zig
// Create worker pool
const WORKER_COUNT = 4;
for (0..WORKER_COUNT) |_| {
    const worker_thread = try ActorThread.init(allocator);
    try worker_thread.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread);
}

// Submit work
for (tasks) |task| {
    var work_msg = WorkerMessage{ .Process = task };
    try engine.send(WorkerMessage, &work_msg);
}
```

### Service Mesh

```zig
// Database service
const db_thread = try ActorThread.init(allocator);
try db_thread.registerActor(try Actor(DatabaseService).init(allocator, DatabaseService.handle));
try engine.spawn(db_thread);

// Web service
const web_thread = try ActorThread.init(allocator);
try web_thread.registerActor(try Actor(WebService).init(allocator, WebService.handle));
try engine.spawn(web_thread);

// Auth service
const auth_thread = try ActorThread.init(allocator);
try auth_thread.registerActor(try Actor(AuthService).init(allocator, AuthService.handle));
try engine.spawn(auth_thread);
```

### Publisher-Subscriber

```zig
// Multiple subscribers for each topic
for (0..3) |_| {
    const news_thread = try ActorThread.init(allocator);
    try news_thread.registerActor(try Actor(NewsSubscriber).init(allocator, NewsSubscriber.handle));
    try engine.spawn(news_thread);
}

// Publish to all subscribers
var news = NewsSubscriber{ .Breaking = "Important news!" };
try engine.broadcast(NewsSubscriber, &news);
```

This multi-threading architecture provides the foundation for building scalable, high-performance concurrent applications with zctor.
