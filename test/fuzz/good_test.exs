# This fuzzer always expects good results
defmodule PgEx.Tests.Fuzz.Good do
  use PgEx.Tests.Base

  @columns [:int4, :uuid]

  test "fuzz the good" do
    for _ <- (1..100) do
      do_an_iteration()
    end
  end

  # TODO: Use a transaction if we ever get to to that
  defp do_an_iteration do
    rows = insert_rows()
    assert_rows(rows)
  end

  defp insert_rows() do
    assert PgEx.query!("truncate table fuzz", []).affected == :truncate  #TODO: use a named prepared statement here

    # number_of_rows = rand(10)
    number_of_rows = 1
    Enum.reduce((1..number_of_rows), %{}, fn id, rows ->
      Map.put(rows, id, insert_row(id))
    end)
  end

  defp insert_row(id) do
    r = Enum.reduce(@columns, {["id"], ["$1"], [id], 2}, fn column, {columns, placeholders, values, count} ->
      columns = [Atom.to_string(column) | columns]
      placeholders = ["$#{count}" | placeholders]

      value = case rand(2) == 1 do
        true -> nil
        false -> create_value(column)
      end
      values = [value | values]

      {columns, placeholders, values, count + 1}
    end)

    {columns, placeholders, values, _} = r

    sql = [
      "insert into fuzz (", Enum.join(columns, ","), ")
      values (", Enum.join(Enum.reverse(placeholders), ","), ")"
    ]
    assert PgEx.query!(sql, values).affected == 1
    Map.new(Enum.zip(columns, values))
  end

  defp create_value(:int4), do: rand(-2147483648, 2147483647)

  defp create_value(:uuid) do
    PgEx.Types.UUID.decode(16, :crypto.strong_rand_bytes(16))
  end

  defp assert_rows(rows) do
    for {id, row} <- rows do
      assert_row(id, row)
    end
    assert_nulls(rows)
  end

  defp assert_row(id, row) do
    row = Enum.filter(row, fn {_column, value} -> value end)
    for {column, value} <- row do
      {:ok, result} = PgEx.query("select id, #{column} from fuzz where #{column} = $1", [value])
      assert result.affected == 1

      [[actual_id, actual_value]] = result.rows
      assert actual_id == id
      assert actual_value == value
    end
  end

  # pick some random rows, select all null columns (could be none) and assert_nulls
  # that we get a null value back and that it really should be null
  defp assert_nulls(rows) do
    for column <- Enum.take_random(@columns, 1) do #TODO: make this larger when we have more columns
      {:ok, result} = PgEx.query("select id, #{column} from fuzz where #{column} is null", [])
      for [[id, value]] <- result.rows do
        assert value == nil
        row = Map.get(rows, id)
        refute Map.has_key?(row, column)
      end
    end

  end

end
