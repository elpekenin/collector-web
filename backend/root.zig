//! Functions used on frontend to interact with database
//!
//! Note that leaking resources is not a big deal since most times we will be using an arena
//! As such, everything will be free'd when the response is sent by client
//!
//! Regardless, those leaks are still a bad thing, lets try and not make any :)

pub const User = @import("User.zig");
pub const database = @import("database.zig");
pub const fetch = @import("fetch.zig");
pub const Card = @import("Card.zig");
