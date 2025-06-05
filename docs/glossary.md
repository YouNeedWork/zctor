# Glossary

## A

**Actor**  
An isolated computational unit that processes messages sequentially and maintains private state. Actors are the fundamental building blocks of the actor model.

**Actor Model**  
A mathematical model of concurrent computation where actors are the universal primitives. In response to a message, an actor can make local decisions, create more actors, send more messages, and designate what to do with the next message.

**Actor System**  
A collection of actors working together under the management of an ActorEngine. The system provides infrastructure for actor creation, message routing, and lifecycle management.

**ActorEngine**  
The top-level component that manages the actor system, including thread pool management, actor spawning, and message routing.

**ActorThread**  
A thread-local manager that handles actors within a single OS thread context, providing event loop integration and message dispatch.

**Allocator**  
A Zig interface for memory allocation and deallocation. zctor uses hierarchical allocators for efficient memory management.

**Arena Allocator**  
A memory allocator that allocates from a large block and frees everything at once. Useful for request-scoped allocations.

**Asynchronous**  
Operations that don't block the calling thread, allowing other work to proceed concurrently.

## B

**Backpressure**  
A mechanism to prevent system overload by controlling the rate of message flow when consumers can't keep up with producers.

**Batch Processing**  
Processing multiple items together for improved efficiency and throughput.

**Blocking Operation**  
An operation that prevents the thread from doing other work until it completes. Should be avoided in actor message handlers.

## C

**Callback**  
A function passed as an argument to be executed at a later time, often used for asynchronous operations.

**Circuit Breaker**  
A design pattern that prevents cascading failures by temporarily disabling operations that are likely to fail.

**Concurrency**  
The ability to handle multiple tasks at the same time, possibly on different threads. Different from parallelism.

**Context**  
Runtime environment and services provided to actors, including access to the event loop and communication facilities.

## D

**Deadlock**  
A situation where two or more actors are waiting for each other indefinitely, causing the system to freeze.

**Distributed System**  
A system where components run on multiple machines connected by a network, requiring special considerations for actor communication.

## E

**Event Loop**  
A programming construct that waits for and dispatches events or messages. zctor uses libxev for cross-platform event loop implementation.

**Event-Driven**  
A programming paradigm where the flow of execution is determined by events such as message arrivals.

## F

**Fault Tolerance**  
The ability of a system to continue operating despite failures of individual components.

**FIFO**  
First In, First Out - a queuing discipline where the first item added is the first to be removed. Used for actor message queues.

## L

**libxev**  
A high-performance, cross-platform event loop library that provides the foundation for zctor's asynchronous operations.

**Load Balancing**  
Distributing work across multiple resources (threads, actors) to optimize performance and resource utilization.

**Lock-Free**  
Programming techniques that avoid using locks for synchronization, reducing contention and improving performance.

## M

**Mailbox**  
The message queue associated with each actor. Messages are processed in FIFO order from the mailbox.

**Message**  
A unit of communication between actors. Messages should be immutable and contain all necessary data for processing.

**Message Handler**  
A function that processes messages for an actor. Takes the actor and message as parameters and optionally returns an error.

**Message Passing**  
A form of communication where actors send messages to each other rather than sharing mutable state.

**Mutex**  
A synchronization primitive that ensures mutual exclusion. Generally avoided in favor of message passing in actor systems.

## P

**Parallelism**  
Executing multiple tasks simultaneously on multiple CPU cores. Different from concurrency.

**Publisher-Subscriber**  
A messaging pattern where publishers send messages to subscribers via topics, enabling loose coupling between components.

## R

**Race Condition**  
A situation where the outcome depends on the relative timing of events, often leading to bugs in concurrent systems.

**Request-Response**  
A communication pattern where one actor sends a request and waits for a response from another actor.

## S

**Scalability**  
The ability of a system to handle increased load by adding resources (horizontal scaling) or more powerful hardware (vertical scaling).

**State**  
Data maintained by an actor between message processing. State should be private to each actor.

**Supervisor**  
An actor responsible for managing the lifecycle of child actors, including restart strategies and fault handling.

**Synchronization**  
Coordination of concurrent activities to ensure correct execution order and data consistency.

## T

**Thread**  
An execution context that can run concurrently with other threads. zctor uses a thread-per-CPU-core model.

**Thread Pool**  
A collection of worker threads used to execute tasks. zctor automatically manages the thread pool based on CPU cores.

**Throughput**  
The number of operations completed per unit of time, a key performance metric for actor systems.

## Z

**Zig**  
A general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software. The language used to implement zctor.

---

## Related Terms

### Actor Model Concepts
- **Encapsulation**: Actors encapsulate state and behavior
- **Location Transparency**: Actors can communicate regardless of physical location
- **Supervision Trees**: Hierarchical structure for fault tolerance

### Concurrency Patterns
- **Actor Isolation**: No shared mutable state between actors
- **Message Immutability**: Messages should not be modified after sending
- **Sequential Processing**: Actors process messages one at a time

### Performance Terms
- **Latency**: Time between sending a message and processing it
- **Backpressure**: Flow control mechanism
- **Work Stealing**: Load balancing technique for thread pools

### System Design
- **Fault Isolation**: Failures in one component don't affect others
- **Graceful Degradation**: System continues with reduced functionality
- **Hot Code Reloading**: Updating code without stopping the system

---

*For more detailed information on any of these terms, refer to the relevant chapters in this documentation.*