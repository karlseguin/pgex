defmodule PgEx.Tests.Connection do
  use PgEx.Tests.Base

  test "error on missing parameter" do
    err = PgEx.query("select * from saiyans where id = $1", [])
    assert_error(err, "missing 1 or more parameter values")
  end

  test "error on too many parameter" do
    err = PgEx.query("select * from saiyans where id = $1", [1, 2])
    assert_error(err, "too many parameter values")
  end

  test "error on too many parameter when query expects none" do
    err = PgEx.query("select * from saiyans", ["hello"])
    assert_error(err, "too many parameter values")
  end

  test "error on parameter encoding problem" do
    err = PgEx.query("select * from saiyans where id = $1", ["hello"])
    assert_error(err, "failed to convert \"hello\" to int4")
  end

  test "select empty array" do
    result = PgEx.query!("select '{}'::bool[], '{}'::int4[], '{}'::float4[], '{}'::text[], '{}'::uuid[]", [])
    [[bools, ints, floats, texts, uuids]] = result.rows  # TODO: Add a PgEx.row!
    assert bools == []
    assert ints == []
    assert floats == []
    assert texts == []
    assert uuids == []
  end

  test "select single-dimension array" do
    result = PgEx.query!("select '{true, false}'::bool[], '{1, -3, 99}'::int4[], '{32.55, 0.1}'::float4[], '{\"over\", \"9000!\"}'::text[], '{\"8e632b23-b469-4b15-a433-8ff29719c856\", \"ffadfd13-f52b-4dd3-a129-bd02fb328298\"}'::uuid[]", [])
    [[bools, ints, floats, texts, uuids]] = result.rows  # TODO: Add a PgEx.row!
    assert bools == [true, false]
    assert ints == [1, -3, 99]
    assert floats == [32.54999923706055, 0.10000000149011612] #...
    assert texts == ["over", "9000!"]
    assert uuids == ["8e632b23-b469-4b15-a433-8ff29719c856", "ffadfd13-f52b-4dd3-a129-bd02fb328298"]
  end

  test "select single-dimension array with 1 value" do
    result = PgEx.query!("select '{false}'::bool[], '{32381}'::int4[], '{-4491.22}'::float4[], '{\"spice\"}'::text[], '{\"498ceaea-ed3d-47f2-9d1a-0bdc2c0f0f7a\"}'::uuid[]", [])
    [[bools, ints, floats, texts, uuids]] = result.rows  # TODO: Add a PgEx.row!
    assert bools == [false]
    assert ints == [32381]
    assert floats == [-4491.22021484375] #...
    assert texts == ["spice"]
    assert uuids == ["498ceaea-ed3d-47f2-9d1a-0bdc2c0f0f7a"]
  end

  test "select multi-dimensional arrays" do
    result = PgEx.query!("select '{{false}, {true}}'::bool[], '{{-1, 0}, {2, 3}}'::int4[], '{{{{0}, {0.1}}}}'::float4[], '{{\"a\", \"b\", \"c\"}, {\"\", \"ē\",\"?\"}, {\"!\", \"''\", null}}'::text[]", [])
    [[bools, ints, floats, texts]] = result.rows  # TODO: Add a PgEx.row!
    assert bools == [[false], [true]]
    assert ints == [[-1, 0] ,[2, 3]]
    assert floats == [[[[0.0], [0.10000000149011612]]]]
    assert texts == [["a", "b", "c"], ["", "ē", "?"], ["!", "'", nil]]
  end
end
