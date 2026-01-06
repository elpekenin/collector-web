const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (wasm.api.getInput(api.login, ctx)) |input| {
        defer input.deinit();
        try wasm.api.writeOutput(
            api.login,
            ctx,
            backend.auth.login(
                ctx.arena,
                input.value.username,
                input.value.password,
            ),
        );
    } else |err| {
        try wasm.api.writeError(ctx, err);
    }
}
