const zx = @import("zx");
const Request = @FieldType(zx.PageContext, "request");
const Response = @FieldType(zx.PageContext, "response");

const cookie_name = "auth-token";

const Data = struct {
    username: []const u8,
    password: []const u8,
    referrer: []const u8,
};

pub fn data(request: Request) !Data {
    const form = try request.formData();

    return .{
        .username = form.get("username") orelse return error.MissingUsername,
        .password = form.get("password") orelse return error.MissingPasword,
        .referrer = form.get("referrer") orelse return error.MissingReferrer,
    };
}

pub fn getCookie(request: Request) ?[]const u8 {
    return request.cookies().get(cookie_name);
}

pub fn setCookie(response: Response, token: []const u8) !void {
    try response.setCookie(cookie_name, token, .{
        .max_age = 3600,
        .secure = true,
        .same_site = .strict,
    });
}

pub fn rmCookie(response: Response) !void {
    return response.setCookie(cookie_name, "", .{
        .max_age = 1,
    });
}
