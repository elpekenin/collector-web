const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const utils = @import("../../../utils.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (utils.api.getInput(api.signin, ctx)) |input| {
        defer input.deinit();
        try utils.api.writeOutput(
            api.signin,
            ctx,
            backend.auth.signin(
                ctx.arena,
                input.value.username,
                input.value.password,
            ),
        );
    } else |err| {
        try utils.api.writeError(ctx, err);
    }
}
