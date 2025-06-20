# zctor

A high-performance, multi-threaded actor framework for Zig, providing scalable concurrent message-passing with intelligent load balancing and cross-thread communication.

📖 **[View Complete Documentation](https://youneedwork.github.io/zctor/)** - Comprehensive documentation website with examples, API reference, and guides.

## Overview

zctor is a production-ready Zig implementation of the Actor Model, designed for building high-performance concurrent applications. The framework features true multi-threading with intelligent actor routing, load balancing, and comprehensive messaging patterns including broadcast, publisher-subscriber, and request-response communication.

### Key Features

- **🚀 True Multi-Threading**: Distribute actors across multiple threads with automatic CPU core utilization
- **⚖️ Intelligent Load Balancing**: Round-robin distribution across multiple actor instances
- **📡 Broadcast Messaging**: One-to-many communication patterns for pub-sub systems
- **🔄 Cross-Thread Communication**: Seamless messaging between actors on different threads
- **🎯 Request-Response Pattern**: Synchronous call operations across thread boundaries
- **🧠 Smart Actor Registry**: Automatic thread routing based on actor type registration
- **🛡️ Type Safety**: Compile-time guarantees with Zig's type system
- **📊 Built-in State Management**: Thread-safe state management within actors
- **⚡ High Performance**: Leverages libxev for efficient event loop management
- **🔧 Minimal Dependencies**: Only depends on libxev for event handling

## Documentation

📚 **[Complete Documentation Website](https://youneedwork.github.io/zctor/)** - Visit our comprehensive documentation site for:

- **[Quick Start Guide](https://youneedwork.github.io/zctor/#quick-start)** - Get up and running in minutes
- **[API Reference](https://youneedwork.github.io/zctor/#api-reference)** - Complete API documentation
- **[Examples](https://youneedwork.github.io/zctor/#examples)** - Real-world usage examples
- **[Best Practices](https://youneedwork.github.io/zctor/#best-practices)** - Optimization tips and patterns
- **[Advanced Topics](https://youneedwork.github.io/zctor/#advanced-topics)** - Complex patterns and customization

## Requirements

- **Zig**: Version 0.14.0 or higher
- **libxev**: Automatically managed as a dependency

## Installation

### From Source

```bash
git clone https://github.com/YouNeedWork/zctor.git
cd zctor
zig build
```

### Using as a Library

In your project's `build.zig`, add zctor as a dependency:

```zig
// In build.zig
const zctor_dep = b.dependency("zctor", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zctor", zctor_dep.module("zctor"));
```

Then in your Zig code:

```zig
const zctor = @import("zctor");
const ActorEngine = zctor.ActorEngine;
const Actor = zctor.Actor;
```

## Quick Start

### Basic Multi-Threaded Actor Example

```zig
const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Define your message types
const CalculatorMessage = union(enum) {
    Add: struct { a: i32, b: i32 },
    Multiply: struct { a: i32, b: i32 },

    const Self = @This();

    // Message handler - returns results for call operations
    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .Add => |op| {
                std.debug.print("[Thread {}] Computing {} + {}\n", .{ thread_id, op.a, op.b });
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a + op.b;
                return @ptrCast(result_ptr);
            },
            .Multiply => |op| {
                std.debug.print("[Thread {}] Computing {} * {}\n", .{ thread_id, op.a, op.b });
                const result_ptr = actor.getAllocator().create(i32) catch return null;
                result_ptr.* = op.a * op.b;
                return @ptrCast(result_ptr);
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create the multi-threaded actor engine
    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    // Create multiple threads with calculator actors for load balancing
    const thread1 = try ActorThread.init(allocator);
    try thread1.registerActor(try Actor(CalculatorMessage).init(allocator, CalculatorMessage.handle));
    try engine.spawn(thread1);

    const thread2 = try ActorThread.init(allocator);
    try thread2.registerActor(try Actor(CalculatorMessage).init(allocator, CalculatorMessage.handle));
    try engine.spawn(thread2);

    // Send messages (automatically load-balanced across threads)
    var add_msg = CalculatorMessage{ .Add = .{ .a = 10, .b = 5 } };
    try engine.send(CalculatorMessage, &add_msg);

    var mul_msg = CalculatorMessage{ .Multiply = .{ .a = 7, .b = 3 } };
    try engine.send(CalculatorMessage, &mul_msg);

    // Request-response pattern (call)
    var call_msg = CalculatorMessage{ .Add = .{ .a = 20, .b = 15 } };
    const response = try engine.call(CalculatorMessage, &call_msg);
    if (response) |ptr| {
        const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
        std.debug.print("Call result: {}\n", .{result_ptr.*});
        allocator.destroy(result_ptr);
    }

    // Start the engine
    engine.start();
}
```

### Available Examples

Run these examples to see different messaging patterns:

```bash
# Basic request-response pattern
zig build run-call

# Multi-threaded actors with load balancing
zig build run-multi

# Broadcast messaging (one-to-many)
zig build run-broadcast

# Cross-thread communication patterns
zig build run-thread-comm

# Publisher-subscriber pattern
zig build run-pubsub

# Load balancing demonstration
zig build run-load-balance
```

## Building

### Build the Library and Executable

```bash
zig build
```

### Run the Example

```bash
zig build run
```

### Build in Release Mode

```bash
zig build -Doptimize=ReleaseFast
```

## Testing

Run the test suite:

```bash
zig build test
```

This will run all unit tests for the library components.

## Architecture

### Core Components

- **ActorEngine**: Manages the multi-threaded actor system with intelligent routing and load balancing
- **ActorThread**: Handles actors within a single thread context with event loop management
- **Actor(T)**: Generic actor type that processes messages of type T with thread-safe state management
- **Context**: Provides runtime context, thread information, and services to actors
- **Actor Registry**: Maps actor types to available threads for smart message routing

### Multi-Threading Features

#### **🎯 Smart Message Routing**

- **Actor Registry**: Automatically tracks which threads have which actor types
- **Load Balancing**: Round-robin distribution across multiple instances of the same actor type
- **Cross-Thread Calls**: Request-response pattern works seamlessly across thread boundaries

#### **📡 Messaging Patterns**

- **`send()`**: Fire-and-forget messaging with automatic thread routing
- **`call()`**: Synchronous request-response across threads
- **`broadcast()`**: One-to-many messaging to all instances of an actor type

#### **⚖️ Load Balancing**

```zig
// Multiple worker instances automatically load-balanced
const worker1 = try ActorThread.init(allocator);
try worker1.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
try engine.spawn(worker1);

const worker2 = try ActorThread.init(allocator);
try worker2.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
try engine.spawn(worker2);

// Messages automatically distributed round-robin between worker1 and worker2
try engine.send(WorkerMessage, &task1); // → worker1
try engine.send(WorkerMessage, &task2); // → worker2
try engine.send(WorkerMessage, &task3); // → worker1 (round-robin)
```

### Message Flow

1. **Message Submission**: Messages sent via `ActorEngine.send()`, `call()`, or `broadcast()`
2. **Thread Routing**: Actor registry determines target thread(s) based on actor type
3. **Load Balancing**: Round-robin selection when multiple instances available
4. **Queue Processing**: Messages queued in thread-specific mailboxes (FIFO)
5. **Event Loop**: Each thread's event loop processes messages asynchronously
6. **Handler Execution**: Messages handled by actor's message handler function
7. **Response Handling**: For `call()` operations, responses sent back via one-shot channels

### State Management

Actors can maintain internal state using the built-in state management system:

```zig
const State = struct {
    counter: u32 = 0,
    data: []const u8 = "",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*State {
        const s = try allocator.create(State);
        s.* = State{
            .counter = 0,
            .data = "",
            .allocator = allocator,
        };
        return s;
    }
};

pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    // Get or create state
    var state = actor.getState(State) orelse blk: {
        const new_state = State.init(actor.getAllocator()) catch |err| {
            std.debug.print("Failed to initialize state: {}\n", .{err});
            return null;
        };
        actor.setState(new_state);
        break :blk actor.getState(State).?;
    };

    // Use state...
    state.counter += 1;

    switch (msg) {
        .Hello => |name| {
            std.debug.print("Hello {s}, counter: {}\n", .{ name, state.counter });
        },
        // ... other message handlers
    }
}
```

## API Reference

### ActorEngine

#### Core Methods

- `init(allocator: Allocator) !*ActorEngine` - Create a new multi-threaded actor engine
- `spawn(actor_thread: *ActorThread) !void` - Spawn a new actor thread
- `start() void` - Start the engine and begin processing messages
- `deinit() void` - Clean up the engine and all threads

#### Messaging Methods

- `send(comptime T: type, msg: *T) !void` - Send fire-and-forget message with load balancing
- `call(comptime T: type, msg: *T) !?*anyopaque` - Synchronous request-response across threads
- `broadcast(comptime T: type, msg: *T) !void` - Send message to all instances of actor type

#### Utility Methods

- `getThreadCount() usize` - Get number of active threads
- `getActorRegistry() *const StringArrayHashMap(ArrayList(usize))` - Get actor registry for debugging

### ActorThread

- `init(allocator: Allocator) !*ActorThread` - Create a new actor thread
- `registerActor(actor: *Actor(T)) !void` - Register an actor on this thread
- `send(comptime T: type, msg: *T) !void` - Send message to actor on this thread
- `call(comptime T: type, msg: *T) !?*anyopaque` - Call actor on this thread
- `deinit(allocator: Allocator) void` - Clean up the thread

### Actor(T)

#### State Management

- `getState(comptime S: type) ?*S` - Get typed state (thread-safe)
- `setState(state: *anyopaque) void` - Set actor state
- `resetState() void` - Clear actor state

#### Context & Resources

- `getAllocator() Allocator` - Get the actor's allocator
- `getContext() *Context` - Get runtime context (includes thread_id)

#### Message Handling

- `send(msg_ptr: *anyopaque) !void` - Send message to this actor instance
- `call(msg_ptr: *anyopaque) !*anyopaque` - Call this actor instance

## Examples

zctor includes comprehensive examples demonstrating different messaging patterns and multi-threading capabilities:

### 🎯 **Basic Examples**

#### **Request-Response Pattern**

```bash
zig build run-call
```

Demonstrates synchronous request-response communication with result handling.

#### **Multi-Threaded Actors**

```bash
zig build run-multi
```

Shows actors running on different threads with cross-thread communication.

### 📡 **Advanced Messaging Patterns**

#### **Broadcast Messaging**

```bash
zig build run-broadcast
```

One-to-many communication where messages are sent to all subscribers simultaneously.

- News broadcasts to multiple subscriber threads
- Event notifications across the system
- Real-time data distribution

#### **Publisher-Subscriber Pattern**

```bash
zig build run-pubsub
```

Real-world pub-sub system with multiple topic types:

- Stock market data feeds
- News distribution
- Chat messaging systems

#### **Cross-Thread Communication**

```bash
zig build run-thread-comm
```

Demonstrates various thread communication patterns:

- Same-thread messaging (intra-thread)
- Cross-thread messaging (inter-thread)
- Load balancing across threads
- Monitoring and metrics collection

#### **Load Balancing**

```bash
zig build run-load-balance
```

Shows intelligent load balancing across multiple worker instances:

- Round-robin task distribution
- Multiple actor instances on different threads
- Performance statistics collection
- Parallel task processing

### 📊 **Example Output**

Each example shows thread IDs to demonstrate true multi-threading:

```
Registered actor type 'WorkerMessage' -> Threads: [0, 1, 2, 3, 4]
Load balancing: sending to thread 0 (option 1 of 5)
[Thread 0] 🔄 Processing compute task 1 (complexity: 3)
Load balancing: sending to thread 1 (option 2 of 5)
[Thread 1] 🔄 Processing compute task 2 (complexity: 1)
Load balancing: sending to thread 2 (option 3 of 5)
[Thread 2] 🔄 Processing compute task 3 (complexity: 5)
```

### 🏗️ **Real-World Use Cases**

These examples demonstrate patterns suitable for:

- **Web servers** with request distribution
- **Data processing pipelines** with parallel workers
- **Real-time systems** with event broadcasting
- **Microservices** with inter-service communication
- **Game servers** with player message handling
- **IoT systems** with sensor data aggregation

## Contributing

Contributions are welcome! Please see our [comprehensive contributing guide](https://youneedwork.github.io/zctor/#contributing) for detailed information.

**Quick steps:**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

The documentation website is automatically generated and deployed via GitHub Actions whenever changes are pushed to the main branch.

## License

See the [LICENSE](LICENSE) file for license information.

## Acknowledgments

- Built with [libxev](https://github.com/mitchellh/libxev) for efficient event handling
- Inspired by the Actor Model as implemented in Erlang, Elixir, and Akka
