# API Reference

This is the complete API reference for zctor, automatically generated from source code.

## actor_thread_builder.zig

### Functions

#### `init`

```zig
pub fn init() Self
```

#### `build`

```zig
pub fn build(_: *Self) ActorThread
```

---

## root.zig

### Module Documentation

zctor - A lightweight actor framework for Zig

This library provides an implementation of the Actor Model with:

- Actor-based concurrency

- Multi-threaded execution

- Asynchronous message passing

- Built-in state management

---

## actor_thread.zig

### Functions

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, actor_engine: *ActorEngine, thread_id: i32) !*Self
```

#### `registerActor`

```zig
pub fn registerActor(self: *Self, actor: anytype) !void
```

#### `send`

```zig
pub fn send(self: *Self, comptime T: type, msg_ptr: *T) !void
```

#### `publish`

```zig
pub fn publish(self: *Self, comptime T: type, msg_ptr: *anyopaque) void
```

#### `deinit`

```zig
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void
```

#### `run`

```zig
pub fn run(self: *Self) !void
```

#### `start_loop`

```zig
pub fn start_loop(self: *Self) !void
```

---

## actor_engine.zig

### Functions

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) !*Self
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

#### `start`

```zig
pub fn start(self: *Self) void
```

#### `stop`

```zig
pub fn stop(self: *Self) void
```

#### `spawn`

```zig
pub fn spawn(self: *Self, comptime T: anytype, handle: fn (*Actor.Actor(T) , T) ?void) !void
```

#### `send`

```zig
pub fn send(self: *Self, comptime T: anytype, msg_ptr: *anyopaque) !void
```

---

## simple_message.zig

### Types

#### `SimpleMessage`

```zig
union(enum)
```

### Functions

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) !*State
```

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) SimpleMessage
```

#### `hello_req`

```zig
pub fn hello_req(name: []const u8) SimpleMessage
```

#### `goodbye_req`

```zig
pub fn goodbye_req() SimpleMessage
```

#### `ping_req`

```zig
pub fn ping_req(value: u32) SimpleMessage
```

#### `getCount_req`

```zig
pub fn getCount_req() SimpleMessage
```

#### `reset_req`

```zig
pub fn reset_req() SimpleMessage
```

#### `handle`

```zig
pub fn handle(self: *Actor(Self) , msg: SimpleMessage) ?void
```

---

## actor.zig

### Functions

#### `Actor`

```zig
pub fn Actor(comptime T: type) type
```

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, ctx: *context, handler: *const fn (*Self, T) ?void) !*Self
```

#### `run`

```zig
pub fn run(self: *Self) void
```

#### `handleRawMessage`

```zig
pub fn handleRawMessage(self: *Self, msg_ptr: *anyopaque) !void
```

#### `sender`

```zig
pub fn sender(self: *Self, msg: T) !void
```

#### `deinit`

```zig
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void
```

#### `getState`

```zig
pub fn getState(self: *Self, comptime S: anytype) ?*S
```

#### `setState`

```zig
pub fn setState(self: *Self, state: *anyopaque) void
```

#### `resetState`

```zig
pub fn resetState(self: *Self) void
```

#### `getContext`

```zig
pub fn getContext(self: *Self) *context
```

#### `getAllocator`

```zig
pub fn getAllocator(self: *Self) std.mem.Allocator
```

---

## actor_interface.zig

### Types

#### `VTable`

```zig
struct
```

### Functions

#### `run`

```zig
pub fn run(self: Self) void
```

#### `deinit`

```zig
pub fn deinit(self: Self, allocator: std.mem.Allocator) void
```

#### `handleRawMessage`

```zig
pub fn handleRawMessage(self: Self, msg: *anyopaque) void
```

#### `init`

```zig
pub fn init(actor: anytype) Self
```

---

## main.zig

### Functions

#### `main`

```zig
pub fn main() !void
```

---

## context.zig

### Functions

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop, actor_engine: *ActorEngine, therad_id: i32) !*Self
```

#### `deinit`

```zig
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void
```

#### `send`

```zig
pub fn send(self: *Self, comptime T: type, msg_ptr: *anyopaque) !void
```

---

## one_shot.zig

### Module Documentation

A one-shot channel that can send exactly one value from sender to receiver

Uses atomic operations and spinning for synchronization

Initialize an empty one-shot channel

Send a value through the channel

Returns true if successful, false if already used

Receive a value from the channel (blocking with spinning)

Returns the value if successful, null if channel was already consumed

Try to receive without blocking

Returns the value if available, null otherwise

Check if the channel is ready to be consumed

Check if the channel has been consumed

Check if the channel is still empty

Convenience wrapper that provides sender and receiver handles

Sender handle for one-shot channel

Receiver handle for one-shot channel

### Functions

#### `OneShotChannel`

A one-shot channel that can send exactly one value from sender to receiver
Uses atomic operations and spinning for synchronization

```zig
pub fn OneShotChannel(comptime T: type) type
```

#### `init`

Initialize an empty one-shot channel

```zig
pub fn init() Self
```

#### `send`

Send a value through the channel
Returns true if successful, false if already used

```zig
pub fn send(self: *Self, value: T) bool
```

#### `receive`

Receive a value from the channel (blocking with spinning)
Returns the value if successful, null if channel was already consumed

```zig
pub fn receive(self: *Self) ?T
```

#### `tryReceive`

Try to receive without blocking
Returns the value if available, null otherwise

```zig
pub fn tryReceive(self: *Self) ?T
```

#### `isReady`

Check if the channel is ready to be consumed

```zig
pub fn isReady(self: *Self) bool
```

#### `isConsumed`

Check if the channel has been consumed

```zig
pub fn isConsumed(self: *Self) bool
```

#### `isEmpty`

Check if the channel is still empty

```zig
pub fn isEmpty(self: *Self) bool
```

#### `oneShotChannel`

Convenience wrapper that provides sender and receiver handles

```zig
pub fn oneShotChannel(comptime T: type) struct
```

#### `Sender`

Sender handle for one-shot channel

```zig
pub fn Sender(comptime T: type) type
```

#### `send`

```zig
pub fn send(self: Self, value: T) bool
```

#### `deinit`

```zig
pub fn deinit(self: Self) void
```

#### `Receiver`

Receiver handle for one-shot channel

```zig
pub fn Receiver(comptime T: type) type
```

#### `receive`

```zig
pub fn receive(self: Self) ?T
```

#### `tryReceive`

```zig
pub fn tryReceive(self: Self) ?T
```

#### `isReady`

```zig
pub fn isReady(self: Self) bool
```

#### `isConsumed`

```zig
pub fn isConsumed(self: Self) bool
```

#### `isEmpty`

```zig
pub fn isEmpty(self: Self) bool
```

---

