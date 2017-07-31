drop table if exists fuzz;

create unlogged table fuzz (
  id serial not null,
  int4 int4,
  uuid uuid
)
