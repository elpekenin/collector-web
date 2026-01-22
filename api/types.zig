//! Payloads sent both ways for HTTP APIs
//!
//! This module is used by both backend and frontend to keep them sync

pub const signin = struct {
    pub const Args = struct {
        username: []const u8,
        password: []const u8,
        referrer: []const u8,
    };

    pub const Response = struct {
        username: []const u8,
        token: []const u8,
    };
};

pub const login = signin;

pub const logout = struct {
    pub const Args = struct {
        token: []const u8,
    };

    pub const Response = struct {
        // FIXME: replace with bool after https://github.com/mitchellh/zig-js/pull/5
        ok: u1,
    };
};
