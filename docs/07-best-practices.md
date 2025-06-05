# Best Practices

This chapter covers best practices, design patterns, and optimization techniques for building production-ready applications with zctor.

## Design Principles

### Single Responsibility

Each actor should have a single, well-defined responsibility:

```zig
// Good: Focused responsibility
const UserAuthenticator = union(enum) {
    Login: struct { username: []const u8, password: []const u8 },
    Logout: struct { session_id: []const u8 },
    ValidateSession: struct { session_id: []const u8 },
};

// Avoid: Mixed responsibilities
const UserManager = union(enum) {
    Login: struct { username: []const u8, password: []const u8 },
    SaveFile: struct { filename: []const u8, data: []const u8 },
    SendEmail: struct { to: []const u8, subject: []const u8 },
    CalculateTax: struct { amount: f64 },
};
```

### Immutable Messages

Design messages to be immutable and contain all necessary data:

```zig
// Good: Self-contained message
const ProcessOrder = struct {
    order_id: u32,
    customer_id: u32,
    items: []OrderItem,
    total_amount: f64,
    currency: Currency,
    timestamp: i64,
};

// Avoid: Mutable or incomplete messages
const ProcessOrder = struct {
    order_id: u32,
    // Missing essential data - actor would need to fetch it
};
```

### Type-Safe Message Design

Leverage Zig's type system for safe message handling:

```zig
// Use enums for discrete states
const UserStatus = enum { active, inactive, suspended, deleted };

// Use tagged unions for different message types
const DatabaseMessage = union(enum) {
    Read: struct { table: []const u8, id: u32 },
    Write: struct { table: []const u8, data: []const u8 },
    Delete: struct { table: []const u8, id: u32 },
    
    // Compile-time validation of message types
    pub fn validate(self: @This()) bool {
        return switch (self) {
            .Read => |r| r.table.len > 0 and r.id > 0,
            .Write => |w| w.table.len > 0 and w.data.len > 0,
            .Delete => |d| d.table.len > 0 and d.id > 0,
        };
    }
};
```

## State Management

### Lazy State Initialization

Initialize state only when needed to optimize memory usage:

```zig
const State = struct {
    cache: ?std.HashMap(u32, []const u8, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) !*State {
        const state = try allocator.create(State);
        state.* = State{
            .cache = null, // Lazy initialization
            .allocator = allocator,
        };
        return state;
    }
    
    pub fn getCache(self: *State) !*std.HashMap(u32, []const u8, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage) {
        if (self.cache == null) {
            self.cache = std.HashMap(u32, []const u8, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage).init(self.allocator);
        }
        return &self.cache.?;
    }
};
```

### State Validation

Validate state consistency in debug builds:

```zig
const State = struct {
    counter: u32,
    max_value: u32,
    
    pub fn validate(self: *const State) bool {
        return self.counter <= self.max_value;
    }
    
    pub fn increment(self: *State) !void {
        if (self.counter >= self.max_value) {
            return error.CounterOverflow;
        }
        self.counter += 1;
        
        // Assert invariants in debug builds
        if (builtin.mode == .Debug) {
            std.debug.assert(self.validate());
        }
    }
};
```

### Memory-Efficient State

Use memory pools and compact data structures:

```zig
const State = struct {
    // Use ArrayList instead of HashMap when appropriate
    recent_messages: std.ArrayList(Message),
    
    // Use fixed-size arrays for bounded data
    connection_pool: [16]?Connection,
    
    // Use bit fields for flags
    flags: packed struct {
        is_authenticated: bool,
        is_admin: bool,
        notifications_enabled: bool,
        _padding: u5 = 0,
    },
    
    allocator: std.mem.Allocator,
};
```

## Error Handling

### Graceful Error Recovery

Design actors to handle errors gracefully:

```zig
pub fn handle(actor: *Actor(DatabaseMessage), msg: DatabaseMessage) ?void {
    switch (msg) {
        .Query => |query| {
            // Try primary database
            executeQuery(query.sql) catch |err| switch (err) {
                error.ConnectionTimeout => {
                    // Retry with backup database
                    executeQueryOnBackup(query.sql) catch |backup_err| {
                        std.log.err("Both primary and backup databases failed: {} / {}", .{ err, backup_err });
                        // Send failure notification
                        notifyQueryFailure(query.request_id);
                        return;
                    };
                },
                error.InvalidQuery => {
                    std.log.err("Invalid query: {s}", .{query.sql});
                    // Don't retry, just log and continue
                    return;
                },
                else => {
                    std.log.err("Database error: {}", .{err});
                    return null; // Signal actor error
                },
            };
        },
    }
}
```

### Error Propagation

Use explicit error types for clear error handling:

```zig
const ProcessingError = error{
    InvalidInput,
    NetworkTimeout,
    DatabaseError,
    InsufficientMemory,
};

const ProcessMessage = struct {
    data: []const u8,
    callback: ?fn (result: ProcessingError![]const u8) void,
};

pub fn handle(actor: *Actor(ProcessMessage), msg: ProcessMessage) ?void {
    const result = processData(msg.data) catch |err| {
        if (msg.callback) |cb| {
            cb(err);
        }
        return; // Continue processing other messages
    };
    
    if (msg.callback) |cb| {
        cb(result);
    }
}
```

## Performance Optimization

### Message Pooling

Reuse message objects to reduce allocations:

```zig
const MessagePool = struct {
    pool: std.ArrayList(*Message),
    allocator: std.mem.Allocator,
    
    pub fn get(self: *MessagePool) !*Message {
        if (self.pool.items.len > 0) {
            return self.pool.pop();
        }
        return try self.allocator.create(Message);
    }
    
    pub fn put(self: *MessagePool, msg: *Message) !void {
        // Reset message state
        msg.* = std.mem.zeroes(Message);
        try self.pool.append(msg);
    }
};
```

### Batch Processing

Process multiple messages in batches for better throughput:

```zig
const BatchProcessor = union(enum) {
    AddItem: []const u8,
    ProcessBatch: void,
    
    const Self = @This();
    
    const State = struct {
        batch: std.ArrayList([]const u8),
        batch_size: usize,
        last_process: i64,
        
        pub fn shouldProcess(self: *State) bool {
            const now = std.time.timestamp();
            return self.batch.items.len >= self.batch_size or 
                   (now - self.last_process) > 1000; // 1 second timeout
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor);
        
        switch (msg) {
            .AddItem => |item| {
                state.batch.append(item) catch return null;
                
                if (state.shouldProcess()) {
                    var process_msg = Self.ProcessBatch;
                    actor.sender(process_msg) catch {};
                }
            },
            .ProcessBatch => {
                if (state.batch.items.len > 0) {
                    processBatch(state.batch.items);
                    state.batch.clearRetainingCapacity();
                    state.last_process = std.time.timestamp();
                }
            },
        }
    }
};
```

### Memory Management

Use appropriate allocators for different use cases:

```zig
const State = struct {
    // Use arena allocator for temporary data
    arena: std.heap.ArenaAllocator,
    
    // Use general purpose allocator for long-lived data
    persistent_data: std.HashMap(u32, []const u8, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage),
    
    pub fn init(allocator: std.mem.Allocator) !*State {
        const state = try allocator.create(State);
        state.* = State{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .persistent_data = std.HashMap(u32, []const u8, std.hash_map.DefaultContext(u32), std.hash_map.default_max_load_percentage).init(allocator),
        };
        return state;
    }
    
    pub fn processTemporaryData(self: *State, data: []const u8) !void {
        // Use arena for temporary allocations
        const temp_allocator = self.arena.allocator();
        const processed = try processData(temp_allocator, data);
        
        // Store result in persistent storage
        try self.persistent_data.put(calculateHash(data), processed);
        
        // Clear arena for next use
        _ = self.arena.reset(.retain_capacity);
    }
};
```

## Testing Strategies

### Unit Testing Actors

Create testable actor handlers:

```zig
// Separate business logic from actor infrastructure
const Calculator = struct {
    pub fn add(a: i32, b: i32) i32 {
        return a + b;
    }
    
    pub fn multiply(a: i32, b: i32) i32 {
        return a * b;
    }
};

const CalculatorMessage = union(enum) {
    Add: struct { a: i32, b: i32 },
    Multiply: struct { a: i32, b: i32 },
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        _ = actor;
        switch (msg) {
            .Add => |op| {
                const result = Calculator.add(op.a, op.b);
                std.debug.print("Result: {}\n", .{result});
            },
            .Multiply => |op| {
                const result = Calculator.multiply(op.a, op.b);
                std.debug.print("Result: {}\n", .{result});
            },
        }
    }
};

// Test business logic separately
test "Calculator add function" {
    try testing.expectEqual(@as(i32, 5), Calculator.add(2, 3));
}

test "Calculator multiply function" {
    try testing.expectEqual(@as(i32, 6), Calculator.multiply(2, 3));
}
```

### Integration Testing

Test actor interactions:

```zig
const TestHarness = struct {
    engine: *ActorEngine,
    responses: std.ArrayList([]const u8),
    
    pub fn init(allocator: std.mem.Allocator) !TestHarness {
        return TestHarness{
            .engine = try ActorEngine.init(allocator),
            .responses = std.ArrayList([]const u8).init(allocator),
        };
    }
    
    pub fn expectResponse(self: *TestHarness, expected: []const u8) !void {
        // Wait for response or timeout
        const timeout = std.time.timestamp() + 5; // 5 second timeout
        
        while (std.time.timestamp() < timeout) {
            if (self.responses.items.len > 0) {
                const actual = self.responses.orderedRemove(0);
                try testing.expectEqualStrings(expected, actual);
                return;
            }
            std.time.sleep(1000000); // 1ms
        }
        
        return error.TimeoutWaitingForResponse;
    }
};
```

### Mock Actors

Create mock actors for testing:

```zig
const MockDatabaseMessage = union(enum) {
    Query: struct { sql: []const u8, callback: fn ([]const u8) void },
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        _ = actor;
        switch (msg) {
            .Query => |query| {
                // Return predictable test data
                if (std.mem.eql(u8, query.sql, "SELECT * FROM users")) {
                    query.callback("user1,user2,user3");
                } else {
                    query.callback("error: unknown query");
                }
            },
        }
    }
};
```

## Production Considerations

### Monitoring and Observability

Add metrics and logging to your actors:

```zig
const MetricsCollector = struct {
    message_count: u64 = 0,
    error_count: u64 = 0,
    processing_time_total: u64 = 0,
    
    pub fn recordMessage(self: *MetricsCollector) void {
        self.message_count += 1;
    }
    
    pub fn recordError(self: *MetricsCollector) void {
        self.error_count += 1;
    }
    
    pub fn recordProcessingTime(self: *MetricsCollector, duration: u64) void {
        self.processing_time_total += duration;
    }
};

pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    const start_time = std.time.nanoTimestamp();
    defer {
        const end_time = std.time.nanoTimestamp();
        const duration = @intCast(u64, end_time - start_time);
        getMetrics().recordProcessingTime(duration);
    }
    
    getMetrics().recordMessage();
    
    // Process message
    processMessage(msg) catch |err| {
        getMetrics().recordError();
        std.log.err("Error processing message: {}", .{err});
        return null;
    };
}
```

### Resource Management

Implement proper resource cleanup:

```zig
const ResourceManager = struct {
    connections: std.ArrayList(*Connection),
    files: std.ArrayList(std.fs.File),
    
    pub fn cleanup(self: *ResourceManager) void {
        // Close all connections
        for (self.connections.items) |conn| {
            conn.close();
        }
        self.connections.clearAndFree();
        
        // Close all files
        for (self.files.items) |file| {
            file.close();
        }
        self.files.clearAndFree();
    }
};

const State = struct {
    resources: ResourceManager,
    
    pub fn deinit(self: *State) void {
        self.resources.cleanup();
    }
};
```

### Configuration Management

Use compile-time configuration for performance:

```zig
const Config = struct {
    const max_message_queue_size = if (builtin.mode == .Debug) 100 else 10000;
    const enable_detailed_logging = builtin.mode == .Debug;
    const batch_size = if (builtin.cpu.arch == .x86_64) 1000 else 100;
};

pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    if (Config.enable_detailed_logging) {
        std.log.debug("Processing message: {}", .{msg});
    }
    
    // Use configuration values
    if (getQueueSize() > Config.max_message_queue_size) {
        std.log.warn("Message queue size exceeded: {}", .{getQueueSize()});
    }
}
```

## Common Pitfalls

### Avoid Blocking Operations

Never perform blocking operations in actor handlers:

```zig
// Bad: Blocking I/O
pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    const file = std.fs.cwd().openFile("data.txt", .{}) catch return null;
    const data = file.readToEndAlloc(actor.getAllocator(), 1024) catch return null;
    // This blocks the entire thread!
}

// Good: Use async I/O or delegate to specialized actors
pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    switch (msg) {
        .ReadFile => |filename| {
            // Send request to I/O actor
            var io_msg = IOMessage{ .ReadFile = .{ .filename = filename, .callback = handleFileData } };
            actor.getContext().send(IOMessage, &io_msg) catch {};
        },
    }
}
```

### Avoid Shared Mutable State

Don't share mutable state between actors:

```zig
// Bad: Shared mutable state
var global_counter: u32 = 0;

pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    global_counter += 1; // Race condition!
}

// Good: Actor-local state
const State = struct {
    local_counter: u32 = 0,
};

pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    var state = getState(actor);
    state.local_counter += 1; // Safe!
}
```

### Avoid Large Messages

Keep messages small and focused:

```zig
// Bad: Large message with embedded data
const ProcessImage = struct {
    image_data: [1024 * 1024]u8, // 1MB embedded in message
    filter: ImageFilter,
};

// Good: Reference to data
const ProcessImage = struct {
    image_path: []const u8,
    filter: ImageFilter,
};
```

## Next Steps

With these best practices in mind, you're ready to explore:

- [Advanced Topics](./08-advanced-topics.md) - Complex patterns and optimizations
- [Contributing](./09-contributing.md) - How to contribute to zctor
- [Examples](./06-examples.md) - More practical implementations