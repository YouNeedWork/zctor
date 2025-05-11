const std = @import("std");
const typ = std.builtin.Type;
const xev = @import("xev");

pub const Ctx = struct {
    loop: *xev.Loop,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, loop: *xev.Loop) !*Self {
        const ctx = try allocator.create(Self);
        ctx.* = .{
            .loop = loop,
        };

        return ctx;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

pub fn Actor(comptime T: anytype) type {
    return struct {
        mailbox: std.fifo.LinearFifo(T, .{ .Static = 100 }),
        ctx: *Ctx,
        event: xev.Async,
        completion: xev.Completion,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, ctx: *Ctx) !*Self {
            const self = try allocator.create(Self);

            self.* = .{
                .mailbox = std.fifo.LinearFifo(
                    T,
                    .{ .Static = 100 },
                ).init(),
                .ctx = ctx,
                .completion = undefined,
                .event = try xev.Async.init(),
            };

            return self;
        }

        fn actorCallback(
            ud: ?*Self,
            l: *xev.Loop,
            c: *xev.Completion,
            r: xev.Async.WaitError!void,
        ) xev.CallbackAction {
            _ = l;
            _ = c;
            _ = r catch unreachable;

            const self: *Self = ud.?;

            std.debug.print("Actor callback executed, mailbox size: {}\n", .{self.mailbox.count});

            // Process messages in the mailbox
            while (self.mailbox.count > 0) {
                const msg: i32 = self.mailbox.readItem().?;
                std.debug.print("Processing message: {}\n", .{msg});
            }

            return .rearm; // Rearm to receive more notifications
        }

        pub fn run(self: *Self) void {
            self.setup_callback();
        }

        fn setup_callback(self: *Self) void {
            self.event.wait(self.ctx.loop, &self.completion, Self, self, Self.actorCallback);
        }

        // 添加一个处理原始消息的方法
        pub fn handleRawMessage(self: *Self, msg_ptr: *anyopaque) !void {
            const typed_msg = @as(*T, @ptrCast(@alignCast(msg_ptr)));
            return self.sender(typed_msg.*);
        }

        pub fn sender(self: *Self, msg: T) !void {
            //TODO: cap checking
            try self.mailbox.writeItem(msg);
            try self.event.notify();
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.mailbox.deinit();
            allocator.destroy(self);
        }
    };
}

const ActorThread = struct {
    loop: xev.Loop,
    ctx: *Ctx,
    actors: std.ArrayList(ActorInterface),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.loop = try xev.Loop.init(.{});
        self.ctx = try Ctx.init(allocator, &self.loop);
        self.actors = std.ArrayList(ActorInterface).init(allocator);

        return self;
    }

    pub fn regiestActor(self: *Self, actor: anytype) !void {
        //TODO: init in threads so we need to deinit all
        try self.actors.append(ActorInterface.init(actor));
    }

    pub fn sender(self: *Self, T: type, msg_ptr: *anyopaque) void {
        _ = T;
        for (self.actors.items) |actor| {
            actor.sender(msg_ptr);
        }
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.actors.items) |actor| {
            actor.deinit(allocator);
        }

        self.actors.deinit();
        self.ctx.deinit(allocator);
        self.loop.deinit();
        allocator.destroy(self);
    }

    pub fn run(self: *Self) !void {
        for (self.actors.items) |actor| {
            actor.run();
        }
    }

    pub fn start_loop(self: *Self) !void {
        try self.loop.run(.until_done);
    }
};

const ActorEngine = struct {
    allocator: std.mem.Allocator,
    actor_threads: [128]*ActorThread,
    wg: std.Thread.WaitGroup,
    threads: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.allocator = allocator;
        self.wg.reset();
        self.threads = 0;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn run(self: *Self) !void {
        const cpu_count = try std.Thread.getCpuCount();
        self.threads = cpu_count;
        self.wg.startMany(cpu_count);

        for (0..cpu_count) |i| {
            const t = try std.Thread.spawn(.{}, thread_run, .{ self, i });
            t.detach();
        }

        self.wg.wait();
    }

    fn thread_run(self: *Self, idx: usize) !void {
        // Init ActorThread
        const actor_thread = ActorThread.init(self.allocator) catch {
            std.debug.print("failed to init actor thread {}\n", .{idx});
            return;
        };

        self.actor_threads[idx] = actor_thread;
        try actor_thread.regiestActor(try Actor(i32).init(self.allocator, actor_thread.ctx));
        try actor_thread.run();

        var p: i32 = 10000;
        actor_thread.sender(Actor(i32), &p);
        actor_thread.sender(Actor(i32), &p);
        try actor_thread.start_loop();

        actor_thread.deinit(self.allocator);
        self.wg.finish();
    }
};

pub const ActorInterface = struct {
    ptr: *anyopaque, // 指向实际 Actor 实例的指针
    vtable: *const VTable, // 指向虚拟函数表的指针

    const Self = @This();

    // 虚拟函数表定义
    pub const VTable = struct {
        run: *const fn (ptr: *anyopaque) void,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
        sender: *const fn (ptr: *anyopaque, msg: *anyopaque) void,
        handleRawMessage: *const fn (ptr: *anyopaque, msg_ptr: *anyopaque) void,
    };

    // 方便使用的包装方法
    pub fn run(self: Self) void {
        return self.vtable.run(self.ptr);
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        return self.vtable.deinit(self.ptr, allocator);
    }

    pub fn sender(self: Self, msg: *anyopaque) void {
        return self.vtable.sender(self.ptr, msg);
    }

    pub fn handleRawMessage(self: Self, msg: *anyopaque) void {
        return self.vtable.handleRawMessage(self.ptr, msg);
    }

    // 从任何类型创建一个 ActorInterface
    pub fn init(actor: anytype) ActorInterface {
        const T = @TypeOf(actor);

        //TODO: check actor has the impl.

        // 为类型 T 创建静态 vtable
        const vtable = comptime blk: {
            //const alignment = @alignOf(T);

            const runFn = struct {
                fn function(ptr: *anyopaque) void {
                    const self: T = @ptrCast(@alignCast(ptr));
                    self.run();
                }
            }.function;

            const deinitFn = struct {
                fn function(ptr: *anyopaque, allocator: std.mem.Allocator) void {
                    const self: T = @ptrCast(@alignCast(ptr));
                    self.deinit(allocator);
                }
            }.function;

            const senderFn = struct {
                fn function(ptr: *anyopaque, msg_ptr: *anyopaque) void {
                    const self: T = @ptrCast(@alignCast(ptr));
                    self.handleRawMessage(msg_ptr) catch {
                        std.debug.print("failed to process message", .{});
                    };
                }
            }.function;

            const handleRawMessageFn = struct {
                fn function(ptr: *anyopaque, msg_ptr: *anyopaque) void {
                    const self: T = @ptrCast(@alignCast(ptr));
                    self.handleRawMessage(msg_ptr) catch {
                        std.debug.print("failed to process message", .{});
                    };
                }
            }.function;

            break :blk &VTable{
                .run = runFn,
                .deinit = deinitFn,
                .sender = senderFn,
                .handleRawMessage = handleRawMessageFn,
            };
        };

        return .{
            .ptr = actor,
            .vtable = vtable,
        };
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    try engine.run();
    engine.deinit();
}
