const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const utils = @import("../../../utils.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (utils.api.getInput(api.logout, ctx)) |input| {
        defer input.deinit();
        try utils.api.writeOutput(
            api.logout,
            ctx,
            backend.auth.logout(ctx.arena, input.value.token),
        );
    } else |err| {
        try utils.api.writeError(ctx, err);
    }
}
