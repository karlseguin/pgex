defmodule PgEx.Types.Text do
  use PgEx.Types.Bin

  def encode(value), do: :erlang.iolist_to_binary(value)
  def decode(_, value) when is_binary(value), do: value
  def decode(_, _), do: :error
end
