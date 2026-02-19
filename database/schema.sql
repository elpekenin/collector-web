CREATE TABLE IF NOT EXISTS "User" (
    id INTEGER PRIMARY KEY NOT NULL,
    username TEXT NOT NULL UNIQUE,

    CHECK (username <> '')
) STRICT;

CREATE TABLE IF NOT EXISTS "Token" (
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL UNIQUE,
    value TEXT NOT NULL,

    FOREIGN KEY(user_id) REFERENCES User(id)
) STRICT;

CREATE TABLE IF NOT EXISTS "Secret" (
    id INTEGER PRIMARY KEY NOT NULL,
    salt TEXT NOT NULL,
    hashed_password TEXT NOT NULL,

    FOREIGN KEY(id) REFERENCES User(id)
) STRICT;

CREATE TABLE IF NOT EXISTS "Set_" (
    id INTEGER PRIMARY KEY NOT NULL,
    tcgdex_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    release_date TEXT NOT NULL,

    CHECK (tcgdex_id <> ''),
    CHECK (name <> ''),
    CHECK (release_date <> '')
) STRICT;

CREATE TABLE IF NOT EXISTS "Card" (
    id INTEGER PRIMARY KEY NOT NULL UNIQUE,
    tcgdex_id TEXT UNIQUE NOT NULL,
    set_id TEXT NOT NULL,
    name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    cardmarket_id INTEGER,
    dex_ids TEXT NOT NULL,

    FOREIGN KEY(set_id) REFERENCES Set_(tcgdex_id)
) STRICT;

CREATE TABLE IF NOT EXISTS "Variant" (
    id INTEGER PRIMARY KEY NOT NULL,
    card_id TEXT NOT NULL,
    type TEXT NOT NULL,
    subtype TEXT NOT NULL,
    size TEXT NOT NULL,
    stamps TEXT NOT NULL,
    foil TEXT NOT NULL,

    CHECK (type <> ''),
    CHECK (subtype <> ''),
    CHECK (size <> ''),
    CHECK (foil <> ''),

    FOREIGN KEY(card_id) REFERENCES Card(tcgdex_id),

    CONSTRAINT different UNIQUE (card_id, type, subtype, size, stamps, foil)
) STRICT;

CREATE TABLE IF NOT EXISTS "Owned" (
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    owned INTEGER NOT NULL,

    CHECK (owned == 0 OR owned == 1),

    FOREIGN KEY(user_id) REFERENCES User(id),
    FOREIGN KEY(variant_id) REFERENCES Variant(id),

    CONSTRAINT different UNIQUE (user_id, variant_id)
) STRICT;

CREATE TABLE IF NOT EXISTS "Species" (
    id INTEGER PRIMARY KEY NOT NULL,
    pokedex INTEGER UNIQUE NOT NULL,
    name TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS "Tracked" (
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL,
    species_dex INTEGER NOT NULL,
    tracked INTEGER NOT NULL,

    CHECK (tracked == 0 or tracked == 1),

    FOREIGN KEY(user_id) REFERENCES User(id),

    CONSTRAINT different UNIQUE (user_id, species_dex)
) STRICT;
