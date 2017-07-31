defmodule PgEx.Parser do
  @moduledoc false

  # strings are null-terminated. Find the null, split the input, return the
  # string and whatever's left.
  def read_string(value) do
    {pos, 1} = :binary.match(value, <<0>>)
    {value, <<0, remainder::binary>>} = :erlang.split_binary(value, pos)
    {value, remainder}
  end

  def read_row([], <<>>, columns), do: Enum.reverse(columns)
  def read_row([_decoders], <<>>, _columns) do
    {:error, "more decoders tha result columns"}
  end
  def read_row([], <<_::binary>>, _columns) do
    {:error, "more data than available decoders"}
  end

  def read_row([_decoder | decoders], <<255, 255, 255, 255, row::binary>>, columns) do
    read_row(decoders, row, [nil | columns])
  end

  def read_row([decoder | decoders], <<length::big-32, row::binary>>, columns) do
    {value, row} = :erlang.split_binary(row, length)
    # TODO: Handle :error return. This is hard to test until we have custom types, so...
    column = decoder.decode(length, value)
    read_row(decoders, row, [column | columns])
  end
end
