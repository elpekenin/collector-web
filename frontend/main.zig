const std = @import("std");
const assert = std.debug.assert;

const builtin = @import("builtin");

const zx = @import("zx");
const meta = @import("zx_meta").meta;

const wasm = @import("wasm.zig");

comptime {
    if (zx.platform == .browser) {
        @export(&mainClient, .{
            .name = "mainClient",
        });

        @export(&handleEvent, .{
            .name = "handleEvent",
        });
    }
}

pub const std_options: std.Options = .{
    .log_scope_levels = &.{
        .{
            .scope = .db_migrate,
            .level = .warn,
        },
        .{
            .scope = .fridge,
            .level = .warn,
        },
    },
};

const config: zx.App.Config = .{
    .server = .{},
    .meta = meta,
};

pub fn main() !void {
    if (builtin.os.tag == .freestanding) return;

    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const app: *zx.App = try .init(allocator, config);
    defer app.deinit();

    app.info();
    try app.start();
}

var client: zx.Client = .init(
    wasm.allocator,
    .{ .components = &@import("zx_components").components },
);

fn mainClient() callconv(wasm.calling_convention) void {
    client.info();
    client.renderAll();
}

fn handleEvent(velement_id: u64, event_type_id: u8, event_id: u64) callconv(wasm.calling_convention) void {
    if (builtin.os.tag != .freestanding) return;

    const event_type: zx.Client.EventType = @enumFromInt(event_type_id);
    const handled = client.dispatchEvent(velement_id, event_type, event_id);

    if (handled) {
        client.renderAll();
    }
}
