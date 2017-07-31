drop table if exists saiyans;

create unlogged table saiyans (
  id serial primary key,
  name text not null
);
