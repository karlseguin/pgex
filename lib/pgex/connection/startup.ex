# Encapsulates the logic needed to bring a connection online. This currently
# involves authentication and loading type information. This code logically
# belongs in PgEx.Connection, but I'm thinking it might make things more
# manageable to split it up.
defmodule PgEx.Connection.Startup do
  @moduledoc false
  alias PgEx.Connection

  # TODO: load from .pgpass

  @spec init(Conn.t) :: {:ok, Connection.t} | {:error, any}
  def init(conn) do
    config = conn.config
    port = Keyword.get(config, :port)
    host = Keyword.get(config, :host)
    username = Keyword.get(config, :username)
    database = Keyword.get(config, :database)
    timeout = Keyword.get(config, :connect_timeout, 5000)

    case :gen_tcp.connect(host, port, [:binary, active: false], timeout) do
      {:error, err} -> {:error, err}
      {:ok, socket} ->
        conn = %Connection{conn | socket: socket}
        payload = <<0, 3, 0, 0, "user", 0, username::binary, 0, "database", 0, database::binary, 0, 0>>
        with :ok <- :gen_tcp.send(socket, <<(byte_size(payload)+4)::big-32, payload::binary>>),
             :ok <- authenticate(socket, Connection.recv_message(conn), config),
             {:ok, conn} <- load_types(conn)
        do
          {:ok, conn}
        else
          err ->
            :gen_tcp.close(socket)
            err
        end
    end
  end

  @spec authenticate(Connection.t, Connection.received, keyword) :: :ok | {:error, any}
  # authenticated
  defp authenticate(_conn, {?R, <<0, 0, 0, 0>>}, _config), do: :ok

  defp authenticate(conn, {?R, <<0, 0, 0, 3>>}, config) do
    send_password(conn, Keyword.get(config, :password, ""))
  end

  defp authenticate(conn, {?R, <<0, 0, 0, 5, salt::binary>>}, config) do
    hash = :crypto.hash(:md5, Keyword.get(config, :password, "") <> Keyword.get(config, :username))
    hash = :crypto.hash(:md5, Base.encode64(hash, case: :lower) <> salt)
    send_password(conn, Base.encode16(hash, case: :lower))
  end

  defp authenticate(_conn, {?R, message}, _config) do
    {:error, "unsupported authentication type: #{inspect message}"}
  end

  defp authenticate(_conn, unexpected, _config), do: unexpected

  @spec send_password(Connection.t, String.t) :: :ok | {:error, any}
  defp send_password(conn, password) do
    message = Connection.build_message(?p, <<password::binary, 0>>)
    case Connection.send_recv_message(conn, message) do
      {?R, <<0, 0, 0, 0>>} -> :ok
      err -> err
    end
  end

  # TODO: more types
  # TODO: custom types
  @spec load_types(Connection.t) :: {:ok, Connection.t}
  defp load_types(conn) do
    alias PgEx.Types
    types = %{
      16 => Types.Bool,
      20 => Types.Int8,
      21 => Types.Int2,
      23 => Types.Int4,
      25 => Types.Text,
      700 => Types.Float4,
      701 => Types.Float8,
      2950 => Types.UUID,
    }
    {:ok, %Connection{conn | types: types}}
  end

end
