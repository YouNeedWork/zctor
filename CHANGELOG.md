# Changelog

All notable changes to zctor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-20

### 🚀 Major Features Added

#### Multi-Threading Architecture
- **True Multi-Threading**: Complete rewrite to support actors running on separate OS threads
- **Actor Registry**: Smart mapping system that tracks which threads have which actor types
- **Intelligent Load Balancing**: Round-robin distribution across multiple instances of the same actor type
- **Cross-Thread Communication**: Seamless messaging between actors on different threads

#### New Messaging Patterns
- **`engine.send()`**: Fire-and-forget messaging with automatic load balancing
- **`engine.call()`**: Synchronous request-response pattern across thread boundaries
- **`engine.broadcast()`**: One-to-many messaging to all instances of an actor type

#### Enhanced Actor System
- **ActorThread**: New component for managing actors within a single thread context
- **Thread-Safe State Management**: Each actor instance maintains isolated state
- **Context Enhancement**: Added thread_id and enhanced runtime context
- **Memory Safety**: Improved memory management with proper cleanup

### 📡 New Examples

#### Basic Examples
- **Call Example** (`run-call`): Request-response pattern demonstration
- **Multi-Threading Example** (`run-multi`): Basic cross-thread communication

#### Advanced Examples  
- **Broadcast Example** (`run-broadcast`): One-to-many messaging patterns
- **Thread Communication Example** (`run-thread-comm`): Comprehensive communication patterns
- **Publisher-Subscriber Example** (`run-pubsub`): Real-world pub-sub system
- **Load Balancing Example** (`run-load-balance`): Intelligent load distribution

### 🔧 API Changes

#### New ActorEngine Methods
```zig
// Multi-threading support
pub fn spawn(actor_thread: *ActorThread) !void
pub fn getThreadCount() usize
pub fn getActorRegistry() *const StringArrayHashMap(ArrayList(usize))

// Enhanced messaging
pub fn send(comptime T: type, msg: *T) !void          // Load-balanced
pub fn call(comptime T: type, msg: *T) !?*anyopaque   // Request-response
pub fn broadcast(comptime T: type, msg: *T) !void     // One-to-many
```

#### New ActorThread Component
```zig
pub fn init(allocator: Allocator) !*ActorThread
pub fn registerActor(actor: *Actor(T)) !void
pub fn send(comptime T: type, msg: *T) !void
pub fn call(comptime T: type, msg: *T) !?*anyopaque
pub fn deinit(allocator: Allocator) void
```

#### Enhanced Actor Methods
```zig
pub fn getContext() *Context  // Now includes thread_id
```

### 🏗️ Architecture Improvements

#### Actor Registry System
- **Multi-Instance Support**: Registry now maps actor types to lists of thread IDs
- **Dynamic Registration**: Threads automatically register their actor types
- **Smart Routing**: Messages automatically routed to appropriate threads

#### Load Balancing Engine
- **Round-Robin Algorithm**: Even distribution across available threads
- **Atomic Counters**: Thread-safe load balancing counters
- **Performance Optimization**: Minimal overhead for thread selection

#### Thread Management
- **Thread Pool**: Efficient management of multiple actor threads
- **Graceful Shutdown**: Proper cleanup of all threads and resources
- **Error Isolation**: Thread failures don't affect other threads

### 📊 Performance Improvements

#### Concurrency
- **True Parallelism**: Actors can now run simultaneously on different CPU cores
- **Scalability**: System scales with available CPU cores
- **Throughput**: Significant performance improvements for CPU-intensive workloads

#### Memory Management
- **Thread-Local Allocators**: Each actor has its own allocator for thread safety
- **Efficient Message Passing**: Messages copied between threads to avoid shared state
- **Resource Cleanup**: Improved cleanup of actor state and responses

### 🛡️ Safety Improvements

#### Thread Safety
- **No Shared Mutable State**: All communication via message passing
- **Isolated Actor State**: Each actor instance has separate state
- **Type Safety**: Compile-time guarantees for message types

#### Error Handling
- **Graceful Degradation**: Thread failures isolated from other threads
- **Error Propagation**: Proper error handling across thread boundaries
- **Resource Management**: Automatic cleanup of failed operations

### 📚 Documentation

#### New Documentation Files
- **EXAMPLES.md**: Comprehensive guide to all examples
- **MULTI_THREADING.md**: Detailed multi-threading architecture guide
- **CHANGELOG.md**: This changelog file

#### Updated Documentation
- **README.md**: Complete rewrite showcasing multi-threading capabilities
- **API Reference**: Updated with all new methods and components
- **Architecture Section**: Detailed explanation of multi-threading design

### 🔄 Breaking Changes

#### API Changes
- **`engine.spawn()`**: Now takes `ActorThread` instead of actor type and handler
- **Actor Creation**: Must now create `ActorThread` and register actors explicitly
- **Message Handlers**: Return type changed to `?*anyopaque` for call support

#### Migration Guide
```zig
// Old API (v1.x)
try engine.spawn(MyMessage, MyMessage.handle);

// New API (v2.x)
const thread = try ActorThread.init(allocator);
try thread.registerActor(try Actor(MyMessage).init(allocator, MyMessage.handle));
try engine.spawn(thread);
```

### 🧪 Testing

#### New Test Coverage
- Multi-threading functionality tests
- Load balancing verification tests
- Cross-thread communication tests
- Actor registry tests

#### Example Verification
- All examples include comprehensive output verification
- Thread ID tracking for multi-threading validation
- Performance statistics for load balancing validation

### 🚀 Real-World Use Cases

The new multi-threading capabilities enable zctor to be used for:

#### High-Performance Applications
- **Web Servers**: Request handling with load balancing
- **Data Processing**: Parallel processing pipelines
- **Real-Time Systems**: Event broadcasting and distribution
- **Microservices**: Inter-service communication

#### Scalable Systems
- **Distributed Computing**: Task distribution across cores
- **IoT Systems**: Sensor data aggregation and processing
- **Game Servers**: Player message handling and game state management
- **Financial Systems**: Real-time trading and market data processing

### 🎯 Future Roadmap

#### Planned Features
- **Network Distribution**: Actors across multiple machines
- **Persistence**: Actor state persistence and recovery
- **Monitoring**: Built-in metrics and monitoring capabilities
- **Hot Code Reloading**: Dynamic actor updates without downtime

#### Performance Optimizations
- **Lock-Free Queues**: Further performance improvements
- **NUMA Awareness**: CPU topology-aware thread placement
- **Adaptive Load Balancing**: Dynamic load balancing based on actual load

---

## [1.0.0] - 2024-12-01

### Initial Release

#### Core Features
- Basic actor model implementation
- Single-threaded message passing
- State management within actors
- Event loop integration with libxev

#### Components
- **ActorEngine**: Basic actor system management
- **Actor(T)**: Generic actor type
- **Context**: Runtime context for actors

#### Examples
- Simple message passing example
- Basic state management demonstration

---

## Version Numbering

- **Major version** (X.0.0): Breaking changes, major new features
- **Minor version** (0.X.0): New features, backward compatible
- **Patch version** (0.0.X): Bug fixes, backward compatible

## Contributing

See [README.md](README.md#contributing) for contribution guidelines.

## License

See [LICENSE](LICENSE) file for license information.
