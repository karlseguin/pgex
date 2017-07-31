defmodule PgEx.Connection do
  @moduledoc false

  use GenServer
  alias PgEx.Error
  alias PgEx.Connection.{Prepared, Startup}

  defstruct [
    :socket, :timeout, :types
  ]

  @type t :: %__MODULE__{
    socket: port,
    timeout: non_neg_integer,
    types: %{required(non_neg_integer) => module}
  }

  @type received :: {byte, binary} | {:error, Error.t}

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, [])
  end

  @spec init(keyword) :: {:ok, t} | {:error, Error.t}
  def init(config) do
    port = Keyword.get(config, :port, System.get_env("PGPORT") || 5432)
    host = Keyword.get(config, :host, System.get_env("PGHOST") || {127, 0, 0, 1})

    host = case is_binary(host) do
      true -> String.to_charlist(host)
      false -> host
    end

    timeout = Keyword.get(config, :connect_timeout, 5000)
    case :gen_tcp.connect(host, port, [:binary, active: false], timeout) do
      {:ok, socket} -> Startup.init(socket, config)
      err -> Error.build(err)
    end
  end

  # Executes an unammed prepared statement
  def handle_call({:query, sql, values}, _from, conn) do
    {r, conn} = case wait_for_ready(conn) do
      {:ok, conn} ->
        case do_query(conn, sql, values) do
          {:ok, result} -> {{:ok, result}, conn}
          err -> {handle_error(conn, err), conn}
        end
      err -> {err, conn}
    end
    {:reply, r, conn}
  end

  defp do_query(conn, sql, values) do
    with {:ok, prepared} <- Prepared.create(conn, "", sql),
         {:ok, conn} <- wait_for_ready(conn),
         {:ok, result} <- Prepared.bind_and_execute(conn, prepared, values)
    do
      {:ok, result}
    else
      err -> err
    end
  end

  @spec wait_for_ready(t) :: {:ok, t} | {:error, any}
  def wait_for_ready(conn) do
    case recv_message(conn) do
      {?Z, _} -> {:ok, conn}
      {?S, _} -> wait_for_ready(conn) #TODO
      {?K, _} -> wait_for_ready(conn) #TODO
      other -> handle_error(conn, other)
    end
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
    socket = conn.socket
    timeout = conn.timeout
    case recv_n(socket, 5, timeout) do
      {:ok, <<type, length::big-32>>} ->
        case length == 4 do
          true -> {type, nil}
          false ->
            case recv_n(socket, length - 4, timeout) do
              {:ok, message} -> {type, message}
              err -> err
            end
        end
      err -> err
    end
  end

  @spec recv_n(port, pos_integer, non_neg_integer) :: {:ok, iodata} | {:error, :inet.posix}
  defp recv_n(socket, n, timeout) do
    :gen_tcp.recv(socket, n, timeout)
  end

  @doc false
  @spec handle_error(t, any) :: {:error, Error.t}
  def handle_error(conn, error) do
    # TODO: many errors probably don't need to result in killing the connection
    :gen_tcp.close(conn.socket)
    Error.build(error)
  end

  @doc false
  @spec build_message(byte, binary) :: binary
  def build_message(type, payload) do
    <<type, (byte_size(payload)+4)::big-32, payload::binary>>
  end
end
