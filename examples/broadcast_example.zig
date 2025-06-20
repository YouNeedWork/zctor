const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// News message that will be broadcast to all subscribers
const NewsMessage = union(enum) {
    Breaking: []const u8,
    Sports: []const u8,
    Weather: []const u8,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .Breaking => |news| {
                std.debug.print("[Thread {}] 🚨 BREAKING NEWS: {s}\n", .{ thread_id, news });
            },
            .Sports => |news| {
                std.debug.print("[Thread {}] ⚽ SPORTS: {s}\n", .{ thread_id, news });
            },
            .Weather => |news| {
                std.debug.print("[Thread {}] 🌤️  WEATHER: {s}\n", .{ thread_id, news });
            },
        }
        return null;
    }
};

// Event message for event-driven architecture
const EventMessage = union(enum) {
    UserLogin: struct { user_id: u32, timestamp: u64 },
    UserLogout: struct { user_id: u32, timestamp: u64 },
    OrderPlaced: struct { order_id: u32, amount: f64 },

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .UserLogin => |event| {
                std.debug.print("[Thread {}] 👤 User {} logged in at {}\n", .{ thread_id, event.user_id, event.timestamp });
            },
            .UserLogout => |event| {
                std.debug.print("[Thread {}] 👋 User {} logged out at {}\n", .{ thread_id, event.user_id, event.timestamp });
            },
            .OrderPlaced => |event| {
                std.debug.print("[Thread {}] 🛒 Order {} placed for ${d:.2}\n", .{ thread_id, event.order_id, event.amount });
            },
        }
        return null;
    }
};

// Notification handler that processes different types of notifications
const NotificationMessage = union(enum) {
    Email: []const u8,
    SMS: []const u8,
    Push: []const u8,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .Email => |content| {
                std.debug.print("[Thread {}] 📧 Email notification: {s}\n", .{ thread_id, content });
            },
            .SMS => |content| {
                std.debug.print("[Thread {}] 📱 SMS notification: {s}\n", .{ thread_id, content });
            },
            .Push => |content| {
                std.debug.print("[Thread {}] 🔔 Push notification: {s}\n", .{ thread_id, content });
            },
        }
        return null;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    std.debug.print("🚀 Creating broadcast messaging system...\n", .{});
    std.debug.print("Available threads: {}\n", .{engine.getThreadCount()});

    // Create multiple threads with news subscribers
    const thread1 = try ActorThread.init(allocator);
    try thread1.registerActor(try Actor(NewsMessage).init(allocator, NewsMessage.handle));
    try engine.spawn(thread1);

    const thread2 = try ActorThread.init(allocator);
    try thread2.registerActor(try Actor(NewsMessage).init(allocator, NewsMessage.handle));
    try engine.spawn(thread2);

    const thread3 = try ActorThread.init(allocator);
    try thread3.registerActor(try Actor(NewsMessage).init(allocator, NewsMessage.handle));
    try engine.spawn(thread3);

    // Create threads with event handlers
    const thread4 = try ActorThread.init(allocator);
    try thread4.registerActor(try Actor(EventMessage).init(allocator, EventMessage.handle));
    try engine.spawn(thread4);

    const thread5 = try ActorThread.init(allocator);
    try thread5.registerActor(try Actor(EventMessage).init(allocator, EventMessage.handle));
    try engine.spawn(thread5);

    // Create notification handlers
    const thread6 = try ActorThread.init(allocator);
    try thread6.registerActor(try Actor(NotificationMessage).init(allocator, NotificationMessage.handle));
    try engine.spawn(thread6);

    // Give threads time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n📊 Actor registry:\n", .{});
    const registry = engine.getActorRegistry();
    var iter = registry.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s} -> Thread {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    std.debug.print("\n=== 📡 Testing Broadcast Messaging ===\n", .{});

    // Test 1: Broadcast news to all news subscribers
    std.debug.print("\n🔥 Broadcasting breaking news...\n", .{});
    var breaking_news = NewsMessage{ .Breaking = "Major earthquake detected!" };
    try engine.broadcast(NewsMessage, &breaking_news);

    std.time.sleep(50 * std.time.ns_per_ms);

    std.debug.print("\n⚽ Broadcasting sports news...\n", .{});
    var sports_news = NewsMessage{ .Sports = "Local team wins championship!" };
    try engine.broadcast(NewsMessage, &sports_news);

    std.time.sleep(50 * std.time.ns_per_ms);

    std.debug.print("\n🌤️  Broadcasting weather update...\n", .{});
    var weather_news = NewsMessage{ .Weather = "Sunny skies expected tomorrow" };
    try engine.broadcast(NewsMessage, &weather_news);

    std.time.sleep(50 * std.time.ns_per_ms);

    // Test 2: Broadcast events to all event handlers
    std.debug.print("\n📅 Broadcasting user events...\n", .{});
    var login_event = EventMessage{ .UserLogin = .{ .user_id = 12345, .timestamp = 1640995200 } };
    try engine.broadcast(EventMessage, &login_event);

    std.time.sleep(50 * std.time.ns_per_ms);

    var order_event = EventMessage{ .OrderPlaced = .{ .order_id = 98765, .amount = 299.99 } };
    try engine.broadcast(EventMessage, &order_event);

    std.time.sleep(50 * std.time.ns_per_ms);

    var logout_event = EventMessage{ .UserLogout = .{ .user_id = 12345, .timestamp = 1640998800 } };
    try engine.broadcast(EventMessage, &logout_event);

    std.time.sleep(50 * std.time.ns_per_ms);

    // Test 3: Send targeted notifications (not broadcast)
    std.debug.print("\n📬 Sending targeted notifications...\n", .{});
    var email_notif = NotificationMessage{ .Email = "Welcome to our service!" };
    try engine.send(NotificationMessage, &email_notif);

    std.time.sleep(50 * std.time.ns_per_ms);

    var sms_notif = NotificationMessage{ .SMS = "Your order has shipped" };
    try engine.send(NotificationMessage, &sms_notif);

    std.time.sleep(50 * std.time.ns_per_ms);

    var push_notif = NotificationMessage{ .Push = "New message received" };
    try engine.send(NotificationMessage, &push_notif);

    std.debug.print("\n✅ All broadcast and messaging tests completed!\n", .{});

    // Start the engine to process remaining messages
    engine.start();
}
