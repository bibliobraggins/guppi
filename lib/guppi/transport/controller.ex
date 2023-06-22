defmodule Guppi.TransportController do
  use GenServer

  @moduledoc """
    This module spawns a Transport GenServer and manages it.

    TODO: should have handle_info() callbacks for when child
    dies. when the child dies, we increment the proxy records
    index by one, and reinitialize the child process with the
    next set of socket options. The child should hold all
    logic for handling and setting up the connection.
  """

  def start_link(opts) do
    proxy_list =
      case Keyword.fetch(opts, :proxy) do
        {:ok, nil} ->
          nil
        {:ok, proxy} ->
          resolve_proxy(proxy)
        _ ->
          raise ArgumentError, "need a host to resolve"
      end

    GenServer.start_link(__MODULE__, {proxy_list, opts})
  end

  @impl true
  def init({proxy_list, opts}) do
    idx = 0

    %{target: target, port: port, scheme: scheme} = Enum.at(proxy_list, idx)

    options = [proxy: %{target: target, port: port}, proto: scheme]

    Guppi.NaptrTransport.start_link(options)
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
