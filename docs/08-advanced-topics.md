# Advanced Topics

This chapter covers advanced patterns, performance optimization, and complex use cases for experienced zctor developers.

## Custom Allocators

### Arena Allocators for Request Processing

Use arena allocators for request-scoped memory management:

```zig
const RequestProcessor = union(enum) {
    ProcessRequest: struct { 
        id: u32, 
        data: []const u8,
        arena: *std.heap.ArenaAllocator,
    },
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        switch (msg) {
            .ProcessRequest => |req| {
                // All allocations during this request use the arena
                const allocator = req.arena.allocator();
                
                // Process data with temporary allocations
                const processed = processComplexData(allocator, req.data) catch return null;
                const transformed = transformData(allocator, processed) catch return null;
                const result = finalizeData(allocator, transformed) catch return null;
                
                // Send result somewhere
                sendResult(req.id, result);
                
                // Arena will be freed by the caller
            },
        }
    }
};

// Usage with arena management
pub fn handleHttpRequest(request: HttpRequest) !void {
    var arena = std.heap.ArenaAllocator.init(global_allocator);
    defer arena.deinit(); // Automatic cleanup
    
    const msg = RequestProcessor.ProcessRequest{
        .id = request.id,
        .data = request.body,
        .arena = &arena,
    };
    
    try engine.send(RequestProcessor, &msg);
}
```

### Memory Pool Allocators

Implement custom memory pools for high-performance scenarios:

```zig
const PoolAllocator = struct {
    pool: std.ArrayList([]u8),
    chunk_size: usize,
    backing_allocator: std.mem.Allocator,
    
    pub fn init(backing_allocator: std.mem.Allocator, chunk_size: usize) PoolAllocator {
        return PoolAllocator{
            .pool = std.ArrayList([]u8).init(backing_allocator),
            .chunk_size = chunk_size,
            .backing_allocator = backing_allocator,
        };
    }
    
    pub fn allocator(self: *PoolAllocator) std.mem.Allocator {
        return std.mem.Allocator{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }
    
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ptr_align;
        _ = ret_addr;
        const self: *PoolAllocator = @ptrCast(@alignCast(ctx));
        
        if (len <= self.chunk_size and self.pool.items.len > 0) {
            return self.pool.pop().ptr;
        }
        
        return self.backing_allocator.rawAlloc(len, ptr_align, ret_addr);
    }
    
    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = buf_align;
        _ = ret_addr;
        const self: *PoolAllocator = @ptrCast(@alignCast(ctx));
        
        if (buf.len == self.chunk_size) {
            self.pool.append(buf) catch {
                // If pool is full, fall back to backing allocator
                self.backing_allocator.rawFree(buf, buf_align, ret_addr);
            };
        } else {
            self.backing_allocator.rawFree(buf, buf_align, ret_addr);
        }
    }
    
    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *PoolAllocator = @ptrCast(@alignCast(ctx));
        return self.backing_allocator.rawResize(buf, buf_align, new_len, ret_addr);
    }
};
```

## Supervision Patterns

### Hierarchical Supervision

Implement supervision trees for fault tolerance:

```zig
const SupervisorStrategy = enum {
    one_for_one,    // Restart only the failed child
    one_for_all,    // Restart all children when one fails
    rest_for_one,   // Restart the failed child and all children started after it
};

const SupervisorSpec = struct {
    max_restarts: u32 = 3,
    max_time_window: u32 = 60, // seconds
    strategy: SupervisorStrategy = .one_for_one,
};

const Supervisor = union(enum) {
    StartChild: struct { 
        name: []const u8, 
        actor_type: type,
        handler: anytype,
    },
    ChildTerminated: struct { 
        name: []const u8, 
        reason: TerminationReason,
    },
    GetChildren: void,
    
    const Self = @This();
    
    const TerminationReason = enum {
        normal,
        error,
        killed,
    };
    
    const ChildSpec = struct {
        name: []const u8,
        restart_count: u32,
        last_restart: i64,
        status: enum { running, terminated, restarting },
    };
    
    const State = struct {
        children: std.HashMap([]const u8, ChildSpec, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        spec: SupervisorSpec,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, spec: SupervisorSpec) !*State {
            const state = try allocator.create(State);
            state.* = State{
                .children = std.HashMap([]const u8, ChildSpec, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
                .spec = spec,
                .allocator = allocator,
            };
            return state;
        }
        
        pub fn shouldRestart(self: *State, child_name: []const u8) bool {
            const child = self.children.get(child_name) orelse return false;
            const now = std.time.timestamp();
            
            // Check if within time window
            if (now - child.last_restart > self.spec.max_time_window) {
                // Reset restart count if outside time window
                if (self.children.getPtr(child_name)) |c| {
                    c.restart_count = 0;
                }
            }
            
            return child.restart_count < self.spec.max_restarts;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor, SupervisorSpec{});
        
        switch (msg) {
            .StartChild => |spec| {
                // Spawn child actor
                actor.getContext().spawn(spec.actor_type, spec.handler) catch {
                    std.log.err("Failed to start child: {s}", .{spec.name});
                    return;
                };
                
                const child = ChildSpec{
                    .name = spec.name,
                    .restart_count = 0,
                    .last_restart = std.time.timestamp(),
                    .status = .running,
                };
                
                state.children.put(spec.name, child) catch return null;
                std.log.info("Started child: {s}", .{spec.name});
            },
            
            .ChildTerminated => |term| {
                if (state.children.getPtr(term.name)) |child| {
                    child.status = .terminated;
                    
                    if (term.reason == .error and state.shouldRestart(term.name)) {
                        // Implement restart strategy
                        switch (state.spec.strategy) {
                            .one_for_one => restartChild(state, term.name),
                            .one_for_all => restartAllChildren(state),
                            .rest_for_one => restartChildrenAfter(state, term.name),
                        }
                    }
                }
            },
            
            .GetChildren => {
                std.log.info("Supervisor children:");
                var iterator = state.children.iterator();
                while (iterator.next()) |entry| {
                    const child = entry.value_ptr.*;
                    std.log.info("  {s}: {} (restarts: {})", .{ child.name, child.status, child.restart_count });
                }
            },
        }
    }
};
```

### Circuit Breaker Pattern

Implement circuit breakers for external service resilience:

```zig
const CircuitState = enum { closed, open, half_open };

const CircuitBreaker = struct {
    state: CircuitState = .closed,
    failure_count: u32 = 0,
    success_count: u32 = 0,
    last_failure_time: i64 = 0,
    
    // Configuration
    failure_threshold: u32 = 5,
    recovery_timeout: i64 = 30, // seconds
    success_threshold: u32 = 3, // for half-open state
    
    pub fn canExecute(self: *CircuitBreaker) bool {
        const now = std.time.timestamp();
        
        switch (self.state) {
            .closed => return true,
            .open => {
                if (now - self.last_failure_time >= self.recovery_timeout) {
                    self.state = .half_open;
                    self.success_count = 0;
                    return true;
                }
                return false;
            },
            .half_open => return true,
        }
    }
    
    pub fn recordSuccess(self: *CircuitBreaker) void {
        switch (self.state) {
            .closed => {
                self.failure_count = 0;
            },
            .half_open => {
                self.success_count += 1;
                if (self.success_count >= self.success_threshold) {
                    self.state = .closed;
                    self.failure_count = 0;
                }
            },
            .open => {},
        }
    }
    
    pub fn recordFailure(self: *CircuitBreaker) void {
        self.failure_count += 1;
        self.last_failure_time = std.time.timestamp();
        
        if (self.failure_count >= self.failure_threshold) {
            self.state = .open;
        }
    }
};

const ExternalServiceActor = union(enum) {
    CallService: struct { request: []const u8, callback: fn ([]const u8) void },
    
    const Self = @This();
    
    const State = struct {
        circuit_breaker: CircuitBreaker,
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor);
        
        switch (msg) {
            .CallService => |call| {
                if (!state.circuit_breaker.canExecute()) {
                    std.log.warn("Circuit breaker is open, rejecting request");
                    call.callback("Circuit breaker open");
                    return;
                }
                
                callExternalService(call.request) catch |err| {
                    state.circuit_breaker.recordFailure();
                    std.log.err("External service call failed: {}", .{err});
                    call.callback("Service unavailable");
                    return;
                };
                
                state.circuit_breaker.recordSuccess();
                call.callback("Success");
            },
        }
    }
};
```

## Distributed Actor Systems

### Remote Actor Communication

Implement distributed actors across network boundaries:

```zig
const RemoteActorRef = struct {
    node_id: []const u8,
    actor_id: []const u8,
    address: std.net.Address,
};

const ClusterMessage = union(enum) {
    SendRemote: struct { 
        target: RemoteActorRef, 
        message: []const u8,
    },
    ReceiveRemote: struct { 
        from: RemoteActorRef, 
        message: []const u8,
    },
    NodeJoined: struct { node_id: []const u8, address: std.net.Address },
    NodeLeft: struct { node_id: []const u8 },
    
    const Self = @This();
    
    const State = struct {
        node_id: []const u8,
        nodes: std.HashMap([]const u8, std.net.Address, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        connections: std.HashMap([]const u8, std.net.Stream, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        allocator: std.mem.Allocator,
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor);
        
        switch (msg) {
            .SendRemote => |send| {
                const connection = state.connections.get(send.target.node_id);
                if (connection == null) {
                    // Establish connection
                    establishConnection(state, send.target.node_id) catch {
                        std.log.err("Failed to connect to node: {s}", .{send.target.node_id});
                        return;
                    };
                }
                
                // Serialize and send message
                const serialized = serializeMessage(send.target.actor_id, send.message) catch return null;
                sendToNode(state, send.target.node_id, serialized) catch {
                    std.log.err("Failed to send message to remote node");
                };
            },
            
            .ReceiveRemote => |recv| {
                // Deserialize and route to local actor
                const local_actor_id = recv.message; // Simplified
                routeToLocalActor(local_actor_id, recv.message) catch {
                    std.log.err("Failed to route message to local actor");
                };
            },
            
            .NodeJoined => |join| {
                state.nodes.put(join.node_id, join.address) catch return null;
                std.log.info("Node joined cluster: {s}", .{join.node_id});
            },
            
            .NodeLeft => |leave| {
                _ = state.nodes.remove(leave.node_id);
                if (state.connections.get(leave.node_id)) |conn| {
                    conn.close();
                    _ = state.connections.remove(leave.node_id);
                }
                std.log.info("Node left cluster: {s}", .{leave.node_id});
            },
        }
    }
};
```

### Consensus Algorithms

Implement Raft consensus for distributed coordination:

```zig
const RaftRole = enum { follower, candidate, leader };

const RaftMessage = union(enum) {
    RequestVote: struct {
        term: u64,
        candidate_id: []const u8,
        last_log_index: u64,
        last_log_term: u64,
    },
    RequestVoteResponse: struct {
        term: u64,
        vote_granted: bool,
    },
    AppendEntries: struct {
        term: u64,
        leader_id: []const u8,
        prev_log_index: u64,
        prev_log_term: u64,
        entries: []LogEntry,
        leader_commit: u64,
    },
    AppendEntriesResponse: struct {
        term: u64,
        success: bool,
    },
    ClientRequest: struct {
        command: []const u8,
    },
    
    const Self = @This();
    
    const LogEntry = struct {
        term: u64,
        index: u64,
        command: []const u8,
    };
    
    const State = struct {
        // Persistent state
        current_term: u64 = 0,
        voted_for: ?[]const u8 = null,
        log: std.ArrayList(LogEntry),
        
        // Volatile state
        commit_index: u64 = 0,
        last_applied: u64 = 0,
        
        // Leader state
        next_index: std.HashMap([]const u8, u64, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        match_index: std.HashMap([]const u8, u64, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
        
        // Node state
        role: RaftRole = .follower,
        leader_id: ?[]const u8 = null,
        election_timeout: i64 = 0,
        heartbeat_timeout: i64 = 0,
        
        allocator: std.mem.Allocator,
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor);
        
        switch (msg) {
            .RequestVote => |vote| {
                handleRequestVote(state, vote, actor);
            },
            .RequestVoteResponse => |response| {
                handleVoteResponse(state, response, actor);
            },
            .AppendEntries => |entries| {
                handleAppendEntries(state, entries, actor);
            },
            .AppendEntriesResponse => |response| {
                handleAppendEntriesResponse(state, response, actor);
            },
            .ClientRequest => |request| {
                handleClientRequest(state, request, actor);
            },
        }
    }
};
```

## Performance Tuning

### Message Batching

Implement smart message batching for high-throughput scenarios:

```zig
const BatchingActor = union(enum) {
    ProcessItem: []const u8,
    Flush: void,
    Configure: struct { max_batch_size: usize, max_delay_ms: u64 },
    
    const Self = @This();
    
    const State = struct {
        batch: std.ArrayList([]const u8),
        max_batch_size: usize = 100,
        max_delay_ms: u64 = 10,
        last_batch_time: i64 = 0,
        timer_active: bool = false,
        allocator: std.mem.Allocator,
        
        pub fn shouldFlush(self: *State) bool {
            const now = std.time.milliTimestamp();
            return self.batch.items.len >= self.max_batch_size or
                   (self.batch.items.len > 0 and (now - self.last_batch_time) >= self.max_delay_ms);
        }
        
        pub fn processBatch(self: *State) void {
            if (self.batch.items.len == 0) return;
            
            // Process all items in batch
            processBatchItems(self.batch.items);
            
            // Clear batch
            self.batch.clearRetainingCapacity();
            self.last_batch_time = std.time.milliTimestamp();
            self.timer_active = false;
        }
    };
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        var state = getOrCreateState(actor);
        
        switch (msg) {
            .ProcessItem => |item| {
                state.batch.append(item) catch return null;
                
                if (state.shouldFlush()) {
                    state.processBatch();
                } else if (!state.timer_active) {
                    // Schedule flush timer
                    scheduleFlush(actor, state.max_delay_ms);
                    state.timer_active = true;
                }
            },
            
            .Flush => {
                state.processBatch();
            },
            
            .Configure => |config| {
                state.max_batch_size = config.max_batch_size;
                state.max_delay_ms = config.max_delay_ms;
            },
        }
    }
};
```

### Lock-Free Data Structures

Implement lock-free data structures for high-performance scenarios:

```zig
const AtomicQueue = struct {
    const Node = struct {
        data: ?*anyopaque,
        next: ?*Node,
    };
    
    head: ?*Node,
    tail: ?*Node,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AtomicQueue {
        const dummy = allocator.create(Node) catch unreachable;
        dummy.* = Node{ .data = null, .next = null };
        
        return AtomicQueue{
            .head = dummy,
            .tail = dummy,
            .allocator = allocator,
        };
    }
    
    pub fn enqueue(self: *AtomicQueue, data: *anyopaque) !void {
        const new_node = try self.allocator.create(Node);
        new_node.* = Node{ .data = data, .next = null };
        
        while (true) {
            const tail = @atomicLoad(?*Node, &self.tail, .acquire);
            const next = @atomicLoad(?*Node, &tail.?.next, .acquire);
            
            if (tail == @atomicLoad(?*Node, &self.tail, .acquire)) {
                if (next == null) {
                    if (@cmpxchgWeak(?*Node, &tail.?.next, next, new_node, .release, .relaxed) == null) {
                        _ = @cmpxchgWeak(?*Node, &self.tail, tail, new_node, .release, .relaxed);
                        break;
                    }
                } else {
                    _ = @cmpxchgWeak(?*Node, &self.tail, tail, next, .release, .relaxed);
                }
            }
        }
    }
    
    pub fn dequeue(self: *AtomicQueue) ?*anyopaque {
        while (true) {
            const head = @atomicLoad(?*Node, &self.head, .acquire);
            const tail = @atomicLoad(?*Node, &self.tail, .acquire);
            const next = @atomicLoad(?*Node, &head.?.next, .acquire);
            
            if (head == @atomicLoad(?*Node, &self.head, .acquire)) {
                if (head == tail) {
                    if (next == null) {
                        return null; // Queue is empty
                    }
                    _ = @cmpxchgWeak(?*Node, &self.tail, tail, next, .release, .relaxed);
                } else {
                    if (next) |next_node| {
                        const data = @atomicLoad(?*anyopaque, &next_node.data, .acquire);
                        if (@cmpxchgWeak(?*Node, &self.head, head, next_node, .release, .relaxed) == null) {
                            self.allocator.destroy(head.?);
                            return data;
                        }
                    }
                }
            }
        }
    }
};
```

## Monitoring and Debugging

### Built-in Metrics Collection

Add comprehensive metrics to your actors:

```zig
const ActorMetrics = struct {
    messages_processed: u64 = 0,
    messages_failed: u64 = 0,
    total_processing_time_ns: u64 = 0,
    max_processing_time_ns: u64 = 0,
    queue_size_samples: std.ArrayList(u32),
    
    pub fn recordMessage(self: *ActorMetrics, processing_time_ns: u64, queue_size: u32) void {
        self.messages_processed += 1;
        self.total_processing_time_ns += processing_time_ns;
        if (processing_time_ns > self.max_processing_time_ns) {
            self.max_processing_time_ns = processing_time_ns;
        }
        
        self.queue_size_samples.append(queue_size) catch {};
        
        // Keep only recent samples
        if (self.queue_size_samples.items.len > 1000) {
            _ = self.queue_size_samples.orderedRemove(0);
        }
    }
    
    pub fn getAverageProcessingTime(self: *const ActorMetrics) f64 {
        if (self.messages_processed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_processing_time_ns)) / @as(f64, @floatFromInt(self.messages_processed));
    }
    
    pub fn getAverageQueueSize(self: *const ActorMetrics) f64 {
        if (self.queue_size_samples.items.len == 0) return 0.0;
        var sum: u64 = 0;
        for (self.queue_size_samples.items) |size| {
            sum += size;
        }
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(self.queue_size_samples.items.len));
    }
};
```

### Debug Actor Inspector

Create debugging tools for actor inspection:

```zig
const ActorInspector = union(enum) {
    InspectActor: struct { actor_type: []const u8 },
    GetSystemStats: void,
    DumpActorState: struct { actor_type: []const u8 },
    
    const Self = @This();
    
    pub fn handle(actor: *Actor(Self), msg: Self) ?void {
        switch (msg) {
            .InspectActor => |inspect| {
                std.log.info("Inspecting actor type: {s}", .{inspect.actor_type});
                // Implementation would inspect actor state
            },
            
            .GetSystemStats => {
                // Collect system-wide statistics
                const stats = collectSystemStats();
                std.log.info("System Stats:");
                std.log.info("  Total Actors: {}", .{stats.total_actors});
                std.log.info("  Total Messages: {}", .{stats.total_messages});
                std.log.info("  Average Latency: {d:.2}ms", .{stats.avg_latency_ms});
            },
            
            .DumpActorState => |dump| {
                // Implementation would serialize and dump actor state
                std.log.info("Dumping state for actor type: {s}", .{dump.actor_type});
            },
        }
    }
};
```

## Next Steps

These advanced topics provide the foundation for building sophisticated, production-ready systems with zctor. Continue your journey with:

- [Contributing](./09-contributing.md) - How to contribute to the zctor project
- [Best Practices](./07-best-practices.md) - Review core best practices
- [Examples](./06-examples.md) - See these patterns in action