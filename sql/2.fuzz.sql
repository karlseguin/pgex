drop table if exists fuzz;

create unlogged table fuzz (
  id serial not null,
  bool bool,
  int2 int2,
  int4 int4,
  int8 int8,
  uuid uuid
)
