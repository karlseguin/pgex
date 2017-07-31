defmodule PgEx.Type do
  @callback name() :: binary
  @callback format() :: binary
  @callback encode(any) :: {:ok, iodata} | :error
  @callback decode(non_neg_integer, binary) :: {:ok, any} | :error
end

defmodule PgEx.Types.Txt do
  defmacro __using__(_) do
    quote location: :keep  do
      @behaviour PgEx.Type
      def format(), do: <<0, 0>>
    end
  end
end

defmodule PgEx.Types.Bin do
  defmacro __using__(_) do
    quote location: :keep  do
      @behaviour PgEx.Type
      def format(), do: <<0, 1>>
    end
  end
end
