defmodule Guppi.Config do
  @doc """
    Defines a struct that holds per account config variables
  """

  alias Guppi.Config.Account, as: Account
  alias Guppi.Config.Transport, as: Transport

  defstruct accounts: nil,
            transports: nil

  def read_config!, do: read_config() |> parse_config!()

  defp read_config do
    with {:ok, raw_config} <- File.read("./configuration.json"),
        {:ok, config} <- Jason.decode(raw_config, keys: :atoms) do
          config
      else
        {:error, err} -> raise ArgumentError, "Config problem: #{inspect(err)}"
      end
  end

  defp parse_config!(raw_config) do
    accounts = Enum.into(raw_config.accounts, [], fn account -> Account.set_account!(account) end)

    transports = Enum.into(raw_config.transports, [], fn transport -> Transport.set_transport!(transport) end)

    %__MODULE__{
      accounts: accounts,
      transports: transports
    }
  end

end

defmodule Guppi.Config.Account do
  @doc """
    Defines a struct that holds per account config variables
  """

  defstruct sip_user: nil,
            register: nil,
            sip_password: nil,
            extension: nil,
            display_name: nil,
            registration_timer: nil,
            subscription_timer: nil,
            refresh_timer: nil,
            max_forwards: nil,
            local_sdp: nil,
            ip: nil,
            transport: nil,
            uri: nil,
            allow: nil,
            user_agent: nil,
            outbound_proxy: nil,
            sdp: nil,
            subscribes: nil,
            certificate: nil


  def set_account!(account_map) do
    account = Map.replace!(account_map, :uri, Sippet.URI.parse!(account_map.uri))

    account = case Map.fetch(account_map, :ip) do
      {:ok, _ip} ->
        Map.replace!(
          account,
          :ip,
          String.replace(account.ip, ~r|0\.0\.0\.0|, Guppi.Helpers.local_ip!())
        )

      _ ->
        Map.replace!(
          account,
          :ip,
          Guppi.Helpers.local_ip!()
        )
    end

    struct(__MODULE__, account)
  end

end

defmodule Guppi.Config.Transport do
  defstruct port: nil,
            outbound_proxy: nil

  def set_transport!(transport) do
    transport = case Map.fetch(transport, :ip) do
      {:ok, _ip} ->
        Map.replace!(
          transport,
          :ip,
          String.replace(transport.ip, ~r|0\.0\.0\.0|, Guppi.Helpers.local_ip!())
        )

      _ ->
        Map.replace!(
          transport,
          :ip,
          Guppi.Helpers.local_ip!()
        )
    end

    transport = case Map.fetch(transport, :outbound_proxy) do
      {:ok, outbound_proxy} ->
        Map.replace!(
          transport,
          :outbound_proxy,
          resolve_proxy(outbound_proxy)
        )
      othr ->
        raise ArgumentError, "an outbound proxy is required, #{inspect(othr)}"
    end

    transport
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
