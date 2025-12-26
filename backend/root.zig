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

pub fn printStr(allocator: Allocator, comptime fmt: []const u8, args: anytype) ![]const u8 {
    var allocating: std.Io.Writer.Allocating = .init(allocator);
    defer allocating.deinit();

    try allocating.writer.print(fmt, args);

    return allocating.toOwnedSlice();
}

pub fn allCards(allocator: Allocator, name: []const u8) ![]const database.Card {
    var session = try database.session(allocator);
    defer session.deinit();

    const wildcard = try printStr(allocator, "%{s}%", .{name});
    defer allocator.free(wildcard);

    return session
        .query(database.Card)
        .whereRaw("name like ?", .{wildcard})
        .findAll();
}

const InsertRes = struct {
    new_row: bool,
};

fn insert(allocator: Allocator, session: *database.Session, brief: sdk.Card.Brief) !InsertRes {
    const image = brief.image orelse return error.ImageNotFound;

    const url = try printStr(allocator, "{f}", .{image});
    defer allocator.free(url);

    // ignore TCG Pocket cards
    if (std.mem.indexOf(u8, url, "tcgp")) |_| {
        return .{ .new_row = false };
    }

    _ = session.insert(database.Card, .{
        .card_id = brief.id,
        .name = brief.name,
        .image_url = url,
    }) catch |err| return switch (err) {
        // card existed, but let's not actually errors
        error.UniqueViolation => .{ .new_row = false },
        else => return err,
    };

    //TODO: parse variants

    return .{ .new_row = true };
}

const FetchRes = struct {
    card_count: usize,
    ms_elapsed: usize,
};

pub fn fetch(allocator: Allocator, name: []const u8) !FetchRes {
    var timer: std.time.Timer = try .start();

    var session = try database.session(allocator);
    defer session.deinit();

    var iterator = sdk.Card.all(allocator, .{
        .page_size = 250,
        .where = &.{
            .like(.name, name),
        },
    });

    var n_cards: usize = 0;
    while (iterator.next() catch null) |briefs| {
        for (briefs) |brief| {
            defer brief.deinit();

            const res = try insert(allocator, &session, brief);
            if (res.new_row) n_cards += 1;
        }
    }

    return .{
        .card_count = n_cards,
        .ms_elapsed = timer.read() / 1_000_000, // ns to ms
    };
}
