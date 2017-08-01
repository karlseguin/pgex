defmodule PgEx.Types.Int8 do
  use PgEx.Types.Bin

  def name(), do: "int4"

  def encode(value) do
    case value >= -9223372036854775808 && value <= 9223372036854775807 do
      true -> <<value::signed-64>>
      false -> :error
    end
  end

  def decode(8, <<value::signed-64>>), do: value
  def decode(_, _), do: :error
end
