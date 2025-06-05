# zctor

A lightweight, high-performance actor framework for Zig, providing concurrent message-passing with asynchronous event handling.

📖 **[View Complete Documentation](https://youneedwork.github.io/zctor/)** - Comprehensive documentation website with examples, API reference, and guides.

## Overview

zctor is a Zig implementation of the Actor Model, offering a robust foundation for building concurrent applications. The framework leverages libxev for efficient event loop management and provides a clean API for actor creation, message passing, and state management.

### Key Features

- **Actor-based Concurrency**: Implement the Actor Model with isolated actors communicating via messages
- **Multi-threaded Engine**: Distribute actors across multiple threads for optimal performance
- **Asynchronous Message Passing**: Non-blocking message delivery with efficient event handling
- **State Management**: Built-in state management within actors with type safety
- **Memory Safe**: Leverages Zig's memory safety guarantees
- **Minimal Dependencies**: Only depends on libxev for event handling

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

Here's a simple example demonstrating basic actor usage:

```zig
const std = @import("std");
const zctor = @import("zctor");
const ActorEngine = zctor.ActorEngine;
const Actor = zctor.Actor;

// Define your message types
const MyMessage = union(enum) {
    Hello: []const u8,
    Ping: u32,
    Stop: void,
    
    const Self = @This();
    
    // Message handler - matches the expected signature
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        switch (msg) {
            .Hello => |name| {
                std.debug.print("Hello, {s}!\n", .{name});
            },
            .Ping => |value| {
                std.debug.print("Ping: {}\n", .{value});
            },
            .Stop => {
                std.debug.print("Stopping actor\n");
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create the actor engine
    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    // Spawn an actor
    try engine.spawn(MyMessage, MyMessage.handle);

    // Send messages
    var hello_msg = MyMessage{ .Hello = "World" };
    try engine.send(MyMessage, &hello_msg);

    var ping_msg = MyMessage{ .Ping = 42 };
    try engine.send(MyMessage, &ping_msg);

    // Start the engine (this will block)
    engine.start();
}
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

- **ActorEngine**: Manages the overall actor system and thread pool
- **ActorThread**: Handles actors within a single thread context
- **Actor(T)**: Generic actor type that processes messages of type T
- **Context**: Provides runtime context and services to actors

### Message Flow

1. Messages are sent to actors via the `ActorEngine.send()` method
2. Messages are queued in the actor's mailbox (FIFO queue)
3. The event loop processes messages asynchronously
4. Each message is handled by the actor's message handler function

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

- `init(allocator: Allocator) !*ActorEngine` - Create a new actor engine
- `spawn(comptime T: type, handler: fn) !void` - Spawn a new actor
- `send(comptime T: type, msg: *T) !void` - Send a message to an actor
- `start() void` - Start the engine and begin processing messages
- `deinit() void` - Clean up the engine

### Actor(T)

- `getState(comptime S: type) ?*S` - Get typed state
- `setState(state: *anyopaque) void` - Set actor state  
- `resetState() void` - Clear actor state
- `getAllocator() Allocator` - Get the actor's allocator

## Examples

The `src/simple_message.zig` file contains a complete example demonstrating:

- Message type definitions
- State management
- Message handling patterns
- Actor lifecycle management

Run the example with:

```bash
zig build run
```

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