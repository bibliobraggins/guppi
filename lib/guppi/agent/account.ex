defmodule Guppi.Account do
  @doc """
    Defines a struct that holds per account config variables
  """

  alias Sippet.URI, as: URI

  defstruct [
    :register,
    :name,
    :extension,
    :display_name,
    :registrar,
    :transport,
    :registration_timer,
    :max_forwards,
    :realm,
    :proxy,
    :local_sdp,
    :uri,
    :digit_map,
    :primary_dns,
    :allow,
    :secondary_dns,
    :sip_user,
    :sip_password,
    :sip_server_1,
    :sip_server_2,
    :outbound_proxy,
    :sdp,
    :certificates
  ]

  # @defaults %{}

  def read_config!, do: read_config() |> parse_config!()

  defp read_config do
    case Jason.decode(File.read!("./configuration.json"), keys: :atoms) do
      {:ok, config} -> config
      {:error, err} -> raise ArgumentError, "Config problem: #{inspect(err)}"
    end
  end

  defp parse_config!(raw_config),
    do: Enum.into(raw_config.accounts, [], fn account -> parse_account(account) end)

  defp parse_account(account) do
    struct(Guppi.Account, parse_uri!(account))
  end

  # defp write(config), do: File.write!(@config_file, Jason.encode!(config), [])

  defp parse_uri!(account) do
    uri = String.replace(account.uri, ~r|0\.0\.0\.0|, Guppi.Helpers.local_ip!(), [])

    parsed_uri =
      case URI.parse(uri) do
        {:ok, %URI{} = parsed_uri} ->
          parsed_uri

        {:error, reason} ->
          raise ArgumentError, "Invalid uri provided: #{inspect(reason)}"
      end

    Map.replace!(account, :uri, parsed_uri)
  end
end
