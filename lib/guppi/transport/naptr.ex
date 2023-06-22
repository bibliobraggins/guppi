defmodule Guppi.NaptrTransport do
  use GenServer

  alias Sippet.Message.StatusLine, as: StatusLine
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message, as: Message

  require Logger

  @moduledoc """
    The NaptrTransport is a failover capable transport for Sippet, basically. provide
    resolved via NAPTR, SRV, or A records provided via an initial options KeywordList:

      [
        port: local_port,

        proxy:
          [
            type: "NAPTR" || "SRV" || "A",
            record: "sip_provider_domain.net",
            port: nil || 0 || 5060,
            transport: nil || :udp || :tls || :tcp
            | rest_of_proxies
          ]
      ]

    - If the port is left nil, we send to port 5060
    - If the transport is left nil, we spawn with :udp
    - If no proxy is provided, we send messages to
      the declared recipient in the start line.
  """

  @type protocol :: :udp | :tcp | :tls

  @enforce_keys [
    :socket,
    :family,
    :sippet,
    :protocol,
    :proxy
  ]

  defstruct @enforce_keys ++ [
    :ssl
  ]

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
          raise ArgumentError, "This Transport requires an proxy record"
      end

    ciphers =
      if options[:protocol] == :tls do
        case Keyword.fetch(options, :ciphers) do
          {:ok, nil} ->
            nil
          {:ok, ciphers} ->
            String.split(ciphers, ",")
        end
      else
        nil
      end

    crt =
      if options[:protocol] == :tls do
        case Keyword.fetch(options, :key) do
          {:ok, nil} ->
            raise ArgumentError,  "cannot use TLS without a crt"
          {:ok, crt} ->
            crt
          err ->
            raise ArgumentError, "cannot use TLS without a crt: #{err}"
          end
      else
        nil
      end

    key =
      if options[:protocol] == :tls do
        case Keyword.fetch(options, :key) do
          {:ok, nil} ->
            raise ArgumentError,  "cannot use TLS without a key"
          {:ok, crt} ->
            crt
          err ->
            raise ArgumentError,  "cannot use TLS without a key: #{err}"
          end
      else
        nil
      end

    opts = [name: name, ip: ip, port: port, proxy: proxy, family: family, ciphers: ciphers, crt: crt, key: key]

    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  @spec init(keyword()) :: {:ok, nil, {:continue, keyword()}}
  def init(opts) when is_list(opts) do
    Sippet.register_transport(opts[:name], opts[:protocol], reliable?(opts[:protocol]))

    {:ok, nil, {:continue, opts}}
  end

  @impl true
  def handle_continue(opts, _) do
    case start_socket(opts) do
      {:ok, socket} ->
        Logger.debug("#{inspect(self())} started transport " <> "#{stringify_sockname(socket)}/#{opts[:protocol]}")

        state =
          %__MODULE__{
            socket: socket,
            family: opts[:family],
            sippet: opts[:name],
            proxy: opts[:proxy],
            protocol: opts[:protocol],
            ssl: opts[:ssl_opts]
          }

        {:noreply, state}

      {:error, reason} ->
        Logger.error("#{inspect(self())} port #{opts[:port]}/#{opts[:protocol]} #{inspect(reason)}, retrying in 10s...")

        Process.sleep(10_000)

        {:noreply, nil, {:continue, opts}}
    end
  end

  @spec handle_info({protocol(), port(), tuple(), integer(), binary()}, struct()) :: {:noreply, %__MODULE__{}}
  @impl true
  def handle_info({protocol, _socket, from_ip, from_port, packet}, %__MODULE__{sippet: sippet} = state) do
    Sippet.Router.handle_transport_message(sippet, packet, {protocol, from_ip, from_port})

    {:noreply, state}
  end

  @impl true
  def handle_call({:send_message, message, to_host, to_port, key}, _from, state) do

    io_msg = Message.to_iodata(message)

    Logger.info("Sending: \n#{to_string(message)}")

    case message do
      %Message{start_line: %RequestLine{}} ->
        Logger.debug([
          "sending Request to #{stringify_hostport(state.proxy, state.port)}/#{state.protocol}",
          ", #{inspect(key)}"
        ])


        case send_msg(state, io_msg) do
          :ok ->
            :ok
          {:error, reason} ->
            if key != nil do
              Sippet.Router.receive_transport_error(state.sippet, key, reason)
            end
        end

      %Message{start_line: %StatusLine{}} ->
        Logger.debug([
          "sending Response to #{stringify_hostport(to_host, to_port)}/#{state.protocol}",
          ", #{inspect(key)}"
        ])

        case send_msg(state, io_msg) do
          :ok ->
            :ok
          {:error, reason} ->
            if key != nil do
              Sippet.Router.receive_transport_error(state.sippet, key, reason)
            end
        end
    end

    {:reply, :ok, state}
  end

  @impl true
  def terminate(reason, %__MODULE__{} = state) do
    Logger.debug(
      "stopped transport #{stringify_sockname(state.socket)}/#{state.protocol}, reason: #{inspect(reason)}"
    )

    case state.protocol do
      :tls ->
        :ssl.close(state.socket)
      :tcp ->
        :gen_tcp.close(state.socket)
      :udp ->
        :gen_udp.close(state.socket)
    end
  end

  #_________________________________________________________________________________#

  defp send_msg(state, io_msg) do
    case state.protocol do
      :tls ->
        case :ssl.send(state.socket, io_msg) do
          :ok ->
            :ok
        end
      :tcp ->
        case :gen_tcp.send(state.socket, io_msg) do
          :ok -> :ok
          {:error, reason} ->
            {:error, reason}
        end
      :udp ->
        case resolve_name(state.proxy.target, state.family) do
          {:ok, to_ip} ->
            case :gen_udp.send(state.socket, to_ip, state.proxy.port, io_msg) do
              :ok -> :ok
              {:error, reason} ->
                {:error, reason}
            end
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp start_socket(opts) do
    case opts[:protocol] do
      :tls ->
        with {:ok, _socket} <- :ssl.listen(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family], opts[:ssl_opts]]),
              {:ok, socket} <- :ssl.connect(opts[:proxy].target, opts[:proxy].port, opts[:ssl_opts], 3600) do
                {:ok, socket}
        else
          {:error, reason} ->
            {:error, reason}
        end
      :tcp ->
        with {:ok, _socket} <- :gen_tcp.listen(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family]]),
        {:ok, socket} <- :gen_tcp.connect(opts[:proxy].target, opts[:proxy].port) do
          {:ok, socket}
        else
          {:error, reason} ->
            {:error, reason}
        end
      :udp ->
        case :gen_udp.open(opts[:port], [:binary, {:active, true}, {:ip, opts[:ip]}, opts[:family]]) do
          {:ok, socket} ->
            {:ok, socket}
          {:error, reason} ->
            {:error, reason}
      end
    end
  end

  def resolve_name(host, family) do
    to_charlist(host)
    |> :inet.getaddr(family)
  end

  def stringify_sockname(socket) do
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

  defp reliable?(proto) do
    if proto == :tcp || :tls do
      true
    else
      false
    end
  end

end
