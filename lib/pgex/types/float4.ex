defmodule PgEx.Types.Float4 do
  use PgEx.Types.Bin

  def encode(_type, value) when is_number(value), do: <<value::float-32>>
  def encode(_type, value) do
    case value do
      :NaN -> <<0::1, 255, 1::1, 0::22>>
      :inf -> <<0::1, 255, 0::23>>
      :"-inf" -> <<1::1, 255, 0::23>>
      _ -> :error
    end
  end

  def decode(4, value) do
    case value do
      <<0::1, 255, 0::23>> -> :inf
      <<1::1, 255, 0::23>> -> :"-inf"
      <<_::1, 255, _::23>> -> :NaN
      <<float::float-32>>   -> float
    end
  end
  def decode(_, _), do: :error
end
