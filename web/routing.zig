const std = @import("std");

const zx = @import("zx");

pub fn isApi(route: []const u8) bool {
    return std.mem.startsWith(u8, route, "/api/");
}

pub const Environment = enum {
    unknown,
    development,
    deployed,
};

pub fn getEnvironment(request: zx.Request) Environment {
    const url = request.headers.get("host") orelse return .unknown;

    return if (std.mem.indexOf(u8, url, "localhost")) |_|
        .development
    else
        .deployed;
}
