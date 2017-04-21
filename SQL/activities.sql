CREATE TABLE activities (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v1mc(),
    user_id             UUID references users(id),
    date                date,
    rating              integer,
    activity_type       UUID references activity_types(id),
    units               double precision,
    bonus_multiplier    integer,
    points              double precision,
    registered_date     timestamptz DEFAULT current_timestamp
);
