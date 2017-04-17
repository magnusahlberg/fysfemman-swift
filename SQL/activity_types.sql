DROP TABLE activity_types;

CREATE TABLE activity_types (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v1mc(),
    name        varchar(128),
    unit        varchar(32),
    multiplier  double precision
);
