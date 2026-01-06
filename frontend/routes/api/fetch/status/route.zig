const std = @import("std");

const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const utils = @import("../../../../utils.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (utils.api.getInput(api.fetch.status, ctx)) |input| {
        defer input.deinit();
        try utils.api.writeOutput(
            api.fetch.status,
            ctx,
            backend.fetch.status(input.value.id),
        );
    } else |err| {
        try utils.api.writeError(ctx, err);
    }
}
