//! Functions to update local database with API data

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const ptz = @import("ptz");
const sdk = ptz.Sdk(.en);

const database = @import("database.zig");
const Card = @import("Card.zig");

const ThreadState = struct {
    count: usize,
    finished: bool,
    timer: std.time.Timer,

    fn init() !ThreadState {
        return .{
            .count = 0,
            .finished = false,
            .timer = try .start(),
        };
    }

    fn toState(self: *ThreadState) State {
        return .{
            .count = self.count,
            .finished = self.finished,
            .ms_elapsed = self.timer.read() / std.time.ns_per_ms,
        };
    }
};

const State = struct {
    count: usize,
    finished: bool,
    ms_elapsed: usize,
};

const Map = std.AutoHashMap(u64, *ThreadState);

const state = struct {
    var rng: std.Random.DefaultPrng = .init(123);
    var map: ?Map = null;
};

// numbers should never get bigger than u16 (65k years is far away)
// but we are using u64 to simplify the multiplication (u16 * value causes panic due to overflowing u16)
fn consume(it: *std.mem.SplitIterator(u8, .scalar)) !u64 {
    const buf = it.next() orelse return error.BadDateStr;
    return std.fmt.parseInt(u64, buf, 10);
}

fn dateToNum(release_date: []const u8) !u64 {
    var it = std.mem.splitScalar(u8, release_date, '-');

    const year = try consume(&it);
    const month = try consume(&it);
    const day = try consume(&it);

    return year * 366 + month * 31 + day;
}

/// from a card brief, store all variants into database
fn variants(allocator: Allocator, session: *database.Session, brief: sdk.Card.Brief) !usize {
    const url, const free = if (brief.image) |image|
        .{ try std.fmt.allocPrint(allocator, "{f}", .{image}), true }
    else
        .{ "", false }; // TODO: 404.png or something?
    defer if (free) allocator.free(url);

    // ignore TCG Pocket cards
    if (std.mem.indexOf(u8, url, "tcgp")) |_| {
        return 0;
    }

    const card: sdk.Card = try .get(allocator, .{ .id = brief.id });
    defer card.deinit();

    const set_id = switch (card) {
        inline else => |info| info.set.id,
    };

    const set: sdk.Set = try .get(allocator, .{
        .id = set_id,
    });
    defer set.deinit();

    try Card.insert(session, .{
        .card_id = brief.id,
        .name = brief.name,
        .image_url = url,
        .release_date = try dateToNum(set.releaseDate),
    });

    // TODO: remove this, error out if variants aren't present
    const card_variants: []const ptz.VariantDetailed = switch (card) {
        inline else => |info| info.variant_detailed,
    } orelse return 1;

    for (card_variants) |variant| {
        try Card.Variant.insert(session, .{
            .card_id = brief.id,
            .type = variant.type,
            .subtype = variant.subtype,
            .size = variant.size,
            .stamps = variant.stamp,
            .foil = variant.foil,
        });
    }

    return card_variants.len;
}

fn entrypoint(allocator: Allocator, name: []const u8, id: u64) !void {
    defer allocator.free(name);

    const threads = try getMap();
    assert(!threads.contains(id));

    const thread = try allocator.create(ThreadState);
    thread.* = try .init();
    defer thread.finished = true;

    try threads.put(id, thread);

    var session = try database.getSession(allocator);
    defer session.deinit();

    var iterator = sdk.Card.all(allocator, .{
        .page_size = 250,
        .where = &.{
            .like(.name, name),
        },
    });

    while (iterator.next() catch null) |briefs| {
        for (briefs) |brief| {
            defer brief.deinit();
            thread.count += try variants(allocator, &session, brief);
        }
    }
}

fn getMap() !*Map {
    if (state.map) |*map| {
        return map;
    }

    return error.FetchNotInit;
}

pub fn init(allocator: std.mem.Allocator) !void {
    if (state.map) |_| return;

    state.map = .init(allocator);
}

pub fn all(allocator: Allocator, name: []const u8) !u64 {
    const threads = try getMap();

    const copy = try allocator.dupe(u8, name);
    errdefer allocator.free(copy);

    const id = blk: {
        // avoid collisions
        while (true) {
            const id = state.rng.next();

            if (!threads.contains(id)) {
                break :blk id;
            }
        }
    };

    var thread: std.Thread = try .spawn(.{}, entrypoint, .{ allocator, copy, id });
    thread.detach();

    return id;
}

pub fn stats(id: u64) !State {
    const threads = try getMap();

    const thread = threads.get(id) orelse return error.ThreadNotFound;
    return thread.toState();
}

pub fn cleanup(id: u64) !void {
    const threads = try getMap();

    const thread = threads.get(id) orelse return error.ThreadNotFound;
    if (!thread.finished) return error.ThreadNotFinished;

    threads.allocator.destroy(thread);
    assert(threads.remove(id));
}
