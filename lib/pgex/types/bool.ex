defmodule PgEx.Types.Bool do
  use PgEx.Types.Bin

  def name(), do: "bool"

  def encode(value) do
    case value do
      true -> <<1>>
      false -> <<0>>
      _ -> :error
    end
  end

  def decode(1, <<value>>) do
    case value do
      0 -> false
      1 -> true
      _ -> :error
    end
  end
  def decode(_, _), do: :error
end
