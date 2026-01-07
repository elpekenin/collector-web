const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) void {
    wasm.api.handle(api.signin, ctx, backend.auth.signin);
}
