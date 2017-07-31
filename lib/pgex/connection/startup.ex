# Encapsulates the logic needed to bring a connection online. This currently
# involves authentication and loading type information. This code logically
# belongs in PgEx.Connection, but I'm thinking it might make things more
# manageable to split it up.
defmodule PgEx.Connection.Startup do
  @moduledoc false
  alias PgEx.{Connection, Error}

  # TODO: load from .pgpass

  @spec init(port, keyword) :: {:ok, Connection.t} | {:error, Error.t}
  def init(socket, config) do
    timeout = Keyword.get(config, :timeout, 5000)
    username = Keyword.get(config, :username, System.get_env("PGUSER") || System.get_env("USER"))
    database = Keyword.get(config, :database, System.get_env("PGDATABASE") || username)

    # incase we used a default, for when we authenticate
    config = Keyword.put(config, :username, username)

    # Startup message is special, it has no type, so we can't use send_recv_message
    payload = <<0, 3, 0, 0, "user", 0, username::binary, 0, "database", 0, database::binary, 0, 0>>
    with :ok <- :gen_tcp.send(socket, <<(byte_size(payload)+4)::big-32, payload::binary>>),
         conn <- %Connection{socket: socket, timeout: timeout},
         :ok <- authenticate(conn, Connection.recv_message(conn), config),
         {:ok, conn} <- load_types(conn)
    do
      {:ok, conn}
    else
      {:error, %Error{}} = err -> err
      err -> Error.build(err)
    end
  end

  @spec authenticate(Connection.t, Connection.received, keyword) :: :ok | {:error, Error.t}
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

  defp authenticate(conn, {?R, message}, _config) do
    :gen_tcp.close(conn.socket)
    {:error, "unsupported authentication type: #{inspect message}"}
  end

  defp authenticate(conn, message, _config) do
    Connection.handle_error(conn, message)
  end

  @spec send_password(Connection.t, String.t) :: :ok | {:error, Error.t}
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
      23 => Types.Int4,
      2950 => Types.UUID,
    }
    {:ok, %{conn | types: types}}
  end

end
