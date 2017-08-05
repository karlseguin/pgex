defmodule PgEx.Types.GenericText do
  use PgEx.Types.Txt

  def encode(_type, value), do: to_string(value)
  def decode(_length, value), do: to_string(value)
end
