const std = @import("std");

const app = @import("app");
const database = @import("database");

pub fn owned(ctx: app.RouteCtx, is_owned: bool) !void {
    const variant_id_str = ctx.request.getParam("variant_id") orelse return error.MissingVariantId;
    const variant_id: database.Id = try std.fmt.parseInt(database.Id, variant_id_str, 10);

    var session = try ctx.app.pool.getSession(ctx.arena);
    defer session.deinit();

    const user = try ctx.state.getUser(&session) orelse return;

    const maybe_row = try session
        .query(database.Owned)
        .where("user_id", user.id)
        .where("variant_id", variant_id)
        .findFirst();

    if (maybe_row) |row| {
        try session.update(database.Owned, row.id, .{
            .owned = is_owned,
        });
    } else {
        _ = try session.insert(database.Owned, .{
            .user_id = user.id,
            .variant_id = variant_id,
            .owned = is_owned,
        });
    }
}

pub fn tracked(ctx: app.RouteCtx, is_tracked: bool) !void {
    const pokedex_str = ctx.request.getParam("species_dex") orelse return error.MissingDex;
    const pokedex: database.Int = try std.fmt.parseInt(database.Int, pokedex_str, 10);

    var session = try ctx.app.pool.getSession(ctx.arena);
    defer session.deinit();

    const user = try ctx.state.getUser(&session) orelse return;

    const maybe_row = try session
        .query(database.Tracked)
        .where("user_id", user.id)
        .where("species_dex", pokedex)
        .findFirst();

    if (maybe_row) |row| {
        try session.update(database.Tracked, row.id, .{
            .tracked = is_tracked,
        });
    } else {
        _ = try session.insert(database.Tracked, .{
            .user_id = user.id,
            .species_dex = pokedex,
            .tracked = is_tracked,
        });
    }
}
