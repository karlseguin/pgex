{:ok, _} = PgEx.start_link([
  port: 5432,
  host: "127.0.0.1",
  database: "pgex_test",
  pool: [size: 2, overflow: 2],
])

ExUnit.start(exclude: [:skip])
