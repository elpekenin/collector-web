const std = @import("std");

const database = @import("database");

const ServerState = @This();

pool: *database.Pool,

pub fn init(allocator: std.mem.Allocator) !ServerState {
    return .{
        .pool = try database.createPool(allocator),
    };
}

pub fn deinit(self: *ServerState, allocator: std.mem.Allocator) void {
    self.pool.deinit();
    allocator.destroy(self.pool);
}
