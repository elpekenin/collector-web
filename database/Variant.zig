const std = @import("std");

const fr = @import("fridge");

const database = @import("database.zig");

const Variant = @This();

id: database.Id,
card_id: []const u8,
type: Type,
subtype: ?Subtype = null,
size: ?Size = null,
stamps: Stamps = .empty,
foil: ?Foil = null,

const Stamps = struct {
    const separator: u8 = '$';
    const empty_array: u8 = '%';

    items: []const Stamp,

    pub fn init(items: []const Stamp) Stamps {
        return .{
            .items = items,
        };
    }

    pub const empty: Stamps = .init(&.{});

    pub fn toValue(self: Stamps, allocator: std.mem.Allocator) !fr.Value {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();

        const writer = &aw.writer;

        if (self.items.len == 0) {
            try writer.print("{c}", .{empty_array});
        } else for (self.items) |stamp| {
            try writer.print("{t}{c}", .{ stamp, separator });
        }

        return .{
            .blob = try aw.toOwnedSlice(),
        };
    }

    pub fn fromValue(value: fr.Value, allocator: std.mem.Allocator) !Stamps {
        const blob = switch (value) {
            .blob => |blob| blob,
            else => return error.InvalidValueTag,
        };

        if (blob[0] == empty_array) {
            std.debug.assert(blob.len == 1);
            return .empty;
        }

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

    holo,
    lenticular,
    normal,
    reverse,
};

pub const Subtype = enum {
    unknown,

    @"1999-copyright",
    @"1999-2000-copyright",
    @"aoki-error",
    cosmos,
    @"d-ink-dot-error",
    @"energy-symbol-error",
    @"evolution-box-error",
    @"gold-border",
    @"japanese-back",
    @"missing-expansion-symbol",
    @"missing-hp",
    @"no-e-reader",
    @"no-holo-error",
    @"rarity-error",
    shadowless,
    @"shifted-energy-cost",
    @"text-error",
    unlimited,
};

pub const Size = enum {
    unknown,

    standard,
    jumbo,
};

pub const Stamp = enum {
    unknown,

    @"10th-anniversary",
    @"1st-edition",
    @"1st-edition-error",
    @"1st-edition-scratch-error",
    @"1st-movie",
    @"1st-movie-inverted",
    @"25th-celebration",
    @"akira-miyazaki",
    @"asia-promo",
    champion,
    @"chris-fulop",
    @"christopher-kan",
    @"city-championships",
    @"comic-con",
    @"countdown-calendar",
    @"curran-hill",
    @"d-edition-error",
    @"david-cohen",
    @"destiny-deoxys",
    @"distributor-meeting",
    @"dylan-lefavour",
    @"eb-games",
    finalist,
    @"games-expo",
    gamestop,
    @"gen-con",
    @"gustavo-wada",
    @"gym-challenge",
    @"hiroki-yano",
    horizons,
    @"igor-costa",
    @"illustration-contest-2024",
    @"international-championship-europe",
    @"international-championship-latin-america",
    @"international-championship-north-america",
    @"jason-klaczynski",
    @"jason-martinez",
    @"jeremy-maron",
    @"jeremy-scharff-kim",
    @"jimmy-ballard",
    judge,
    @"jun-hasebe",
    @"kevin-nguyen",
    @"kraze-club",
    @"master-ball-league",
    @"michael-gonzalez",
    @"michael-pramawat",
    @"miska-saari",
    @"mychael-bryan",
    @"national-championships",
    @"nintendo-world",
    origins,
    @"origins-2008",
    @"paul-atanassov",
    @"pikachu-tail",
    platinum,
    @"player-rewards-program",
    @"pokemon-4-ever",
    @"pokemon-center",
    @"pokemon-center-ny",
    @"pokemon-day",
    @"pokemon-rocks-america",
    @"pre-release",
    @"professor-program",
    @"quarter-finalist",
    @"reed-weichler",
    @"regional-championships",
    @"ross-cawthorn",
    @"semi-finalist",
    @"set-logo",
    @"shuto-itagaki",
    snowflake,
    @"stadium-challenge",
    staff,
    @"state-championships",
    @"stephen-silvestro",
    @"takashi-yoneda",
    @"tom-roos",
    @"top-eight",
    @"top-sixteen",
    @"top-thirty-two",
    @"trick-or-trade",
    @"tristan-robinson",
    @"tsubasa-nakamura",
    @"tsuguyoshi-yamato",
    @"ultra-ball-league",
    @"w-promo",
    winner,
    @"wizard-world-chicago",
    @"wizard-world-philadelphia",
    @"worlds-2007",
    @"worlds-2008",
    @"worlds-2009",
    @"worlds-2010",
    @"worlds-2025",
    wotc,
    @"yuka-furusawa",
    @"yuta-komatsuda",
    @"zachary-bokhari",
};

pub const Foil = enum {
    unknown,

    cosmos,
    @"cracked-ice",
    energy,
    galaxy,
    gold,
    league,
    mirror,
    @"player-reward",
    @"professor-program",
    starlight,
};

pub fn ownedBy(self: *const Variant, session: *database.Session, user_id: database.Id) !bool {
    const row = try session
        .query(database.Owned)
        .where("user_id", user_id)
        .where("variant_id", self.id)
        .findFirst() orelse return false;

    return row.owned;
}
