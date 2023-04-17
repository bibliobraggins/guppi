defmodule Guppi.Account do
  @doc """
    Defines a struct that holds per account config variables
  """

  alias Sippet.URI, as: URI

  defstruct name: nil,
            register: nil,
            extension: nil,
            display_name: nil,
            registrar: nil,
            transport: nil,
            registration_timer: nil,
            max_forwards: nil,
            realm: nil,
            proxy: nil,
            local_sdp: nil,
            ip: nil,
            uri: nil,
            digit_map: nil,
            primary_dns: nil,
            allow: nil,
            secondary_dns: nil,
            sip_user: nil,
            sip_password: nil,
            sip_server_1: nil,
            sip_server_2: nil,
            outbound_proxy: nil,
            sdp: nil,
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
      account_map
      |> Map.replace!(
        :ip,
        String.replace(account_map.ip, ~r|0\.0\.0\.0|, Guppi.Helpers.local_ip!())
      )
      |> Map.replace!(:uri, Sippet.URI.parse!(account_map.uri))

    struct(Guppi.Account, account)
  end

  # defp write(config), do: File.write!(@config_file, Jason.encode!(config), [])
end
