# Contains everything needed to execute named or unnamed prepared statements
# (which is really any query we send to the server).
#
# All of this could be stuffed into the PgEx.Connection module, but I'm hoping
# that splitting them up will help make it more manageable.
#
# Prepared statements involve two steps. First, preparing the statemenet and
# then binding the values + execution. For named prepared statements, these steps
# will be distinctly executed by the application (not supported yet, TODO). For
# unnamed, they're executed together. Regardless of the mode, it's almost the
# exact same code.
#
# Becausing binding+execution might happen more than once, we do as much work
# a we can in the first stage. For example, a large part of the Bind message
# can be constructed in the first stage. Doing it here means slightly uglier
# structures, but better performance when executing a statement multiple times.
defmodule PgEx.Connection.Prepared do
  @moduledoc false

  alias __MODULE__, as: Prepared
  alias PgEx.{Connection, Parser}

  defstruct [
    # A list of the column names we're going to get as part of the result
    :columns,

    # A list of the modules we need to decode the returned rows. In other words,
    # decoders[0].decode() used to decode the value of a row for columns[0]
    :decoders,

    # A list of te modules we need to encode parameters. $1 will be encoded by
    # encoder[0].encode(...)
    :encoders,

    # The first handful of bytes we need to send each time we bind the prepared
    # statement are known after we prepare the statement. No point building it
    # each time.
    :bind_prefix,

    # the last few bytes we need to send each time we bind the prepared
    # statement are known after we prepare the statement. No point building it
    # each time.
    :bind_suffix,
  ]

  @type t :: %Prepared{
    columns: [],
    decoders: [module],
    encoders: [module],
    bind_prefix: binary,
    bind_suffix: binary,
  }

  # Creates a Prepare.t (or returns an error). This involves sending the Prepare
  # message to the databsase, and reading the next two messages to figure
  # out what decoders we'll need for the result and what encoders we'll need to
  # encode the parameters.
  @spec create(Connetion.t, atom | binary, iodata) :: {:ok, t} | {:error, any}
  def create(conn, name, sql) do
    sql = :erlang.iolist_to_binary(sql)

    sname = case is_atom(name) do
      true -> Atom.to_string(name)
      false -> name
    end

    parse_describe_sync = [
      Connection.build_message(?P, <<sname::binary,  0, sql::binary, 0, 0, 0>>),
      Connection.build_message(?D, <<?S, 0>>),
      <<?S, 0, 0, 0, 4>>
    ]

    with {?1, nil} <- Connection.send_recv_message(conn, parse_describe_sync),
         {?t, parameters} <- Connection.recv_message(conn),
         {type, columns} when type in [?T, ?n] <- Connection.recv_message(conn),
         prepared <- %__MODULE__{},
         {:ok, prepared} <- extract_column_info(conn, prepared, columns),
         {:ok, prepared} <- extract_parameter_info(conn, prepared, sname, parameters)
    do
      {:ok, prepared}
    end
  end

  # When we eventually send the Bind request, we'll include how each column of
  # the result should be formatted (text or binary). We can build this part
  # of the message right here (how excitting!) because we're told the type of
  # each column. While we're at it, we might as well remember all those column
  # names and all of the modules we'll need to decode the actual information.
  @spec extract_column_info(Connection.t, t, binary | nil) :: {:ok, Prepared.t} | {:error, any}

  # For a statement that returns no data, we get a NoData message from the
  # server and the message is nil.
  defp extract_column_info(_conn, prepared, nil) do
    {:ok, %Prepared{prepared | columns: [], decoders: [], bind_suffix: <<0, 0>>}}
  end

  defp extract_column_info(conn, prepared, <<count::big-16, data::binary>>) do
    case do_extract_column_info(conn.types, data, [], [], <<>>) do
      {:ok, columns, decoders, formats} ->
        suffix = <<count::big-16, formats::binary>>
        {:ok, %Prepared{prepared | columns: columns, decoders: decoders, bind_suffix: suffix}}
      err -> err
    end
  end

  @spec do_extract_column_info(map, binary, [String.t], [module], binary) :: {:ok, [String.t], [module], binary}
  defp do_extract_column_info(_types, <<>>, columns, decoders, formats) do
    {:ok, Enum.reverse(columns), Enum.reverse(decoders), formats}
  end

  defp do_extract_column_info(types, data, columns, decoders, formats) do
    {name, <<_t::big-32, _c::big-16, type::big-32, _z::big-64, rest::binary>>} = Parser.read_string(data)
    decoder = Map.get(types, type, PgEx.Types.GenericText)

    columns = [name | columns]
    decoders = [decoder | decoders]
    formats = <<formats::binary, decoder.format()::binary>>
    do_extract_column_info(types, rest, columns, decoders, formats)
  end

  # When we eventually send the Bind request, we'll include the format (text or
  # binary) that we plan to send each parameter in as well as the actual number
  # of parameters.  We can build that part of the message here. In fact, we can
  # build the entire prefix, including the portal name (always empty for now!)
  # and the stored procedure name. We can also remmeber the actual modules we'll
  # need to encode those pesky parameters.
  @spec extract_parameter_info(map, binary, [module], binary) :: {:ok, t} | {:error, any}
  defp extract_parameter_info(conn, prepared, sname, <<count::big-16, data::binary>>) do
    {encoders, formats} = do_extract_parameter_info(conn.types, data, [], <<>>)
    prefix = <<0, sname::binary, 0, count::big-16, formats::binary, count::big-16>>
    {:ok, %Prepared{prepared | encoders: encoders, bind_prefix: prefix}}
  end

  @spec do_extract_parameter_info(map, binary, [module], binary) :: {[module], binary}
  defp do_extract_parameter_info(_types, <<>>, encoders, formats) do
    {Enum.reverse(encoders), formats}
  end

  defp do_extract_parameter_info(types, <<type::big-32, rest::binary>>, encoders, formats) do
    encoder = Map.get(types, type, PgEx.Types.GenericText)
    encoders = [encoder | encoders]
    formats = <<formats::binary, encoder.format()::binary>>
    do_extract_parameter_info(types, rest, encoders, formats)
  end

  # Sends a Bind request followed by an Execute request and reads the resulting
  # rows.
  @spec bind_and_execute(Connection.t, t, [any]) :: {:ok, Result.t} | {:error, any}
  def bind_and_execute(conn, prepared, values) do
    with {:ok, length, data} <- bind_values(prepared.encoders, values, 0, []),
         payload <- build_bind_and_execute_payload(prepared, length, data),
         :ok <- :gen_tcp.send(conn.socket, payload),
         {?2, _bind} <- Connection.recv_message(conn)
    do
      read_rows(conn, prepared, prepared.decoders, Connection.recv_message(conn), [])
    end
  end

  # Encodes the parameters and builds up the request we'll send to Bind. We also
  # track the length of the build-up data (avoiding a call to :erlang.iolist_size)
  # which we'll need to build a proper request.
  @spec bind_values([module], [any], non_neg_integer, iolist) :: {:ok, non_neg_integer, iolist} | {:error, any}
  defp bind_values([], [], length, data), do: {:ok, length, data}
  defp bind_values(_encoders, [], _length, _data), do: {:error, "missing 1 or more parameter values"}
  defp bind_values([], _values, _length, _data), do: {:error, "too many parameter values"}

  defp bind_values([_encoder | encoders], [nil | values], length, data) do
    bind_values(encoders, values, length + 4, [data, <<255, 255, 255, 255>>])
  end

  defp bind_values([encoder | encoders], [value | values], length, data) do
    case encoder.encode(value) do
      :error -> {:error, "failed to convert #{inspect value} to #{encoder.name()}"}
      encoded ->
        size = :erlang.iolist_size(encoded)
        # total length includes size + the value length field (4)
        # but the value length field doesn't include itself (so no + 4 to size)
        bind_values(encoders, values, length + size + 4, [data, <<size::big-32>>, encoded])
    end
  end

  # We have to put together all our pieces. We have a prefix and suffix that
  # was generated as part of the first stage (prepare). We have the data from
  # binding our values (which sits in the middle of the Bind request). And,
  # we also include the Execute and Sync requests.
  # The length of the bind request is:
  #   length of prefix + length of suffix + length of data + 4 (length of length)
  @spec build_bind_and_execute_payload(t, non_neg_integer, iolist) :: iolist
  defp build_bind_and_execute_payload(prepared, length, data) do
    prefix = prepared.bind_prefix
    suffix = prepared.bind_suffix
    length = length + byte_size(prefix) + byte_size(suffix) + 4
    [?B, <<length::big-32>>, prefix, data, suffix, <<?E, 0, 0, 0, 9, 0, 0, 0, 0, 0, ?S, 0, 0, 0, 4>>]
  end

  # a data row
  defp read_rows(conn, prepared, decoders, {?D, <<_column_count::big-16, row::binary>>}, rows) do
    rows = [Parser.read_row(decoders, row, []) | rows]
    read_rows(conn, prepared, decoders, Connection.recv_message(conn), rows)
  end

  # data complete
  defp read_rows(_conn, prepared, _decoders, {?C, tag}, rows) do
    result = %PgEx.Result{
      rows: rows,
      columns: prepared.columns,
      affected: extract_rows_from_tag(tag),
    }
    {:ok, result}
  end

  for command <- ["SELECT ", "UPDATE ", "DELETE ", "MOVE ", "COPY ", "FETCH "] do
    defp extract_rows_from_tag(<<unquote(command), rows::binary>>) do
      case Integer.parse(rows) do
        {n, <<0>>} -> n
        _ -> -1
      end
    end
  end

  defp extract_rows_from_tag(<<"INSERT ", value::binary>>) do
    {pos, 1} = :binary.match(value, <<32>>)
    {_oid, <<32, rows::binary>>} = :erlang.split_binary(value, pos)
    case Integer.parse(rows) do
      {n, <<0>>} -> n
      _ -> -1
    end
  end

  defp extract_rows_from_tag(<<"TRUNCATE TABLE", 0>>), do: :truncate

  defp extract_rows_from_tag(_unknown) do
    -1
  end
end
