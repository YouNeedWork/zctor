//! zctor - A lightweight actor framework for Zig
//!
//! This library provides an implementation of the Actor Model with:
//! - Actor-based concurrency
//! - Multi-threaded execution
//! - Asynchronous message passing
//! - Built-in state management
// Export the main actor framework components
pub const Actor = @import("actor.zig").Actor;
pub const ActorEngine = @import("actor_engine.zig");
pub const ActorThread = @import("actor_thread.zig");
pub const ActorInterface = @import("actor_interface.zig");
pub const Context = @import("context.zig");

test "library imports" {
    // Ensure all modules can be imported
    _ = Actor;
    _ = ActorEngine;
    _ = ActorThread;
    _ = ActorInterface;
    _ = Context;
}
