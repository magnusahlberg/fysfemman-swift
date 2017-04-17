DROP TABLE users;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v1mc(),
    name varchar(128) NOT NULL,
    mobile varchar(32) NOT NULL,
    admin boolean DEFAULT false,
    datareader boolean DEFAULT false
);
