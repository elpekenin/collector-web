const std = @import("std");
const Field = std.builtin.Type.StructField;

pub fn Omit(comptime T: type, comptime field_name: []const u8) type {
    const info = @typeInfo(T).@"struct";

    var copy = info;
    copy.decls = &.{};
    copy.fields = &.{};

    for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) continue;
        copy.fields = copy.fields ++ &[_]Field{field};
    }

    if (copy.fields.len == info.fields.len) {
        const msg = std.fmt.comptimePrint("{} has no field named {}", .{ T, field_name });
        @compileError(msg);
    }

    return @Type(.{ .@"struct" = copy });
}
