defmodule PgEx.Result do
  @moduledoc """
  Represents the result of a query
  """

  defstruct [:rows, :columns, :affected]
  @type t :: %__MODULE__{
    rows: [any],
    columns: [String.t],
    affected: non_neg_integer | :truncate,
  }
end

# TODO: PgEx.Result should implement Enumerable (and Poison.Encoder ??)
