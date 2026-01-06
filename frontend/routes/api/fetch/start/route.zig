const zx = @import("zx");

const api = @import("api");
const backend = @import("backend");

const utils = @import("../../../../utils.zig");

pub fn POST(ctx: zx.RouteContext) !void {
    if (utils.api.getInput(api.fetch.start, ctx)) |input| {
        defer input.deinit();
        try utils.api.writeOutput(
            api.fetch.start,
            ctx,
            backend.fetch.run(ctx.allocator, input.value.name),
        );
    } else |err| {
        try utils.api.writeError(ctx, err);
    }
}
