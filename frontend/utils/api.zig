const std = @import("std");
const assert = std.debug.assert;

const zx = @import("zx");
const js = zx.Client.js;

const utils = @import("../utils.zig");

fn zigToJs(allocator: std.mem.Allocator, zig: anytype) !js.Object {
    // allocate an empty JS object
    var object: js.Object = try js.global.callAlloc(
        js.Object,
        allocator,
        "Object",
        .{},
    );

    inline for (std.meta.fields(@TypeOf(zig))) |field| {
        const T = field.type;
        const field_value: T = @field(zig, field.name);

        const value: js.Value = switch (T) {
            []const u8 => .init(js.string(field_value)),
            else => switch (@typeInfo(T)) {
                .@"struct" => (try zigToJs(allocator, field_value)).value,
                else => .init(field_value),
            },
        };

        try object.set(field.name, value);
    }

    return object;
}

// TODO: support nested structs
fn jsToZig(comptime T: type, allocator: std.mem.Allocator, object: js.Object) !T {
    var zig: T = undefined;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        const value = switch (field.type) {
            []const u8 => try object.getAlloc(js.String, allocator, field.name),
            bool => @compileError("dont use booleans"),
            else => |F| try object.get(F, field.name),
        };

        @field(zig, field.name) = value;
    }

    return zig;
}

/// Helper to parse input to an API (server)
pub fn getInput(comptime api: type, ctx: zx.RouteContext) !std.json.Parsed(api.Input) {
    const text = ctx.request.text() orelse return error.EmptyRequest;
    return std.json.parseFromSlice(api.Input, ctx.arena, text, .{});
}

/// Helper to write an error (server)
pub fn writeError(ctx: zx.RouteContext, err: anyerror) !void {
    const writer = ctx.response.writer() orelse return error.CantSendJson;

    ctx.response.setStatus(.internal_server_error);
    ctx.response.setContentType(.@"application/json");

    const fmt = std.json.fmt(
        .{
            .@"error" = @errorName(err),
        },
        .{},
    );
    try fmt.format(writer);
}

/// Helper to write the output for an API request (server)
pub fn writeOutput(comptime api: type, ctx: zx.RouteContext, value: anyerror!api.Output) !void {
    const writer = ctx.response.writer() orelse return error.CantSendJson;

    const success = value catch |err| return writeError(ctx, err);

    ctx.response.setStatus(.ok);
    ctx.response.setContentType(.@"application/json");

    const fmt = std.json.fmt(success, .{});
    try fmt.format(writer);
}

fn wrapHandler(comptime Output: type, func: *const fn (Output) anyerror!void) utils.js.AwaitHandler {
    const allocator = std.heap.wasm_allocator;

    return struct {
        fn parseResponse(
            // result from `const response = await fetch(...)`
            response: js.Object,
        ) !void {
            const text: js.Object = try response.callAlloc(js.Object, allocator, "text", .{});
            defer text.deinit();

            try utils.js.await(text, .{
                .onFulfill = parseText,
            });
        }

        fn parseText(
            // result from `const text = await response.text()`
            text: js.Object,
        ) !void {
            const JSON: js.Object = try js.global.get(js.Object, "JSON");
            defer JSON.deinit();

            const json: js.Object = try JSON.callAlloc(
                js.Object,
                allocator,
                "parse",
                .{
                    text,
                },
            );
            defer json.deinit();

            const output = try jsToZig(Output, allocator, json);
            try func(output);
        }
    }.parseResponse;
}

/// Helper to call an API from client
pub fn execute(
    comptime api: type,
    allocator: std.mem.Allocator,
    url: []const u8,
    comptime successHandler: *const fn (api.Output) anyerror!void,
    input: api.Input,
) !void {
    if (!utils.inClient()) return error.NotInBrowser;

    const JSON: js.Object = try js.global.get(js.Object, "JSON");
    defer JSON.deinit();

    const js_body = try zigToJs(allocator, input);
    defer js_body.deinit();

    const body_str: []const u8 = try JSON.callAlloc(
        js.String,
        allocator,
        "stringify",
        .{
            js_body,
        },
    );

    const options = try zigToJs(allocator, .{
        .method = @as([]const u8, "POST"),
        .body = body_str,
        .headers = .{
            .@"Content-Type" = @as([]const u8, "application/json"),
        },
    });
    defer options.deinit();

    const fetch: js.Object = try js.global.callAlloc(
        js.Object,
        allocator,
        "fetch",
        .{
            js.string(url),
            options,
        },
    );
    defer fetch.deinit();

    try utils.js.await(fetch, .{
        .onFulfill = wrapHandler(api.Output, successHandler),
    });
}
