defmodule Guppi.Helpers do
  require Logger

  def local_ip!() do
    get_interfaces()
    |> validate_ip()
    |> stringify()
  end

  def local_ip() do
    get_interfaces()
    |> validate_ip()
  end

  defp get_interfaces() do
    {:ok, address_list} = :inet.getif()

    address_list
  end

  defp validate_ip([{ip, _, _} | _tail]) do
    case ip do
      {10, 0..255, 0..255, 0..255} ->
        ip

      {172, 16..31, 0..255, 0..255} ->
        ip

      {192, 168, 0..255, 0..255} ->
        ip

      {127, 0..255, 0..255, 0..255} ->
        ip

      _ ->
        ip
    end
  end

  def resolve_proxy(record) do
    case record.type do
      "A" ->
        case Map.has_key?(record, :port) do
          true ->
            %{transport_scheme: :udp, target: record.domain, port: record.port}
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
      "NAPTR" -> res_naptr(record.domain)
      _ ->
        raise ArgumentError, "invalid DNS records provided"
    end
  end

  defp res_naptr(domain) do
    case DNS.resolve(domain, :naptr) do
      {:ok, response} ->
        Enum.sort(response, :asc)
        |> Enum.into([], fn {_order, _pref, _flags, service, _regexp, replacement} -> res_srv(set_transport_scheme(service), replacement) end)
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
            target: target,
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

  defp stringify(ip) do
    :inet.ntoa(ip)
    |> to_string()
  end

  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
