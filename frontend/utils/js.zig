const std = @import("std");
const assert = std.debug.assert;

const zx = @import("zx");
const js = zx.Client.js;

const utils = @import("../utils.zig");

comptime {
    if (utils.inClient()) {
        @export(&onPromiseCompleted, .{
            .name = "onPromiseCompleted",
        });
    }
}

const Id = u32;
const RawObj = u64;

/// calls back to `onPromiseCompleted`, allowing access to awaited value
extern "collector-web" fn startAwaiting(promise_id: u32, out: *RawObj) void;

pub const AwaitHandler = fn (js.Object) anyerror!void;

const Callbacks = struct {
    onFulfill: *const AwaitHandler,
    onReject: *const AwaitHandler = printOnReject,
};

const Awaitable = struct {
    output: RawObj,
    callbacks: Callbacks,
};

var awaiting: std.AutoHashMap(Id, Awaitable) = .init(std.heap.wasm_allocator);

/// Write to console. Useful because there is no stdout
pub fn log(args: anytype) !void {
    const console: js.Object = try js.global.get(js.Object, "console");
    defer console.deinit();

    try console.call(void, "log", args);
}

fn printOnReject(object: js.Object) !void {
    try log(.{ js.string("error awaiting for Promise:"), object });
}

fn onPromiseCompleted(id: Id, success: bool) callconv(.{ .wasm_mvp = .{} }) void {
    const kv = awaiting.fetchRemove(id) orelse {
        log(.{js.string("onPromiseComplete received unknown id")}) catch {};
        return;
    };

    const awaitable = kv.value;

    const function = if (success)
        awaitable.callbacks.onFulfill
    else
        awaitable.callbacks.onReject;

    const object: js.Object = .{ .value = @enumFromInt(awaitable.output) };
    defer object.deinit();

    function(object) catch |err| {
        log(.{ js.string("await handler failed with:"), js.string(@errorName(err)) }) catch {};
    };
}

pub fn await(promise: js.Object, callbacks: Callbacks) !void {
    // copied from non-pub js.Value.ref()
    const ref: js.Ref = @bitCast(@intFromEnum(promise.value));
    const promise_id = ref.id;

    const result = try awaiting.getOrPut(promise_id);
    if (result.found_existing) return error.DuplicatedId; // should be unreachable
    result.value_ptr.* = .{
        .output = undefined,
        .callbacks = callbacks,
    };

    // call into JS, it will call us back upon completion
    startAwaiting(promise_id, &result.value_ptr.output);
}
