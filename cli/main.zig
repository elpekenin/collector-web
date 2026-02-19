//! Functions used on frontend to interact with database
//!
//! Note that leaking resources is not a big deal since most times we will be using an arena
//! As such, everything will be free'd when the response is sent by client
//!
//! Regardless, those leaks are still a bad thing, lets try and not make any :)

const std = @import("std");
const Allocator = std.mem.Allocator;

const graphqlz = @import("graphqlz");

const database = @import("database");

const graphql = graphqlz.Client("https://tcgdex.elpekenin.dev/v3/graphql", @import("graphql-schema.zig"));

fn strToEnum(comptime T: type, str: ?[]const u8) T {
    return std.meta.stringToEnum(
        T,
        str orelse return .none,
    ) orelse return .unknown;
}

fn saveVariant(
    allocator: Allocator,
    session: *database.Session,
    card_tcgdex_id: []const u8,
    variant: anytype,
) !database.SaveResult {
    const stamps: database.Variant.Stamps = try .parse(allocator, variant.stamp orelse &.{});
    defer stamps.deinit(allocator);

    return database.save(database.Variant, session, .{
        .card_id = card_tcgdex_id,
        .type = strToEnum(database.Variant.Type, variant.type),
        .subtype = strToEnum(database.Variant.Subtype, variant.subtype),
        .size = strToEnum(database.Variant.Size, variant.size),
        .stamps = stamps,
        .foil = strToEnum(database.Variant.Foil, variant.foil),
    });
}

fn saveCard(allocator: Allocator, session: *database.Session, card: anytype) !usize {
    const image_url, const free_image_url = if (card.image) |url|
        .{ try std.fmt.allocPrint(allocator, "{s}/high.png", .{url}), true }
    else
        .{ "/card-back.png", false };
    defer if (free_image_url) allocator.free(image_url);

    _ = try database.save(database.Set, session, .{
        .tcgdex_id = card.set.id,
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

        break :blk null;
    };

    const card_result = try database.save(database.Card, session, .{
        .tcgdex_id = card.id,
        .set_id = card.set.id,
        .name = card.name,
        .image_url = image_url,
        .cardmarket_id = cardmarket_id,
        .dex_ids = .{ .items = card.dexId orelse &.{} },
    });

    const variants = card.variants_detailed orelse return switch (card_result) {
        .noop => 0,
        .inserted => 1,
    };

    var count: usize = 0;
    for (variants) |variant| {
        const variant_result = try saveVariant(allocator, session, card.id, variant);
        switch (variant_result) {
            .noop => {},
            .inserted => count += 1,
        }
    }

    return count;
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const pool = try database.createPool(allocator);
    defer {
        pool.deinit();
        allocator.destroy(pool);
    }

    var session = try pool.getSession(allocator);
    defer session.deinit();

    // NOTE: sweet spot is somewhere 1900-1950, don't feel like digging exact value
    @setEvalBranchQuota(1950);

    std.debug.print("API ...\n", .{});
    const response = try graphql.query(
        "cards",
        allocator,
        .{
            .filters = .{
                .category = "pokemon",
            },
        },
        .{
            .id = true,
            .dexId = true,
            .name = true,
            .image = true,
            .set = .{
                .id = true,
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

        count += try saveCard(allocator, &session, card);

        // if name is a single word (no spaces), store dexId-name mapping
        if (std.mem.count(u8, card.name, " ") == 0) {
            const dexIds = card.dexId orelse continue;
            std.debug.assert(dexIds.len == 1);

            const exists = try session
                .query(database.Species)
                .where("pokedex", @intCast(dexIds[0]))
                .exists();

            if (exists) continue;

            _ = try database.save(database.Species, &session, .{
                .pokedex = @intCast(dexIds[0]),
                .name = card.name,
            });
        }
    }

    std.log.info("found {} new variants", .{count});
}
