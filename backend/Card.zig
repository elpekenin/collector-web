const std = @import("std");
const Allocator = std.mem.Allocator;

const ptz = @import("ptz");
const sdk = ptz.Sdk(.en);

const database = @import("database.zig");
const util = @import("util.zig");

const Card = @This();

id: u64,
card_id: []const u8,
name: []const u8,
image_url: []const u8,
release_date: u64, // used to display cards chronologically

pub const Variant = struct {
    id: u64,
    card_id: []const u8,
    type: []const u8,
    subtype: ?[]const u8 = null,
    size: ?[]const u8 = null,
    stamps: ?[]const []const u8 = null,
    foil: ?[]const u8 = null,

    pub fn insert(session: *database.Session, variant: util.Omit(Variant, .id)) !void {
        _ = try session.insert(Variant, variant);
    }
};

pub fn insert(session: *database.Session, card: util.Omit(Card, .id)) !void {
    _ = session.insert(Card, card) catch |err| switch (err) {
        // card existed in DB already, lets not error out
        error.UniqueViolation => {},
        else => return err,
    };
}

pub fn list(allocator: Allocator, name: []const u8) ![]const Card {
    var session = try database.getSession(allocator);
    defer session.deinit();

    const wildcard = try std.fmt.allocPrint(allocator, "%{s}%", .{name});
    defer allocator.free(wildcard);

    return session
        .query(Card)
        .whereRaw("name like ?", .{wildcard})
        .orderBy(.release_date, .asc)
        .findAll();
}

const VariantsStats = struct {
    variants_count: usize,
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
fn fetchVariants(allocator: Allocator, session: *database.Session, brief: sdk.Card.Brief) !VariantsStats {
    const url, const free = if (brief.image) |image|
        .{ try std.fmt.allocPrint(allocator, "{f}", .{image}), true }
    else
        .{ "", false }; // TODO: 404.png or something?
    defer if (free) allocator.free(url);

    // ignore TCG Pocket cards
    if (std.mem.indexOf(u8, url, "tcgp")) |_| {
        return .{ .variants_count = 0 };
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

    try insert(session, .{
        .card_id = brief.id,
        .name = brief.name,
        .image_url = url,
        .release_date = try dateToNum(set.releaseDate),
    });

    // TODO: remove this, error out if variants aren't present
    const variants: []const ptz.VariantDetailed = switch (card) {
        inline else => |info| info.variant_detailed,
    } orelse return .{ .variants_count = 1 };

    for (variants) |variant| {
        try Card.Variant.insert(session, .{
            .card_id = brief.id,
            .type = variant.type,
            .subtype = variant.subtype,
            .size = variant.size,
            .stamps = variant.stamp,
            .foil = variant.foil,
        });
    }

    return .{ .variants_count = variants.len };
}

const FetchStats = struct {
    card_count: usize,
    ms_elapsed: usize,
};

/// fetch all cards whose name contains `name` into the local database
/// NOTE: db acts as a cache, to avoid using TCGDex's API all the time
pub fn fetch(allocator: Allocator, name: []const u8) !FetchStats {
    var timer: std.time.Timer = try .start();

    var session = try database.getSession(allocator);
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

            const res = try fetchVariants(allocator, &session, brief);
            n_cards += res.variants_count;
        }
    }

    return .{
        .card_count = n_cards,
        .ms_elapsed = timer.read() / 1_000_000, // ns to ms
    };
}
