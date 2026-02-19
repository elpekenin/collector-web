const zx = @import("zx");
const js = zx.Client.js;

const wasm = @import("../wasm.zig");

/// Helper to call an API from client
pub fn execute(url: []const u8, onFetchComplete: *const fn (js.Object) anyerror!void) !void {
    if (zx.platform != .browser) return error.NotInBrowser;

    const fetch: js.Object = try js.global.call(js.Object, "fetch", .{
        js.string(url),
    });
    defer fetch.deinit();

    try wasm.js.await(fetch, .{
        .onFulfill = onFetchComplete,
    });
}
