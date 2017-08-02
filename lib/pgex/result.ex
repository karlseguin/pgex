defmodule PgEx.Result do
  @moduledoc """
  Represents the result of a query
  """

  defstruct [:it, :rows,  :columns,  :affected]

  @typedoc """
  The enumerable result returned by a query.
  """
  @type t :: %__MODULE__{
    it: [any],
    rows: [any],
    columns: [String.t],
    affected: non_neg_integer | :truncate,
  }

  @doc false
  @spec create_row(t, [any]) :: map
  def create_row(result, columns) do
    Map.new(Enum.zip(result.columns, columns))
  end
end

defimpl Enumerable, for: PgEx.Result do
  alias PgEx.Result
  def count(result), do: {:ok, result.affected}
  def member?(_result, _value), do: {:error, __MODULE__}

  def reduce(_result, {:halt, acc}, _f), do: {:halted, acc}
  def reduce(result, {:suspend, acc}, f), do: {:suspended, acc, &reduce(result, &1, f)}
  def reduce(%{it: []}, {:cont, acc}, _f), do: {:done, acc}
  def reduce(result, {:cont, acc}, f) do
    [columns | rows] = result.it
    result = %Result{result | it: rows}
    row = Result.create_row(result, columns)
    reduce(result, f.(row, acc), f)
  end
end
