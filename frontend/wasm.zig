const std = @import("std");
const builtin = @import("builtin");

const zx = @import("zx");

pub const allocator = if (zx.platform == .browser)
    std.heap.wasm_allocator
else
    @compileError("must only use WASM code in WASM :P");

pub const calling_convention: std.builtin.CallingConvention = if (zx.platform == .browser)
    .{ .wasm_mvp = .{} }
else
    @compileError("must only use WASM code in WASM :P");

pub const api = @import("wasm/api.zig");
pub const html = @import("wasm/html.zig");
pub const js = @import("wasm/js.zig");
pub const routing = @import("wasm/routing.zig");
