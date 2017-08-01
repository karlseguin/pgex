defmodule PgEx do
  alias PgEx.{Error, Result}

  def start_link(config) do
    {pool, config} = Keyword.pop(config, :pool, [])
    name = Keyword.get(config, :name, __MODULE__)

    opts = [
      name: {:local, name},
      worker_module: PgEx.Connection,
      size: Keyword.get(pool, :size, 5),
      strategy: Keyword.get(pool, :strategy, :fifo),
      max_overflow: Keyword.get(pool, :overflow, 10),
    ]

    children = [
      :poolboy.child_spec(name, opts, config),
    ]

    Supervisor.start_link(children, [strategy: :one_for_one])
  end

  @spec query(iodata, [any]) :: {:ok, Result.t} | {:error, Error.t}
  def query(sql, values), do: query(__MODULE__, sql, values)

  @spec query!(iodata, [any]) :: Result.t
  def query!(sql, values), do: query!(__MODULE__, sql, values)

  @spec query(atom, iodata, [any]) :: {:ok, Result.t} | {:error, Error.t}
  def query(conn, sql, values) do
    :poolboy.transaction(conn, fn pid ->
      GenServer.call(pid, {:query, sql, values})
    end)
  end

  @spec query!(atom, iodata, [any]) :: Result.t
  def query!(conn, sql, values) do
    case query(conn, sql, values) do
      {:ok, result} -> result
      {:error, err} -> throw err
    end
  end
end
