defmodule PgEx.Types.Float8 do
  use PgEx.Types.Bin

  def name(), do: "float8"

  def encode(value) when is_number(value), do: <<value::float-64>>
  def encode(value) do
    case value do
      :NaN -> <<0::1, 2047::11, 1::1, 0::51>>
      :inf -> <<0::1, 2047::11, 0::52>>
      :"-inf" -> <<1::1, 2047::11, 0::52>>
      _ -> :error
    end
  end

  def decode(8, value) do
    case value do
      <<0::1, 2047::11, 0::52>> -> :inf
      <<1::1, 2047::11, 0::52>> -> :"-inf"
      <<_::1, 2047::11, _::52>> -> :NaN
      <<float::float-64>> -> float
    end
  end
  def decode(_, _), do: :error
end
