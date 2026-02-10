const std = @import("std");
const Allocator = std.mem.Allocator;

const fr = @import("fridge");

const database = @import("database.zig");

const Card = @This();

id: database.Id,
card_id: []const u8,
name: []const u8,
image_url: []const u8,
release_date: []const u8, // used to display cards chronologically
cardmarket_id: ?database.Int,

pub fn get(session: *database.Session, card_id: []const u8) !?Card {
    return database.findOne(Card, session, .{
        .card_id = card_id,
    });
}

pub const Variant = struct {
    id: database.Id,
    card_id: []const u8,
    type: Type,
    subtype: ?Subtype = null,
    size: ?Size = null,
    stamps: Stamps = .empty,
    foil: ?Foil = null,

    const Stamps = struct {
        items: []const Stamp,

        const separator: u8 = 255;

        pub fn init(items: []const Stamp) Stamps {
            return .{
                .items = items,
            };
        }

        pub const empty: Stamps = .init(&.{});

        pub fn toValue(self: Stamps, allocator: Allocator) !fr.Value {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();

            const writer = &aw.writer;

            for (self.items) |stamp| {
                try writer.print("{t}{c}", .{ stamp, separator });
            }

            return .{
                .blob = try aw.toOwnedSlice(),
            };
        }

        pub fn fromValue(value: fr.Value, allocator: Allocator) !Stamps {
            const blob = switch (value) {
                .blob => |blob| blob,
                else => return error.InvalidValueTag,
            };

            var stamps: std.ArrayList(Stamp) = .empty;
            defer stamps.deinit(allocator);

            var it = std.mem.splitScalar(u8, blob, separator);
            while (it.next()) |raw| {
                if (raw.len == 0) continue;

                const stamp = std.meta.stringToEnum(Stamp, raw) orelse return error.InvalidStampTag;
                try stamps.append(allocator, stamp);
            }

            return .{
                .items = try stamps.toOwnedSlice(allocator),
            };
        }
    };

    pub const Type = enum {
        unknown,

        normal,
        reverse,
        holo,
    };

    pub const Subtype = enum {
        unknown,

        unlimited,
        shadowless,
        @"1999-2000-copyright",
    };

    pub const Size = enum {
        unknown,

        standard,
        jumbo,
    };

    pub const Stamp = enum {
        unknown,

        staff,
        @"1st-edition",
        @"set-logo",
        @"city-championships",
        @"state-championships",
        @"regional-championships",
        @"national-championships",
        @"michael-pramawat",
        @"destiny-deoxys",
        @"pokemon-day",
        @"stadium-challenge",
    };

    pub const Foil = enum {
        unknown,

        energy,
        cosmos,
    };

    pub fn ownedBy(self: *const Variant, session: *database.Session, user_id: database.Id) !bool {
        const row = try database.findOne(Owned, session, .{
            .user_id = user_id,
            .variant_id = self.id,
        }) orelse return false;

        return row.owned;
    }

    pub const Owned = struct {
        id: database.Id,
        user_id: database.Id,
        variant_id: database.Id,
        owned: bool,
    };
};

pub fn variants(self: *const Card, session: *database.Session) ![]const Variant {
    return database.findAll(Variant, session, .{
        .card_id = self.card_id,
    });
}
