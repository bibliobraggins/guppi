defmodule Guppi.NaptrTransport do
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

  @enforce_keys [
    :socket,
    :family,
    :sippet,
    :proxy,
    :idx
  ]

  defstruct @enforce_keys ++ [
    :crt,
    :key,
    :ciphers,
    :port
  ]

  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, struct(__MODULE__, options))
  end

  #_________________________________________________________________________________#

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

  def resolve_proxy(record) do
    case record.type do
      "A" ->
        case Map.has_key?(record, :port) do
          true ->
            # As per RFC3261, UDP should be considered the default, over port 5060
            %{scheme: set_transport_scheme(record.scheme), target: record.domain, port: record.port}

          false ->
            raise ArgumentError, "port number is required when using an A record for proxy"
        end

      "SRV" ->
        case Map.has_key?(record, :transport_scheme) do
          true ->
            %{target: record.domain, transport_scheme: record.transport_scheme}
            res_srv(record.transport_scheme, record.domain)

          false ->
            raise ArgumentError, "transport_scheme is required when using an SRV record for proxy"
        end

      "NAPTR" ->
        res_naptr(record.domain)

      _ ->
        raise ArgumentError, "invalid DNS records provided"
    end
  end

  defp res_naptr(domain) do
    case DNS.resolve(domain, :naptr) do
      {:ok, response} ->
        Enum.sort(response, :asc)
        |> Enum.into([], fn {_order, _pref, _flags, service, _regexp, replacement} ->
          res_srv(set_transport_scheme(service), replacement)
        end)
        |> List.flatten()

      {:error, reason} ->
        raise ArgumentError, "Bad NAPTR Record provided: #{reason}"
    end
  end

  defp res_srv(transport_scheme, domain) do
    case DNS.resolve(domain, :srv) do
      {:ok, response} ->
        Enum.sort(response, :asc)
        |> Enum.into([], fn {_priority, _weight, port, target} ->
          %{
            transport: transport_scheme,
            port: port,
            target: target
          }
        end)

      {:error, reason} ->
        raise ArgumentError, "Bad SRV Record provided: #{reason}"
    end
  end

  def res_a(domain) do
    case DNS.resolve(domain, :a) do
      {:ok, host} ->
        host

      {:error, reason} ->
        raise ArgumentError, "Bad A Record provided: #{reason}"
    end
  end

  defp set_transport_scheme(service) do
    case service do
      'sips+d2t' ->
        :tls

      'sip+d2t' ->
        :tcp

      'sip+d2u' ->
        :udp

      _ ->
        raise ArgumentError, "Bad NAPTR Record provided: invalid service: #{service}"
    end
  end

end
