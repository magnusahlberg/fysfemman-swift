CREATE TABLE credentials (
    id bigserial PRIMARY KEY,
    user_id UUID references users(id),
    token UUID DEFAULT gen_random_uuid(),
    name varchar(128), 
    issued timestamptz DEFAULT current_timestamp,
    expires timestamptz DEFAULT current_timestamp + interval '1 month'
);
