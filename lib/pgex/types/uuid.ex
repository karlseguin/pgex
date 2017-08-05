defmodule PgEx.Types.UUID do
  use PgEx.Types.Bin
  import Bitwise, only: [bsl: 2, bor: 2]

  def encode(_type, <<value::bytes-size(16)>>), do: value
  def encode(_type, <<a1, a2, a3, a4, a5, a6, a7, a8, ?-, b1, b2, b3, b4, ?-, c1, c2, c3, c4, ?-, d1, d2, d3, d4, ?-, e1, e2, e3, e4, e5, e6, e7, e8, e9, eA, eB, eC>>) do
    try do
      <<
        encode_byte(a1, a2), encode_byte(a3, a4), encode_byte(a5, a6), encode_byte(a7, a8),
        encode_byte(b1, b2), encode_byte(b3, b4), encode_byte(c1, c2), encode_byte(c3, c4),
        encode_byte(d1, d2), encode_byte(d3, d4),
        encode_byte(e1, e2), encode_byte(e3, e4), encode_byte(e5, e6), encode_byte(e7, e8), encode_byte(e9, eA),encode_byte(eB, eC)
      >>
    catch
      _ -> :error
    end
  end
  def encode(_type, _wrong) do
    :error
  end

  def decode(16, <<b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, ba, bb, bc, bd, be, bf>>) do
    :erlang.iolist_to_binary([
      decode_byte(b0), decode_byte(b1), decode_byte(b2), decode_byte(b3), ?-,
      decode_byte(b4), decode_byte(b5), ?-,
      decode_byte(b6), decode_byte(b7), ?-,
      decode_byte(b8), decode_byte(b9), ?-,
      decode_byte(ba), decode_byte(bb), decode_byte(bc), decode_byte(bd), decode_byte(be), decode_byte(bf)
    ])
  end

  def decode(_, _value), do: :error

  for i <- (0..255) do
    hex = String.pad_leading(String.downcase(Integer.to_string(i, 16)), 2, <<?0>>)
    defp decode_byte(unquote(i)), do: unquote(hex)
  end

  @encode_lookup %{?0 => 0, ?1 => 1, ?2 => 2, ?3 => 3, ?4 => 4, ?5 => 5, ?6 => 6, ?7 => 7, ?8 => 8, ?9 => 9, ?A => 10, ?a => 10, ?B => 11, ?b => 11, ?C => 12, ?c => 12, ?D => 13, ?d => 13, ?E => 14, ?e => 14, ?F => 15, ?f =>15}
  for {ca, ba} <- @encode_lookup do
    for {cb, bb} <- @encode_lookup do
      value = bor(bsl(ba, 4), bb)
      defp encode_byte(unquote(ca), unquote(cb)), do: unquote(value)
    end
  end

  defp encode_byte(_, _) do
    throw :error
  end
end
