defmodule PgEx.Types.Int2 do
  use PgEx.Types.Bin

  def encode(value) when is_integer(value) do
    case value >= -32768 && value <= 32767 do
      true -> <<value::signed-16>>
      false -> :error
    end
  end

  def encode(_), do: :error

  def decode(2, <<value::signed-16>>), do: value
  def decode(_, _), do: :error
end
