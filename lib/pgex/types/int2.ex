defmodule PgEx.Types.Int2 do
  use PgEx.Types.Bin

  def name(), do: "int2"

  def encode(value) do
    case value >= -32768 && value <= 32767 do
      true -> <<value::signed-16>>
      false -> :error
    end
  end

  def decode(2, <<value::signed-16>>), do: value
  def decode(_, _), do: :error
end
