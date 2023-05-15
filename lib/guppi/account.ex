defmodule Guppi.Account do
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
            local_port: nil,
            uri: nil,
            allow: nil,
            user_agent: nil,
            outbound_proxy: nil,
            sdp: nil,
            subscribes: nil,
            certificate: nil

  # @defaults %{}

  def read_config!, do: read_config() |> parse_config!()

  defp read_config do
    case Jason.decode(File.read!("./configuration.json"), keys: :atoms) do
      {:ok, config} -> config
      {:error, err} -> raise ArgumentError, "Config problem: #{inspect(err)}"
    end
  end

  defp parse_config!(raw_config) do
    Enum.into(raw_config.accounts, [], fn account -> parse_account!(account) end)
  end

  defp parse_account!(account_map) do
    account =
      case Map.fetch(account_map, :ip) do
        {:ok, _ip} ->
          Map.replace!(
            account_map,
            :ip,
            String.replace(account_map.ip, ~r|0\.0\.0\.0|, Guppi.Helpers.local_ip!())
          )

        _ ->
          Map.replace!(
            account_map,
            :ip,
            Guppi.Helpers.local_ip!()
          )
      end
      |> Map.replace!(:uri, Sippet.URI.parse!(account_map.uri))

    account =
      case Map.has_key?(account, :outbound_proxy) do
        true ->
          Map.replace!(
            account,
            :outbound_proxy,
            Guppi.Helpers.resolve_proxy(account.outbound_proxy)
          )

        false ->
          account
      end

    struct(Guppi.Account, account)
  end

  # defp write(config), do: File.write!(@config_file, Jason.encode!(config), [])
end
