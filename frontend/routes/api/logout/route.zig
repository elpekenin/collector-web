const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (wasm.api.getInput(api.logout, ctx)) |input| {
        defer input.deinit();
        try wasm.api.writeOutput(
            api.logout,
            ctx,
            backend.auth.logout(ctx.arena, input.value.token),
        );
    } else |err| {
        try wasm.api.writeError(ctx, err);
    }
}
