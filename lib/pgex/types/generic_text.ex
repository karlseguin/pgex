defmodule PgEx.Types.GenericText do
  use PgEx.Types.Txt
  def name(), do: "generic"
  def encode(value), do: to_string(value)
  def decode(_length, value), do: to_string(value)
end
