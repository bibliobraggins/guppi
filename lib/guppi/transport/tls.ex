defmodule Guppi.TlsTransport do
  use GenServer

  require Logger

  @enforce_keys [
    :socket,
    :family,
    :sippet,
    :proxy,
    :idx
  ]

  defstruct @enforce_keys

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(options) when is_list(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :name option to be present"
      end

    port =
      case Keyword.fetch(options, :port) do
        {:ok, port} when is_integer(port) ->
          port

        other ->
          raise ArgumentError,
                "expected :port to be an integer between 1 and 65535, got: #{inspect(other)}"
      end

    {address, family} =
      case Keyword.fetch(options, :address) do
        {:ok, {address, family}} when family in [:inet, :inet6] and is_binary(address) ->
          {address, family}

        {:ok, address} when is_binary(address) ->
          {address, :inet}

        {:ok, other} ->
          raise ArgumentError,
                "expected :address to be an address or {address, family} tuple, got: " <>
                  "#{inspect(other)}"

        :error ->
          {"0.0.0.0", :inet}
      end

    ip =
      case resolve_name(address, family) do
        {:ok, ip} ->
          ip

        {:error, reason} ->
          raise ArgumentError,
                ":address contains an invalid IP or DNS name, got: #{inspect(reason)}"
      end

    proxy =
      case Keyword.fetch(options, :proxy) do
        {:ok, proxy_record} when is_list(proxy_record) ->
          proxy_record

        {:ok, %{target: _, scheme: _, port: _} = proxy_record} ->
          [proxy_record]

        :error ->
          raise ArgumentError, "This Transport requires an outbound proxy record"
      end

    #ciphers =
    #  case Keyword.fetch(options, :ciphers) do
    #    {:ok, cipher_list} ->
    #      cipher_list

    #    :error ->
    #      raise ArgumentError, "This Transport requires an outbound proxy record"
    #  end

    opts = [name: name, ip: ip, port: port, proxy: proxy, family: family]

    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Sippet.register_transport(opts[:name], :tls, true)

    case :ssl.start() do
      :ok ->
        :ok
      error ->
        raise ArgumentError, "could not start :ssl, error: #{error}"
    end

    {:ok, nil, {:continue, opts}}
  end

  @impl true
  def handle_continue(opts, nil) do
    case :ssl.listen(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family]]) do
      {:ok, socket} ->
        Logger.debug(
          "#{inspect(self())} started transport " <>
            "#{stringify_sockname(socket)}/tls"
        )

        state = %__MODULE__{
          socket: socket,
          family: opts[:family],
          sippet: opts[:name],
          proxy: opts[:proxy],
          idx: 0
        }

        {:noreply, state}

      {:error, reason} ->
        Logger.error(
          "#{inspect(self())} port #{opts[:port]}/tls " <>
            "#{inspect(reason)}, retrying in 10s..."
        )

        Process.sleep(10_000)

        {:noreply, nil, {:continue, opts}}
    end
  end

  def resolve_name(host, family) do
    to_charlist(host)
    |> :inet.getaddr(family)
  end

  defp stringify_sockname(socket) do
    {:ok, {ip, port}} = :inet.sockname(socket)

    address =
      ip
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end

  def stringify_hostport(host, port) do
    "#{host}:#{port}"
  end

end
