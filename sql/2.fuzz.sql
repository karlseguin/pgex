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
  uuid uuid,

  bool_array bool[],
  int2_array int2[],
  int4_array int4[],
  int8_array int8[],
  text_array text[],
  float4_array real[],
  float8_array double precision[],
  uuid_array uuid[]
)
