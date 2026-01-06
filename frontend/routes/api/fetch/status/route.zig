const std = @import("std");

const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const wasm = @import("../../../../wasm.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (wasm.api.getInput(api.fetch.status, ctx)) |input| {
        defer input.deinit();
        try wasm.api.writeOutput(
            api.fetch.status,
            ctx,
            backend.fetch.status(input.value.id),
        );
    } else |err| {
        try wasm.api.writeError(ctx, err);
    }
}
