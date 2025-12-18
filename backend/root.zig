const std = @import("std");

pub const sdk = @import("ptz").Sdk(.en);
const zmig = @import("zmig");

const database = @import("database.zig");

fn getConnection(allocator: std.mem.Allocator) !database.Connection {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const env = env_map.get("ZMIG_DB_PATH") orelse return error.MissingEnvVar;

    const path = try allocator.allocSentinel(u8, env.len, 0);
    defer allocator.free(path);

    @memcpy(path[0..env.len], env);

    var diagnostics: zmig.Diagnostics = undefined;
    return database.init(allocator, path, &diagnostics) catch {
        try std.debug.print("could not connect to database: {f}\n", .{diagnostics});
        return error.CouldNotOpenDb;
    };
}

pub fn getCards(allocator: std.mem.Allocator, params: sdk.Card.Brief.Params) ![]const sdk.Card {
    var cards: std.ArrayList(sdk.Card) = if (params.page_size) |page_size|
        try .initCapacity(allocator, page_size)
    else
        .empty;
    errdefer cards.clearAndFree(allocator);

    // crashes compiler :)
    // _ = try getConnection(allocator);

    var iterator = sdk.Card.all(allocator, params);

    const briefs = try iterator.next() orelse @panic("oops");
    for (briefs) |brief| {
        defer brief.deinit();

        const card: sdk.Card = try .get(allocator, .{ .id = brief.id });
        try cards.append(allocator, card);
    }

    return cards.toOwnedSlice(allocator);
}
