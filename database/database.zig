const std = @import("std");
const Allocator = std.mem.Allocator;
const Field = std.builtin.Type.StructField;

const fr = @import("fridge");
pub const migrate = fr.migrate;
pub const Options = fr.SQLite3.Options;
pub const Pool = fr.Pool(fr.SQLite3);
pub const Session = fr.Session;

pub const Id = Int;
pub const Int = i64;

pub const Card = @import("Card.zig");
pub const Owned = @import("Owned.zig");
pub const Set = @import("Set.zig");
pub const Species = @import("Species.zig");
pub const Tracked = @import("Tracked.zig");
pub const User = @import("User.zig");
pub const Variant = @import("Variant.zig");

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

pub fn createPool(allocator: Allocator) !*Pool {
    const data_dir = try std.fs.getAppDataDir(allocator, "collector-web");
    defer allocator.free(data_dir);

    const options: Options = if (std.process.hasEnvVar(
        allocator,
        "__TESTING__",
    ) catch false)
        .{
            .filename = ":memory:",
        }
    else
        .{
            // NOTE: not freeing because it seems like sqlite doesn't dupe it
            .dir = data_dir,
            .filename = "db.sqlite3",
        };

    const pool = try allocator.create(Pool);
    errdefer allocator.destroy(pool);

    pool.* = try .init(allocator, .{ .max_count = 16 }, options);
    errdefer pool.deinit();

    var session = try pool.getSession(allocator);
    defer session.deinit();

    std.log.info("database at {?s}/{s}", .{ options.dir, options.filename });
    try migrate(&session, @embedFile("schema.sql"));

    return pool;
}

fn findOne(comptime T: type, session: *Session, filters: anytype) !?T {
    var query = session.query(T);

    const Filters = @TypeOf(filters);
    inline for (@typeInfo(Filters).@"struct".fields) |field| {
        const val = @field(filters, field.name);

        if (@typeInfo(field.type) == .optional and val == null) {
            query = query.whereRaw(field.name ++ " IS NULL", .{});
        } else {
            query = query.where(field.name, val);
        }
    }

    return query.findFirst();
}

pub const SaveResult = union(enum) {
    noop: Id,
    inserted: Id,
};

/// update or insert a value
pub fn save(comptime T: type, session: *Session, data: Omit(T, "id")) !SaveResult {
    const maybe_row = if (@hasField(T, "tcgdex_id"))
        try session
            .query(T)
            .findBy("tcgdex_id", data.tcgdex_id)
    else
        try findOne(T, session, data);

    if (maybe_row) |row| {
        return .{ .noop = row.id };
    }

    return .{
        .inserted = try session.insert(T, data),
    };
}
