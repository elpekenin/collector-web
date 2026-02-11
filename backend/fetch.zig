//! Update local database with API data

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const graphqlz = @import("graphqlz");

const database = @import("database.zig");
const Omit = @import("meta.zig").Omit;
const Card = @import("Card.zig");
const Variant = Card.Variant;

const graphql = graphqlz.Client("http://localhost:3000/v3/graphql", @import("graphql-schema.zig"));

fn parseEnum(comptime T: type, str: []const u8) T {
    return std.meta.stringToEnum(T, str) orelse {
        std.log.warn("unknown value '{s}' for {}", .{ str, T });
        return .unknown;
    };
}

fn parseMaybeEnum(comptime T: type, str: ?[]const u8) ?T {
    return parseEnum(T, str orelse return null);
}

fn stampLessThan(_: void, lhs: Variant.Stamp, rhs: Variant.Stamp) bool {
    return @intFromEnum(lhs) < @intFromEnum(rhs);
}

fn handleVariant(
    allocator: Allocator,
    session: *database.Session,
    card_id: database.Id,
    variant: anytype,
) !database.Id {
    const stamps: []Variant.Stamp, const free_stamps = if (variant.stamp) |raw_stamps| blk: {
        const stamps = try allocator.alloc(Variant.Stamp, raw_stamps.len);

        for (raw_stamps, stamps) |str, *stamp| {
            stamp.* = parseEnum(Variant.Stamp, str);
        }

        std.mem.sort(Variant.Stamp, stamps, {}, stampLessThan);

        break :blk .{ stamps, true };
    } else .{ &.{}, false };
    defer if (free_stamps) allocator.free(stamps);

    return database.save(Card.Variant, session, .{
        .card_id = card_id,
        .type = parseEnum(Variant.Type, variant.type),
        .subtype = parseMaybeEnum(Variant.Subtype, variant.subtype),
        .size = parseMaybeEnum(Variant.Size, variant.size),
        .stamps = .init(stamps),
        .foil = parseMaybeEnum(Variant.Foil, variant.foil),
    });
}

fn handleCard(allocator: Allocator, session: *database.Session, card: anytype) !usize {
    var count: usize = 0;

    const image_url, const free_image_url = if (card.image) |url|
        .{ try std.fmt.allocPrint(allocator, "{s}/high.png", .{url}), true }
    else
        .{ "/card-back.png", false };
    defer if (free_image_url) allocator.free(image_url);

    const set_id = try database.save(Card.Set, session, .{
        .name = card.set.name,
        .release_date = card.set.releaseDate orelse "0000-00-00",
    });

    const cardmarket_id: ?database.Int = blk: {
        if (card.pricing) |pricing| {
            if (pricing.cardmarket) |cardmarket| {
                if (cardmarket.idProduct) |id| {
                    break :blk @intCast(id);
                }
            }
        }

        std.log.warn("missing cardmarket_id (card_id: {s})", .{card.id});
        break :blk null;
    };

    const card_id = try database.save(Card, session, .{
        .tcgdex_id = card.id,
        .set_id = set_id,
        .name = card.name,
        .image_url = image_url,
        .cardmarket_id = cardmarket_id,
    });

    count += 1;

    const variants = card.variants_detailed orelse return count;
    for (variants) |variant| {
        _ = try handleVariant(allocator, session, card_id, variant);
        count += 1;
    }

    return count;
}

pub fn run(allocator: Allocator, name: []const u8) !usize {
    var session = try database.getSession(allocator);
    defer session.deinit();

    // NOTE: sweet spot is somewhere 1900-1950, don't feel like digging exact value
    @setEvalBranchQuota(1950);

    const response = try graphql.query(
        "cards",
        allocator,
        .{
            .filters = .{
                .name = name,
            },
        },
        .{
            .id = true,
            .name = true,
            .image = true,
            .set = .{
                .logo = true,
                .name = true,
                .releaseDate = true,
            },
            .variants_detailed = .{
                .type = true,
                .subtype = true,
                .size = true,
                .stamp = true,
                .foil = true,
            },
            .pricing = .{
                .cardmarket = .{
                    .idProduct = true,
                },
            },
        },
    );
    defer response.deinit();

    const cards = try response.unwrap() orelse return error.NothingFound;

    var count: usize = 0;
    for (cards) |card| {
        // skip pocket cards
        if (card.set.logo) |logo| {
            if (std.mem.indexOf(u8, logo, "tcgp") != null) {
                continue;
            }
        }

        count += try handleCard(allocator, &session, card);
    }

    return count;
}
