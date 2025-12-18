CREATE TABLE IF NOT EXISTS user (
    id INTEGER PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,

    CHECK (name <> '')
) STRICT;

CREATE TABLE IF NOT EXISTS card (
    id INTEGER PRIMARY KEY NOT NULL,
    card_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    image_url TEXT,

    CHECK (name <> ''),
    CHECK (image_url IS NULL OR length(image_url) > 0)
) STRICT;

CREATE TABLE IF NOT EXISTS variant (
    id INTEGER PRIMARY KEY NOT NULL,
    card_id TEXT NOT NULL,
    type TEXT NOT NULL,
    subtype TEXT,
    size TEXT,
    stamp TEXT,
    foil TEXT,

    FOREIGN KEY(card_id) REFERENCES card(id),

    CHECK (length(type) > 0),
    CHECK (subtype IS NULL OR length(subtype) > 0),
    CHECK (size IS NULL OR length(size) > 0),
    CHECK (stamp IS NULL OR length(stamp) > 0),
    CHECK (foil IS NULL OR length(foil) > 0)
) STRICT;

CREATE TABLE IF NOT EXISTS owned (
    id INTEGER PRIMARY KEY NOT NULL,
    user_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    owned INTEGER NOT NULL,

    FOREIGN KEY(user_id) REFERENCES user(id),
    FOREIGN KEY(variant_id) REFERENCES variant(id),

    CHECK (owned == 0 OR owned == 1)
) STRICT;
