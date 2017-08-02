drop table if exists fuzz;

create unlogged table fuzz (
  id serial not null,
  bool bool,
  int2 int2,
  int4 int4,
  int8 int8,
  text text,
  float4 real,
  float8 double precision,
  uuid uuid
)
