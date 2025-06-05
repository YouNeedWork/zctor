# Quick Start

This guide will get you up and running with zctor in just a few minutes. We'll build a simple chat-like system to demonstrate the core concepts.

## Your First Actor

Let's start with a simple "Hello World" actor that can receive and respond to messages.

### Step 1: Define Message Types

First, define the types of messages your actor can handle:

```zig
const std = @import("std");
const zctor = @import("zctor");
const ActorEngine = zctor.ActorEngine;
const Actor = zctor.Actor;

// Define your message types
const ChatMessage = union(enum) {
    Hello: []const u8,
    Ping: u32,
    Stop: void,
    
    const Self = @This();
    
    // Message handler - this is where the magic happens
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        switch (msg) {
            .Hello => |name| {
                std.debug.print("👋 Hello, {s}!\n", .{name});
            },
            .Ping => |value| {
                std.debug.print("🏓 Ping: {}\n", .{value});
            },
            .Stop => {
                std.debug.print("🛑 Stopping actor\n");
            },
        }
    }
};
```

### Step 2: Create and Run the Actor System

Now let's create the actor system and send some messages:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create the actor engine
    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    // Spawn an actor with our message handler
    try engine.spawn(ChatMessage, ChatMessage.handle);

    // Send some messages
    var hello_msg = ChatMessage{ .Hello = "World" };
    try engine.send(ChatMessage, &hello_msg);

    var ping_msg = ChatMessage{ .Ping = 42 };
    try engine.send(ChatMessage, &ping_msg);

    var stop_msg = ChatMessage{ .Stop = {} };
    try engine.send(ChatMessage, &stop_msg);

    // Start the engine (this will block and process messages)
    engine.start();
}
```

### Step 3: Run Your Program

Save this as `src/main.zig` and run it:

```bash
zig build run
```

You should see output like:
```
Actor Engine Started
👋 Hello, World!
🏓 Ping: 42
🛑 Stopping actor
```

## Adding State

Real actors often need to maintain state. Let's extend our example to track message counts:

```zig
const ChatMessage = union(enum) {
    Hello: []const u8,
    Ping: u32,
    GetStats: void,
    Reset: void,
    
    const Self = @This();
    
    // Define actor state
    const State = struct {
        hello_count: u32 = 0,
        ping_count: u32 = 0,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .hello_count = 0,
                .ping_count = 0,
                .allocator = allocator,
            };
            return state;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        // Get or create state
        var state = actor.getState(State) orelse blk: {
            const new_state = State.init(actor.getAllocator()) catch |err| {
                std.debug.print("Failed to initialize state: {}\n", .{err});
                return null;
            };
            actor.setState(new_state);
            break :blk actor.getState(State).?;
        };
        
        switch (msg) {
            .Hello => |name| {
                state.hello_count += 1;
                std.debug.print("👋 Hello, {s}! (hello count: {})\n", .{ name, state.hello_count });
            },
            .Ping => |value| {
                state.ping_count += 1;
                std.debug.print("🏓 Ping: {} (ping count: {})\n", .{ value, state.ping_count });
            },
            .GetStats => {
                std.debug.print("📊 Stats - Hellos: {}, Pings: {}\n", .{ state.hello_count, state.ping_count });
            },
            .Reset => {
                state.hello_count = 0;
                state.ping_count = 0;
                std.debug.print("🔄 Stats reset!\n");
            },
        }
    }
};
```

## Multiple Actors

You can create multiple actor types in the same system:

```zig
// Logger actor
const LogMessage = union(enum) {
    Info: []const u8,
    Error: []const u8,
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        _ = actor;
        switch (msg) {
            .Info => |text| std.debug.print("ℹ️  INFO: {s}\n", .{text}),
            .Error => |text| std.debug.print("❌ ERROR: {s}\n", .{text}),
        }
    }
};

// Counter actor
const CounterMessage = union(enum) {
    Increment: void,
    Decrement: void,
    Get: void,
    
    // ... state and handler implementation
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    // Spawn multiple actor types
    try engine.spawn(ChatMessage, ChatMessage.handle);
    try engine.spawn(LogMessage, LogMessage.handle);
    try engine.spawn(CounterMessage, CounterMessage.handle);

    // Send messages to different actors
    var hello = ChatMessage{ .Hello = "Multi-Actor System" };
    try engine.send(ChatMessage, &hello);

    var log = LogMessage{ .Info = "System started successfully" };
    try engine.send(LogMessage, &log);

    engine.start();
}
```

## Key Concepts Learned

Through this quick start, you've learned:

1. **Message Definition**: How to define typed messages using unions
2. **Handler Functions**: How to process messages in actor handlers  
3. **State Management**: How actors can maintain internal state
4. **Actor Lifecycle**: How to create, spawn, and communicate with actors
5. **Multi-Actor Systems**: How to run multiple actor types together

## Common Patterns

### Request-Response

```zig
// Send a message and handle the response
const RequestMessage = union(enum) {
    GetUserById: struct { id: u32, reply_to: *Actor(ResponseMessage) },
    // ... other requests
};

const ResponseMessage = union(enum) {
    UserFound: User,
    UserNotFound: void,
    // ... other responses
};
```

### Supervisor Pattern

```zig
// Supervisor that manages child actors
const SupervisorMessage = union(enum) {
    SpawnChild: []const u8,
    ChildFailed: u32,
    RestartChild: u32,
    // ... supervisor operations
};
```

### Publisher-Subscriber

```zig
// Event-driven communication
const EventMessage = union(enum) {
    Subscribe: []const u8,
    Unsubscribe: []const u8,
    Publish: struct { topic: []const u8, data: []const u8 },
    // ... event operations
};
```

## What's Next?

Now that you understand the basics, explore these topics:

- [Architecture](./04-architecture.md) - Deep dive into zctor's design
- [API Reference](./05-api-reference.md) - Complete API documentation  
- [Examples](./06-examples.md) - Real-world usage patterns
- [Best Practices](./07-best-practices.md) - Tips for production use