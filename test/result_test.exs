defmodule PgEx.Tests.Result do
  use PgEx.Tests.Base

  test "result enumeration mini fuzz" do
    for i <- (1..10) do
      result = generate_result(i)
      assert_result(i, result)
    end
  end

  test "iterates a larger result" do
    result = generate_result(12345)
    assert_result(12345, result)
  end

  defp assert_result(i, result) do
    count = Enum.reduce(result, 1, fn row, id ->
      assert row["id"] == id
      assert row["text"] == "it's over #{id}"
      id + 1
    end)
    count = count - 1  # we started at 0s
    assert count == i
    assert count == Enum.count(result)
  end

  defp generate_result(rows) do
    PgEx.query!("select generate_series(1, $1) as id, 'it''s over ' || generate_series(1, $1)::text as text;", [rows])
  end
end
