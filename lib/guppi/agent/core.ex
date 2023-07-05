defmodule Guppi.Core do
  use Sippet.Core
  use GenServer

  require Logger

  alias String.Chars.Sippet.Message.StatusLine
  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message.StatusLine, as: StatusLine

  @moduledoc """
    The Sippet 'Core'.
    Collection of Callbacks called when Messages are received via the
    Cores Respectively named Sippet and Transport, the 'key' is a reference to a given Sippet transaction.

    Each Guppi Agent owns its own core that receives messages on behalf of it's respective transport

    Each Core is registered to a Sippet and Transport using
    the respective Sippet :name and Transport :name fields.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Sippet.register_core(opts[:name], Guppi.Core)

    {:ok, nil}
  end

  @impl true
  def receive_request(%Message{start_line: %RequestLine{}} = incoming_request, nil) do
    # This will happen when ACKs are received for a previous 200 OK we sent.
    Logger.info("Received: \n#{to_string(incoming_request)}")

    # send(route_agent(incoming_request.headers.to), {incoming_request.start_line.method, incoming_request})
    :ok
  end

  @impl true
  def receive_request(%Message{start_line: %RequestLine{}} = incoming_request, server_key) do
    Logger.info("Received: \n#{to_string(incoming_request)}")

    GenServer.cast(
      route_agent(incoming_request.start_line.request_uri),
      {incoming_request.start_line.method, incoming_request, server_key}
    )
  end

  # triggered by authentication challenges.
  @impl true
  def receive_response(
        %Message{start_line: %StatusLine{status_code: status_code}} = incoming_response,
        client_key
      )
      when status_code in 400..499 do
    Logger.info("Received: \n#{to_string(incoming_response)}")

    case status_code do
      status_code when status_code in [401, 407] ->
        send(route_agent(incoming_response.headers.to), {:challenge, incoming_response})
      _othr ->
        Logger.warning("transatcion #{client_key} failed :: #{status_code}")
    end
  end

  @impl true
  def receive_response(
        %Message{start_line: %StatusLine{status_code: status_code}} = incoming_response,
        client_key
      )
      when status_code in [200] do
    Logger.info("Received: \n#{to_string(incoming_response)}")

    send(route_agent(incoming_response.headers.to), {:ok, incoming_response, client_key})
  end

  @impl true
  def receive_response(%Message{start_line: %StatusLine{}} = incoming_response, client_key) do
    Logger.info("Received: #{to_string(incoming_response)}")

    send(route_agent(incoming_response.headers.to), {:ok, incoming_response, client_key})
  end

  @impl true
  def receive_error(error_reason, client_or_server_key) do
    Logger.warning("Received Error: #{inspect(error_reason)} :: #{client_or_server_key}")
  end

  defp route_agent({_display_name, uri, _tag}), do: route_agent(uri)

  defp route_agent(%Sippet.URI{} = uri) do
    String.to_existing_atom(uri.userinfo)
  end
end
