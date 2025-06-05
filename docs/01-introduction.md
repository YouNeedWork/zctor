# Introduction to zctor

zctor is a lightweight, high-performance actor framework for Zig, providing concurrent message-passing with asynchronous event handling.

## What is the Actor Model?

The Actor Model is a mathematical model of concurrent computation that treats "actors" as the universal primitive of concurrent computation. In response to a message it receives, an actor can:

- Make local decisions
- Create more actors
- Send more messages
- Designate what to do with the next message it receives

## Why zctor?

zctor brings the power of the Actor Model to Zig with:

### Key Features

- **Actor-based Concurrency**: Implement the Actor Model with isolated actors communicating via messages
- **Multi-threaded Engine**: Distribute actors across multiple threads for optimal performance
- **Asynchronous Message Passing**: Non-blocking message delivery with efficient event handling
- **State Management**: Built-in state management within actors with type safety
- **Memory Safe**: Leverages Zig's memory safety guarantees
- **Minimal Dependencies**: Only depends on libxev for event handling

### Performance Benefits

- **Lock-free Design**: Actors eliminate the need for traditional locking mechanisms
- **Efficient Event Loop**: Built on libxev for high-performance I/O handling
- **Zero-cost Abstractions**: Zig's compile-time optimizations ensure minimal runtime overhead
- **Thread-per-CPU**: Optimal thread utilization based on available CPU cores

### Safety Guarantees

- **Isolation**: Actors cannot directly access each other's state
- **Type Safety**: Messages are statically typed for compile-time verification
- **Memory Safety**: Zig's allocator system prevents common memory errors
- **Error Handling**: Explicit error handling through Zig's error system

## Use Cases

zctor is ideal for:

- **Concurrent Servers**: Web servers, game servers, chat systems
- **Data Processing**: Stream processing, ETL pipelines
- **IoT Applications**: Device management, sensor data processing
- **Distributed Systems**: Microservices, cluster computing
- **Real-time Systems**: Trading systems, monitoring applications

## Comparison with Other Frameworks

| Feature | zctor | Akka (Scala) | Elixir/OTP | Go channels |
|---------|-------|--------------|------------|-------------|
| Memory Safety | ✅ | ❌ | ✅ | ✅ |
| Performance | ⚡ High | 🐌 JVM overhead | ⚡ High | ⚡ High |
| Learning Curve | 📈 Moderate | 📈 Steep | 📈 Moderate | 📉 Easy |
| Type System | ⚡ Compile-time | ⚡ Compile-time | 🔄 Runtime | ⚡ Compile-time |
| Dependencies | 📦 Minimal | 📦 Heavy | 📦 Runtime | 📦 None |

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ActorEngine   │───▶│  ActorThread    │───▶│   Actor(T)      │
│                 │    │                 │    │                 │
│ - Thread Pool   │    │ - Event Loop    │    │ - Message Queue │
│ - Load Balance  │    │ - Actor Registry│    │ - State Mgmt    │
│ - Lifecycle     │    │ - Context       │    │ - Handler       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Getting Started

Ready to start building with zctor? Check out the [Installation Guide](./02-installation.md) to get up and running quickly.

## Next Steps

- [Installation](./02-installation.md) - Set up zctor in your project
- [Quick Start](./03-quick-start.md) - Build your first actor
- [Architecture](./04-architecture.md) - Understand the core concepts