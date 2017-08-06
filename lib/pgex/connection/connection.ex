# Connections can exist but not be initialized. An uninitialized connection
# is one with a nil socket. This can happen if the original authentication fails,
# if the connection is closed, or on certain errors. We keep this connection in
# the pool and will attempt to re-establish it before any queries are run.
defmodule PgEx.Connection do
  @moduledoc false

  use GenServer
  require Logger
  alias PgEx.{Connection, Error}
  alias PgEx.Connection.{Query, Startup}

  defstruct [
     :config, :socket, :timeout, :types,
  ]

  @type t :: %__MODULE__{
    socket: port | nil,
    config: Keyword.t,
    timeout: non_neg_integer,
    types: %{required(non_neg_integer) => {non_neg_integer, module}} |  nil,
  }

  @type received :: {byte, binary | nil} | {:error, :inet.posix}

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [])
  end

  @spec init(keyword) :: {:ok, t}
  def init(config) do
    port = Keyword.get(config, :port, System.get_env("PGPORT") || 5432)
    host = Keyword.get(config, :host, System.get_env("PGHOST") || {127, 0, 0, 1})
    username = Keyword.get(config, :username, System.get_env("PGUSER") || System.get_env("USER"))
    database = Keyword.get(config, :database, System.get_env("PGDATABASE") || username)

    host = case is_binary(host) do
      false -> host
      true -> String.to_charlist(host)
    end

    # re-store our varibles in th config so that we don't need to keep cheking against defaults
    config = Keyword.merge(config, [
      port: port,
      host: host,
      username: username,
      database: database,
    ])

    conn = %__MODULE__{
      config: config,
      timeout: Keyword.get(config, :timeout, 10_000),
    }

    conn = case Startup.init(conn) do
      {:ok, conn} -> conn
      {:error, err} ->
        Logger.error("failed to connect to #{inspect host}: #{inspect err}")
        conn
    end

    {:ok, conn}
  end

  # Executes an unammed prepared statement
  @spec handle_call({:query, iodata, [any]}, GenServer.from,  Connection.t) :: {:ok, Result.t} | {:error, Error.t}
  def handle_call({:query, sql, values}, _from, conn) do
    {status, {value, conn}} = do_query(ensure_initialized(conn), sql, values)
    {:reply, {status, value}, conn}
  end

  defp do_query({:ok, conn}, sql, values) do
    case do_query_ready(conn, sql, values) do
      {:ok, _} = ok -> ok
      err -> handle_query_error(conn, err)
    end
  end

  defp do_query({:error, _} = err, _sql, _values), do: err

  defp do_query_ready(conn, sql, values) do
    with {:ok, prepared} <- Query.create(conn, "", sql),
         {:ok, conn} <- wait_for_ready(conn),
         {:ok, result} <- Query.bind_and_execute(conn, prepared, values)
    do
      {:ok, {result, conn}}
    end
  end

  @spec ensure_initialized(t) :: {:ok, t} | {:error, any}
  defp ensure_initialized(%{socket: nil} = conn) do
    case Startup.init(conn) do
      {:ok, conn} -> ensure_initialized(conn)
      err -> {:error, {Error.build(err), conn}}
    end
  end

  defp ensure_initialized(conn) do
    case wait_for_ready(conn) do
      {:ok, _} = ok -> ok
      {:not_ready, err, conn} -> {:error, {Error.build(err), conn}}
    end
  end

  defp wait_for_ready(conn) do
    case recv_message(conn) do
      {?Z, _} -> {:ok, conn}
      {?S, _} -> wait_for_ready(conn) #TODO
      {?K, _} -> wait_for_ready(conn) #TODO
      err ->
        # Whatever happens here, it isn't good. So we'll un-initialize this
        # connection. (The best case is that something timed out, which coukld
        # be recoverable, but, for now at least, let's abandon all hope of
        # doing this query)
        :gen_tcp.close(conn.socket)
        {:not_ready, err, %Connection{conn | socket: nil}}
    end
  end

  defp handle_query_error(conn, err) do
    case err do
      {:not_ready, err, conn} -> {:error, {Error.build(err), conn}}  # already been closed/uninitialized
      err ->
        # TODO: are there errors we can recover from without uninitializing the
        # connection? Timeouts? (but then there might be junk on the socket next
        # time we try to use it...tricky). And, if we got a response we weren't
        # expecting, is our state really good enough to try and execute stuff?
        if conn.socket != nil do
          :gen_tcp.close(conn.socket)
        end
        {:error, {Error.build(err), %Connection{conn | socket: nil}}}
    end
  end

  @doc false
  @spec build_message(byte, binary) :: binary
  def build_message(type, payload) do
    <<type, (byte_size(payload)+4)::big-32, payload::binary>>
  end

  # Sends the message and waits for a response
  @spec send_recv_message(t, iodata) :: received
  def send_recv_message(conn, message) do
    case :gen_tcp.send(conn.socket, message) do
      :ok -> recv_message(conn)
      err -> err
    end
  end

  # Waits for a response from the server.
  # The first 5 bytes of any message from the server are {TYPE, LEGTH::big-32}
  # The length includes itself, so we need to then read LENGTH-4 more bytes.
  # Some messages don't have a message, so the length is 4 (4-4 == 0) in which
  # case we don't need to issue a second read.
  @spec recv_message(t) :: received
  def recv_message(conn) do
    case recv_n(conn.socket, 5, conn.timeout) do
      {:ok, <<type, length::big-32>>} -> read_message_body(conn, type, length - 4)
      err -> err
    end
  end

  @spec read_message_body(t, byte, non_neg_integer) :: received
  defp read_message_body(_conn, type, 0), do: {type, nil}

  defp read_message_body(conn, type, length) do
    case recv_n(conn.socket, length, conn.timeout) do
      {:ok, message} -> {type, message}
      err -> err
    end
  end

  @spec recv_n(port, pos_integer, non_neg_integer) :: {:ok, binary} | {:error, :inet.posix}
  defp recv_n(socket, n, timeout) do
    case :gen_tcp.recv(socket, n, timeout) do
      {:ok, data} -> {:ok, data}
      err -> err
    end
  end
end
