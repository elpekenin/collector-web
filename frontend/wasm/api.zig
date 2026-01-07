const std = @import("std");
const assert = std.debug.assert;

const zx = @import("zx");
const js = zx.Client.js;

const wasm = @import("../wasm.zig");

fn zigToJs(allocator: std.mem.Allocator, zig: anytype) !js.Object {
    // allocate an empty JS object
    var object: js.Object = try js.global.call(js.Object, "Object", .{});

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

fn handleInner(
    comptime api: type,
    ctx: zx.RouteContext,
    handler: *const fn (std.mem.Allocator, api.Args) anyerror!api.Response,
) !void {
    const text = ctx.request.text() orelse return error.EmptyRequest;

    const args: std.json.Parsed(api.Args) = try std.json.parseFromSlice(api.Args, ctx.arena, text, .{});
    defer args.deinit();

    const response = try handler(ctx.arena, args.value);
    try ctx.response.json(response, .{});
}

pub fn handle(
    comptime api: type,
    ctx: zx.RouteContext,
    handler: *const fn (std.mem.Allocator, api.Args) anyerror!api.Response,
) void {
    handleInner(api, ctx, handler) catch |err| {
        ctx.response.setStatus(.internal_server_error);
        ctx.response.json(.{ .@"error" = @errorName(err) }, .{}) catch @panic(
            "could not send JSON error",
        );
    };
}

fn wrapHandler(comptime Response: type, func: *const fn (Response) anyerror!void) wasm.js.AwaitHandler {
    return struct {
        fn parseResponse(
            // result from `const response = await fetch(...)`
            response: js.Object,
        ) !void {
            const text: js.Object = try response.call(js.Object, "text", .{});
            defer text.deinit();

            try wasm.js.await(text, .{
                .onFulfill = parseText,
            });
        }

        fn parseText(
            // result from `const text = await response.text()`
            text: js.Object,
        ) !void {
            const slice: []const u8 = try text.value.string(wasm.allocator);
            defer wasm.allocator.free(slice);

            const json: std.json.Parsed(Response) = try std.json.parseFromSlice(Response, wasm.allocator, slice, .{});
            defer json.deinit();

            try func(json.value);
        }
    }.parseResponse;
}

/// Helper to call an API from client
pub fn execute(
    comptime api: type,
    allocator: std.mem.Allocator,
    url: []const u8,
    comptime successHandler: *const fn (api.Response) anyerror!void,
    args: api.Args,
) !void {
    if (zx.platform != .browser) return error.NotInBrowser;

    const JSON: js.Object = try js.global.get(js.Object, "JSON");
    defer JSON.deinit();

    const js_body = try zigToJs(allocator, args);
    defer js_body.deinit();

    const body_str: []const u8 = try JSON.callAlloc(
        js.String,
        allocator,
        "stringify",
        .{
            js_body,
        },
    );
    defer allocator.free(body_str);

    const options = try zigToJs(allocator, .{
        .method = @as([]const u8, "POST"),
        .body = body_str,
        .headers = .{
            .@"Content-Type" = @as([]const u8, "application/json"),
        },
    });
    defer options.deinit();

    const fetch: js.Object = try js.global.call(js.Object, "fetch", .{
        js.string(url),
        options,
    });
    defer fetch.deinit();

    try wasm.js.await(fetch, .{
        .onFulfill = wrapHandler(api.Response, successHandler),
    });
}
