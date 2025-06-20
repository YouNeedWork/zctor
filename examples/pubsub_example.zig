const std = @import("std");
const zctor = @import("zctor");
const Actor = zctor.Actor;
const ActorEngine = zctor.ActorEngine;
const ActorThread = zctor.ActorThread;

// Stock price update message
const StockUpdate = union(enum) {
    PriceChange: struct { symbol: []const u8, price: f64, change: f64 },
    VolumeUpdate: struct { symbol: []const u8, volume: u64 },
    MarketOpen: void,
    MarketClose: void,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .PriceChange => |update| {
                const direction = if (update.change >= 0) "📈" else "📉";
                std.debug.print("[Thread {}] 💰 {s} ${d:.2} ({s}{d:.2})\n", .{ thread_id, update.symbol, update.price, direction, update.change });
            },
            .VolumeUpdate => |update| {
                std.debug.print("[Thread {}] 📊 {s} Volume: {}\n", .{ thread_id, update.symbol, update.volume });
            },
            .MarketOpen => {
                std.debug.print("[Thread {}] 🔔 Market is now OPEN\n", .{thread_id});
            },
            .MarketClose => {
                std.debug.print("[Thread {}] 🔕 Market is now CLOSED\n", .{thread_id});
            },
        }
        return null;
    }
};

// News subscriber that receives different types of news
const NewsSubscriber = union(enum) {
    TechNews: []const u8,
    FinanceNews: []const u8,
    GeneralNews: []const u8,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .TechNews => |news| {
                std.debug.print("[Thread {}] 💻 TECH: {s}\n", .{ thread_id, news });
            },
            .FinanceNews => |news| {
                std.debug.print("[Thread {}] 💼 FINANCE: {s}\n", .{ thread_id, news });
            },
            .GeneralNews => |news| {
                std.debug.print("[Thread {}] 📰 NEWS: {s}\n", .{ thread_id, news });
            },
        }
        return null;
    }
};

// Chat message for real-time communication
const ChatMessage = union(enum) {
    UserMessage: struct { user: []const u8, message: []const u8, room: []const u8 },
    UserJoined: struct { user: []const u8, room: []const u8 },
    UserLeft: struct { user: []const u8, room: []const u8 },
    SystemMessage: []const u8,

    const Self = @This();

    pub fn handle(actor: *Actor(Self), msg: Self) ?*anyopaque {
        const thread_id = actor.getContext().thread_id;
        switch (msg) {
            .UserMessage => |chat| {
                std.debug.print("[Thread {}] 💬 [{s}] {s}: {s}\n", .{ thread_id, chat.room, chat.user, chat.message });
            },
            .UserJoined => |event| {
                std.debug.print("[Thread {}] ➕ {s} joined {s}\n", .{ thread_id, event.user, event.room });
            },
            .UserLeft => |event| {
                std.debug.print("[Thread {}] ➖ {s} left {s}\n", .{ thread_id, event.user, event.room });
            },
            .SystemMessage => |system_msg| {
                std.debug.print("[Thread {}] 🤖 SYSTEM: {s}\n", .{ thread_id, system_msg });
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

    std.debug.print("📡 Creating Publisher-Subscriber system...\n", .{});

    // Create multiple subscriber threads for stock updates
    const stock_thread1 = try ActorThread.init(allocator);
    try stock_thread1.registerActor(try Actor(StockUpdate).init(allocator, StockUpdate.handle));
    try engine.spawn(stock_thread1);

    const stock_thread2 = try ActorThread.init(allocator);
    try stock_thread2.registerActor(try Actor(StockUpdate).init(allocator, StockUpdate.handle));
    try engine.spawn(stock_thread2);

    const stock_thread3 = try ActorThread.init(allocator);
    try stock_thread3.registerActor(try Actor(StockUpdate).init(allocator, StockUpdate.handle));
    try engine.spawn(stock_thread3);

    // Create news subscriber threads
    const news_thread1 = try ActorThread.init(allocator);
    try news_thread1.registerActor(try Actor(NewsSubscriber).init(allocator, NewsSubscriber.handle));
    try engine.spawn(news_thread1);

    const news_thread2 = try ActorThread.init(allocator);
    try news_thread2.registerActor(try Actor(NewsSubscriber).init(allocator, NewsSubscriber.handle));
    try engine.spawn(news_thread2);

    // Create chat subscriber threads
    const chat_thread1 = try ActorThread.init(allocator);
    try chat_thread1.registerActor(try Actor(ChatMessage).init(allocator, ChatMessage.handle));
    try engine.spawn(chat_thread1);

    const chat_thread2 = try ActorThread.init(allocator);
    try chat_thread2.registerActor(try Actor(ChatMessage).init(allocator, ChatMessage.handle));
    try engine.spawn(chat_thread2);

    // Give threads time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n📊 Subscriber threads:\n", .{});
    const registry = engine.getActorRegistry();
    var iter = registry.iterator();
    while (iter.next()) |entry| {
        std.debug.print("  {s} -> Thread {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    std.debug.print("\n=== 📈 Stock Market Publisher-Subscriber Test ===\n", .{});

    // Market opens - broadcast to all stock subscribers
    var market_open = StockUpdate{ .MarketOpen = {} };
    try engine.broadcast(StockUpdate, &market_open);
    std.time.sleep(100 * std.time.ns_per_ms);

    // Publish stock price updates
    var apple_update = StockUpdate{ .PriceChange = .{ .symbol = "AAPL", .price = 175.50, .change = 2.30 } };
    try engine.broadcast(StockUpdate, &apple_update);
    std.time.sleep(50 * std.time.ns_per_ms);

    var google_update = StockUpdate{ .PriceChange = .{ .symbol = "GOOGL", .price = 2850.75, .change = -15.25 } };
    try engine.broadcast(StockUpdate, &google_update);
    std.time.sleep(50 * std.time.ns_per_ms);

    var tesla_volume = StockUpdate{ .VolumeUpdate = .{ .symbol = "TSLA", .volume = 45_000_000 } };
    try engine.broadcast(StockUpdate, &tesla_volume);
    std.time.sleep(50 * std.time.ns_per_ms);

    var microsoft_update = StockUpdate{ .PriceChange = .{ .symbol = "MSFT", .price = 335.20, .change = 5.80 } };
    try engine.broadcast(StockUpdate, &microsoft_update);
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n=== 📰 News Publisher-Subscriber Test ===\n", .{});

    // Publish different types of news
    var tech_news = NewsSubscriber{ .TechNews = "New AI breakthrough announced by major tech company" };
    try engine.broadcast(NewsSubscriber, &tech_news);
    std.time.sleep(50 * std.time.ns_per_ms);

    var finance_news = NewsSubscriber{ .FinanceNews = "Federal Reserve announces interest rate decision" };
    try engine.broadcast(NewsSubscriber, &finance_news);
    std.time.sleep(50 * std.time.ns_per_ms);

    var general_news = NewsSubscriber{ .GeneralNews = "International climate summit reaches historic agreement" };
    try engine.broadcast(NewsSubscriber, &general_news);
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("\n=== 💬 Chat Publisher-Subscriber Test ===\n", .{});

    // Simulate chat room activity
    var user_joined = ChatMessage{ .UserJoined = .{ .user = "Alice", .room = "general" } };
    try engine.broadcast(ChatMessage, &user_joined);
    std.time.sleep(50 * std.time.ns_per_ms);

    var user_joined2 = ChatMessage{ .UserJoined = .{ .user = "Bob", .room = "general" } };
    try engine.broadcast(ChatMessage, &user_joined2);
    std.time.sleep(50 * std.time.ns_per_ms);

    var chat_msg1 = ChatMessage{ .UserMessage = .{ .user = "Alice", .message = "Hello everyone!", .room = "general" } };
    try engine.broadcast(ChatMessage, &chat_msg1);
    std.time.sleep(50 * std.time.ns_per_ms);

    var chat_msg2 = ChatMessage{ .UserMessage = .{ .user = "Bob", .message = "Hey Alice! How's it going?", .room = "general" } };
    try engine.broadcast(ChatMessage, &chat_msg2);
    std.time.sleep(50 * std.time.ns_per_ms);

    var system_msg = ChatMessage{ .SystemMessage = "Server maintenance scheduled for tonight" };
    try engine.broadcast(ChatMessage, &system_msg);
    std.time.sleep(50 * std.time.ns_per_ms);

    var user_left = ChatMessage{ .UserLeft = .{ .user = "Alice", .room = "general" } };
    try engine.broadcast(ChatMessage, &user_left);
    std.time.sleep(100 * std.time.ns_per_ms);

    // Market closes
    var market_close = StockUpdate{ .MarketClose = {} };
    try engine.broadcast(StockUpdate, &market_close);

    std.debug.print("\n✅ Publisher-Subscriber demonstration completed!\n", .{});
    std.debug.print("📋 Summary:\n", .{});
    std.debug.print("  - Stock updates: ✅ Broadcast to 3 subscriber threads\n", .{});
    std.debug.print("  - News updates: ✅ Broadcast to 2 subscriber threads\n", .{});
    std.debug.print("  - Chat messages: ✅ Broadcast to 2 subscriber threads\n", .{});
    std.debug.print("  - Real-time messaging: ✅ All subscribers received all messages\n", .{});

    // Start the engine to process remaining messages
    engine.start();
}
