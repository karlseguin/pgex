defmodule PgEx.Type do
  # just a friendly name used in error messages and such
  @callback name() :: binary

  @callback format() :: binary
  @callback encode(any) :: {:ok, iodata} | :error
  @callback decode(non_neg_integer, binary) :: {:ok, any} | :error

  def get_name(module) do
    module
      |> Module.split()
      |> List.last()
      |> String.downcase()
  end
end

defmodule PgEx.Types.Txt do
  defmacro __using__(_) do
    module = __CALLER__.module
    name = PgEx.Type.get_name(module)

    quote location: :keep  do
      @behaviour PgEx.Type
      def name, do: unquote(name)
      def format(), do: <<0, 0>>
    end
  end
end

defmodule PgEx.Types.Bin do
  defmacro __using__(_) do
    module = __CALLER__.module
    name = PgEx.Type.get_name(module)

    arr_name = name <> "[]"
    arr = Module.concat(module, Array)

    quote location: :keep  do
      @behaviour PgEx.Type
      def name(), do: unquote(name)
      def format(), do: <<0, 1>>

      # The binary format for arrays is:
      #   number_of_dimesions::big-32, are_there_null::big-32, oid_of_values::big-32
      #
      # Followed by the following 64 bits for each dimension:
      #   number_of_values::big-32, lower_bound::big-32
      #
      # Followed by the length-prefixed values:
      #  length1::big-32, value1::(length1), ... lengthN::big-32, valueN::(lengthN)
      #
      # The key to how we decode is to build an array of the number_of_values.
      # If we had {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}, {{9, 10}, {11, 12}}}
      # our sizes would be: [3, 2, 2]
      #
      # We build the structure recusively. Somethig like:
      #  3  -> {1, 2}, {3, 4}
      #    2 -> {1, 2}
      #      2 -> 1
      #      1 -> 2
      #    1 -> {3, 4}
      #      2 -> 3
      #      1 -> 4
      #
      #  2  -> {5, 6}, {7, 8}
      #    2 -> {5, 6}
      #      2 -> 5
      #      1 -> 6
      #    1 -> {7, 8}
      #      2 -> 7
      #      1 -> 8
      #
      #  1 -> {{9, 10}, {11, 12}}}
      #     ....
      #
      # I'm not sure if that helps.
      defmodule unquote(arr) do
        @moduledoc false
        def name(), do: unquote(arr_name) <> "[]"
        def format(), do: <<0, 1>>

        # an empty array
        def decode(12, <<0, 0, 0, 0, _::binary>>), do: []

        def decode(_length, <<dims::big-32, _null_and_type::64, data::binary>>) do
          header_size = dims * 8
          <<info::bytes-size(header_size), data::binary>> = data
          counts = extract_counts(info, [])
          {"", arr} = decode_dimensions(counts, data)
          arr
        end

        defp extract_counts(<<>>, counts), do: Enum.reverse(counts)
        defp extract_counts(<<count::big-32, _lower::big-32, info::binary>>, counts) do
          extract_counts(info, [count | counts])
        end

        defp decode_dimensions([count], data) do # the last dimension
          decode_array(count, data, [])
        end

        defp decode_dimensions([count | counts], data) do
          decode_dimension(count, counts, data, [])
        end

        defp decode_dimension(0, _counts, data, acc), do: {data, Enum.reverse(acc)}

        defp decode_dimension(count, counts, data, acc) do
          {data, dim} = decode_dimensions(counts, data)
          decode_dimension(count - 1, counts, data, [dim | acc])
        end

        defp decode_array(0, data, arr), do: {data, Enum.reverse(arr)}
        defp decode_array(count, <<255, 255, 255, 255, data::binary>>, arr) do
          decode_array(count - 1, data, [nil | arr])
        end
        defp decode_array(count, <<length::big-32, value::bytes-size(length), data::binary>>, arr) do
          arr = [unquote(module).decode(length, value) | arr]
          decode_array(count - 1, data, arr)
        end
      end
    end
  end
end
