const std = @import("std");

const zx = @import("zx");
const j = zx.Client.js;

comptime {
    // NOTE: not checking types' equality because Ref is a packed struct
    std.debug.assert(@sizeOf(j.Ref) == @sizeOf(@import("api").js.Ref));
}

const msg = "must only use WASM code in the browser";

pub const allocator = if (zx.platform == .browser)
    std.heap.wasm_allocator
else
    @compileError(msg);

pub const calling_convention: std.builtin.CallingConvention = if (zx.platform == .browser)
    .{ .wasm_mvp = .{} }
else
    @compileError(msg);

pub const html = @import("wasm/html.zig");
pub const js = @import("wasm/js.zig");

pub fn fetch(url: []const u8, onFetchComplete: *const js.AwaitHandler) !void {
    if (zx.platform != .browser) return error.NotInBrowser;

    const promise: j.Object = try j.global.call(
        j.Object,
        "fetch",
        .{
            j.string(url),
        },
    );
    defer promise.deinit();

    try js.await(promise, .{
        .onFulfill = onFetchComplete,
    });
}

pub fn text(response: j.Object, onComplete: *const js.AwaitHandler) !void {
    if (zx.platform != .browser) return error.NotInBrowser;

    const promise: j.Object = try response.call(
        j.Object,
        "text",
        .{},
    );
    defer promise.deinit();

    try js.await(promise, .{
        .onFulfill = onComplete,
    });
}
