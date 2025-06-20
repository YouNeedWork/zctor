# zctor Examples

This document provides detailed explanations of all the examples included with zctor, demonstrating various multi-threading patterns and messaging capabilities.

## Overview

zctor includes 6 comprehensive examples that showcase different aspects of the actor framework:

| Example | Command | Focus | Threads | Pattern |
|---------|---------|-------|---------|---------|
| **Call Example** | `zig build run-call` | Request-Response | 2 | Synchronous calls |
| **Multi-Threading** | `zig build run-multi` | Basic Multi-Threading | 3 | Cross-thread messaging |
| **Broadcast** | `zig build run-broadcast` | One-to-Many | 6 | Broadcast messaging |
| **Thread Communication** | `zig build run-thread-comm` | Communication Patterns | 4 | Mixed patterns |
| **Publisher-Subscriber** | `zig build run-pubsub` | Pub-Sub Pattern | 7 | Event distribution |
| **Load Balancing** | `zig build run-load-balance` | Load Distribution | 5 | Round-robin balancing |

## 1. Call Example (`run-call`)

**File**: `examples/call_example.zig`

### Purpose
Demonstrates the request-response pattern where you send a message and wait for a result.

### Key Features
- Synchronous communication with `engine.call()`
- Return value handling
- Error propagation
- Memory management for responses

### Code Highlights
```zig
// Send a call and wait for response
const response = try engine.call(CalculatorMessage, &add_msg);
if (response) |ptr| {
    const result_ptr = @as(*i32, @ptrCast(@alignCast(ptr)));
    std.debug.print("Result: {}\n", .{result_ptr.*});
    allocator.destroy(result_ptr); // Clean up response
}
```

### Use Cases
- Mathematical calculations
- Database queries
- API requests
- Any operation requiring a response

## 2. Multi-Threading Example (`run-multi`)

**File**: `examples/multi_threading_example.zig`

### Purpose
Shows basic multi-threading with actors running on different threads.

### Key Features
- Multiple `ActorThread` instances
- Cross-thread message passing
- Thread ID visibility
- Concurrent processing

### Architecture
```
Thread 0: GreetingMessage actor
Thread 1: CalculatorMessage actor  
Thread 2: StatusMessage actor
```

### Code Highlights
```zig
// Create separate threads for different actor types
const greeting_thread = try ActorThread.init(allocator);
try greeting_thread.registerActor(try Actor(GreetingMessage).init(allocator, GreetingMessage.handle));
try engine.spawn(greeting_thread);

const calc_thread = try ActorThread.init(allocator);
try calc_thread.registerActor(try Actor(CalculatorMessage).init(allocator, CalculatorMessage.handle));
try engine.spawn(calc_thread);
```

### Use Cases
- Service separation
- Resource isolation
- Fault tolerance
- Performance optimization

## 3. Broadcast Example (`run-broadcast`)

**File**: `examples/broadcast_example.zig`

### Purpose
Demonstrates one-to-many communication where a single message is sent to multiple subscribers.

### Key Features
- `engine.broadcast()` method
- Multiple subscribers per message type
- Simultaneous message delivery
- Real-time event distribution

### Architecture
```
NewsMessage: 3 subscriber threads (0, 1, 2)
EventMessage: 2 subscriber threads (3, 4)
NotificationMessage: 1 subscriber thread (5)
```

### Code Highlights
```zig
// Broadcast to all NewsMessage subscribers
var breaking_news = NewsMessage{ .Breaking = "Major earthquake detected!" };
try engine.broadcast(NewsMessage, &breaking_news);
// → Delivered to threads 0, 1, and 2 simultaneously
```

### Use Cases
- News distribution
- Event notifications
- Real-time updates
- System-wide announcements

## 4. Thread Communication Example (`run-thread-comm`)

**File**: `examples/thread_communication_example.zig`

### Purpose
Comprehensive demonstration of different communication patterns between threads.

### Key Features
- Same-thread communication
- Cross-thread communication
- Load balancing
- Monitoring and metrics
- Request-response across threads

### Communication Patterns
1. **Same-Thread**: Coordinator → Worker (both on Thread 0)
2. **Cross-Thread**: Main → Workers (different threads)
3. **Load Balancing**: Tasks distributed across worker threads
4. **Monitoring**: Metrics sent to dedicated monitor thread
5. **Request-Response**: Status requests across threads

### Code Highlights
```zig
// Cross-thread request-response
var status_request = WorkerMessage{ .GetStatus = {} };
const response = try engine.call(WorkerMessage, &status_request);
if (response) |ptr| {
    const status_ptr = @as(*[]const u8, @ptrCast(@alignCast(ptr)));
    std.debug.print("Worker status: {s}\n", .{status_ptr.*});
}
```

### Use Cases
- Distributed systems
- Microservices
- Monitoring systems
- Complex workflows

## 5. Publisher-Subscriber Example (`run-pubsub`)

**File**: `examples/pubsub_example.zig`

### Purpose
Real-world publisher-subscriber pattern with multiple topic types and subscribers.

### Key Features
- Multiple topic types (Stock, News, Chat)
- Multiple subscribers per topic
- Real-time data feeds
- Event-driven architecture

### Topics and Subscribers
```
StockUpdate: 3 subscribers (market data feeds)
NewsSubscriber: 2 subscribers (news distribution)
ChatMessage: 2 subscribers (chat rooms)
```

### Code Highlights
```zig
// Stock market updates
var stock_update = StockUpdate{ .PriceUpdate = .{ .symbol = "AAPL", .price = 175.50, .change = 2.30 } };
try engine.broadcast(StockUpdate, &stock_update);
// → All stock subscribers receive the update

// News distribution
var tech_news = NewsSubscriber{ .TechNews = "New AI breakthrough announced" };
try engine.broadcast(NewsSubscriber, &tech_news);
// → All news subscribers receive the news
```

### Use Cases
- Financial data feeds
- News distribution
- Chat systems
- IoT sensor networks
- Real-time analytics

## 6. Load Balancing Example (`run-load-balance`)

**File**: `examples/load_balancing_example.zig`

### Purpose
Demonstrates intelligent load balancing across multiple worker instances.

### Key Features
- Multiple instances of the same actor type
- Round-robin distribution
- Performance statistics
- Parallel task processing
- Load distribution visualization

### Load Balancing Strategy
```
5 Worker Threads: [0, 1, 2, 3, 4]
Task Distribution:
- Task 1 → Thread 0
- Task 2 → Thread 1  
- Task 3 → Thread 2
- Task 4 → Thread 3
- Task 5 → Thread 4
- Task 6 → Thread 0 (round-robin continues)
```

### Code Highlights
```zig
// Multiple worker instances
for (0..5) |i| {
    const worker_thread = try ActorThread.init(allocator);
    try worker_thread.registerActor(try Actor(WorkerMessage).init(allocator, WorkerMessage.handle));
    try engine.spawn(worker_thread);
}

// Tasks automatically load-balanced
for (tasks) |task| {
    var task_msg = WorkerMessage{ .ProcessTask = .{ .task_id = task.id, .task_type = "compute", .complexity = task.complexity } };
    try engine.send(WorkerMessage, &task_msg); // Automatically distributed
}
```

### Performance Results
```
Worker 1: 3 tasks processed, 9 total complexity
Worker 2: 3 tasks processed, 6 total complexity  
Worker 3: 3 tasks processed, 10 total complexity
Worker 4: 4 tasks processed, 8 total complexity
Worker 5: 4 tasks processed, 8 total complexity
```

### Use Cases
- Web server request handling
- Data processing pipelines
- Batch job processing
- Computational workloads
- Distributed computing

## Running the Examples

### Prerequisites
```bash
# Clone the repository
git clone https://github.com/YouNeedWork/zctor.git
cd zctor

# Build the project
zig build
```

### Run Individual Examples
```bash
# Basic request-response
zig build run-call

# Multi-threading basics
zig build run-multi

# Broadcast messaging
zig build run-broadcast

# Thread communication patterns
zig build run-thread-comm

# Publisher-subscriber
zig build run-pubsub

# Load balancing
zig build run-load-balance
```

### Run All Examples
```bash
# Run all examples in sequence
zig build run-call && \
zig build run-multi && \
zig build run-broadcast && \
zig build run-thread-comm && \
zig build run-pubsub && \
zig build run-load-balance
```

## Understanding the Output

Each example shows thread IDs to demonstrate true multi-threading:

```
[Thread 0] Processing task...
[Thread 1] Processing task...
[Thread 2] Processing task...
```

Look for:
- **Thread IDs**: Different numbers show parallel execution
- **Load balancing messages**: "sending to thread X (option Y of Z)"
- **Registry information**: Shows which threads have which actors
- **Performance statistics**: Task counts and processing times

## Next Steps

After running these examples, you can:

1. **Modify the examples** to understand the behavior
2. **Create your own actor types** based on these patterns
3. **Combine patterns** for complex applications
4. **Measure performance** with different thread counts
5. **Build real applications** using these patterns

For more advanced usage, see the [API Reference](README.md#api-reference) and [Architecture](README.md#architecture) sections in the main README.
