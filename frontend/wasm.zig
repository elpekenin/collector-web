const std = @import("std");
const builtin = @import("builtin");

const zx = @import("zx");

pub const allocator = if (inClient())
    std.heap.wasm_allocator
else
    @compileError("must only use WASM code in WASM :P");

pub const api = @import("wasm/api.zig");
pub const html = @import("wasm/html.zig");
pub const js = @import("wasm/js.zig");
pub const routing = @import("wasm/routing.zig");

// NOTE: **must** to be inline to work correctly if there are arch-specific types and whatnot
/// use in codepaths like
/// ```zig
/// if (!inClient()) return;
/// clientOnlyCode();
/// ```
pub inline fn inClient() bool {
    return builtin.os.tag == .freestanding and builtin.cpu.arch.isWasm();
}
