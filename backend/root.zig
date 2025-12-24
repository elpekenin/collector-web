//! Functions used on frontend to interact with database
//!
//! Note that leaking resources is not a big deal since most times we will be using an arena
//! As such, everything will be free'd when the response is sent by client
//!
//! Regardless, those leaks are still a bad thing, lets try and not make any :)

const std = @import("std");
const Allocator = std.mem.Allocator;

const ptz = @import("ptz");
const sdk = ptz.Sdk(.en);

pub const database = @import("database.zig");

pub fn init(allocator: Allocator) !void {
    try database.init(allocator);
}

pub fn allCards(allocator: Allocator, name: []const u8) ![]const database.Card {
    var session = try database.session(allocator);
    defer session.deinit();

    var allocating: std.Io.Writer.Allocating = .init(allocator);
    defer allocating.deinit();

    try allocating.writer.print("%{s}%", .{name});

    const wildcard = try allocating.toOwnedSlice();
    defer allocator.free(wildcard);

    return session
        .query(database.Card)
        .whereRaw("name like ?", .{wildcard})
        .findAll();
}

fn updateOne(allocator: Allocator, session: *database.Session, card: sdk.Card) !u64 {
    const id: []const u8, const name: []const u8, const image: ?ptz.Image = switch (card) {
        inline else => |c| .{ c.id, c.name, c.image },
    };

    var allocating: std.Io.Writer.Allocating = .init(allocator);
    defer allocating.deinit();

    if (image) |img| {
        allocating.clearRetainingCapacity();

        img.toUrl(&allocating.writer, .high, .jpg) catch {
            allocating.clearRetainingCapacity();
        };
    }

    const url, const free = if (allocating.toOwnedSlice()) |slice|
        .{ slice, true }
    else |_|
        .{ "", false };
    defer if (free) allocator.free(url);

    return session.insert(database.Card, .{
        .card_id = id,
        .name = name,
        .image_url = url,
    });
}

// TODO:
//   run this in another thread or something, so that client sees output rendered instantly
//       perhaps a websocket or something to show a "loading" state or the like
//       alternatively, run this as a backend-only thing, not exposed in an endpoint
//   rate limit and/or restrict which users can trigger it
//   run each of the queries for detailed info inside `for (briefs) |brief|` in parallel
pub fn updateAll(allocator: Allocator, name: []const u8) !void {
    var session = try database.session(allocator);
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

            const card: sdk.Card = try .get(
                allocator,
                .{ .id = brief.id },
            );
            defer card.deinit();

            _ = try updateOne(allocator, &session, card);
        }
    }
}
