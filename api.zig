// proxy values to prevent depending on db/js modules

pub const database = struct {
    pub const Id = Int;
    pub const Int = i64;
};

pub const js = struct {
    pub const Ref = u64;
};

pub const Owned = struct {
    variant_id: database.Id,
    owned: bool,
    js_ref: js.Ref,
};

pub const Tracked = struct {
    pokedex: database.Int,
    tracked: bool,
    js_ref: js.Ref,
};
