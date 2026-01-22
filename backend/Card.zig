const std = @import("std");
const Allocator = std.mem.Allocator;

const database = @import("database.zig");

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

    pub const Owned = struct {
        id: u64,
        user_id: u64,
        variant_id: u64,
        owned: bool,

        pub fn by(allocator: Allocator, user_id: u64) ![]const Owned {
            var session = try database.getSession(allocator);
            defer session.deinit();

            return session
                .query(Owned)
                .where("user_id", user_id)
                .findAll();
        }
    };
};

pub fn all(allocator: Allocator, name: []const u8) ![]const Card {
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

pub fn variants(self: *const Card, allocator: Allocator) ![]const Variant {
    var session = try database.getSession(allocator);
    defer session.deinit();

    return session
        .query(Variant)
        .where("card_id", self.card_id)
        .findAll();
}
