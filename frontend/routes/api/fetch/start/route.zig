const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (wasm.api.getInput(api.fetch.start, ctx)) |input| {
        defer input.deinit();
        try wasm.api.writeOutput(
            api.fetch.start,
            ctx,
            backend.fetch.run(ctx.allocator, input.value.name),
        );
    } else |err| {
        try wasm.api.writeError(ctx, err);
    }
}
