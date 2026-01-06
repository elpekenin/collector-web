const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (wasm.api.getInput(api.signin, ctx)) |input| {
        defer input.deinit();
        try wasm.api.writeOutput(
            api.signin,
            ctx,
            backend.auth.signin(
                ctx.arena,
                input.value.username,
                input.value.password,
            ),
        );
    } else |err| {
        try wasm.api.writeError(ctx, err);
    }
}
