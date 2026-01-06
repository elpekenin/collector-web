const std = @import("std");

const zx = @import("zx");
const js = zx.Client.js;
pub fn getElementById(id: []const u8) ?js.Object {
    const document: js.Object = js.global.get(js.Object, "document") catch return null;

    return document.call(
        js.Object,
        "getElementById",
        .{
            js.string(id),
        },
    ) catch null;
}
