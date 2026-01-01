const zx = @import("zx");
const Response = @FieldType(zx.PageContext, "response");

pub const auth = @import("utils/auth.zig");
pub const html = @import("utils/html.zig");

// FIXME: doesn't really work yet
pub fn redirectTo(response: Response, url: []const u8) void {
    response.setStatus(.see_other);
    response.header("Location", url);
}
