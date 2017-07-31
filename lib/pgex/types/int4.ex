defmodule PgEx.Types.Int4 do
  use PgEx.Types.Bin

  def name(), do: "int4"

  def encode(value) do
    case value >= -2147483648 && value <= 2147483647 do
      true -> <<value::signed-32>>
      false -> :error
    end
  end

  def decode(4, <<value::signed-32>>), do: value
  def decode(_, _), do: :error
end
