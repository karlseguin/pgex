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
end
