defmodule Guppi.Core do
  use Sippet.Core

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

  def receive_request(%Message{start_line: %RequestLine{}} = incoming_request, nil) do
    # This will happen when ACKs are received for a previous 200 OK we sent.
    Logger.debug(
      "#{inspect(incoming_request.start_line.method)} From: #{inspect(incoming_request.headers.from)}"
    )

    # send(route_agent(incoming_request.headers.to), {incoming_request.start_line.method, incoming_request})
    :ok
  end

  def receive_request(%Message{start_line: %RequestLine{}} = incoming_request, server_key) do
    Logger.debug(
      "#{inspect(incoming_request.start_line.method)} From: #{inspect(incoming_request.headers.from)}"
    )

    GenServer.cast(
      route_agent(incoming_request.start_line.request_uri),
      {incoming_request.start_line.method, incoming_request, server_key}
    )
  end

  # triggered by authentication challenges.
  def receive_response(
        %Message{start_line: %StatusLine{status_code: status_code}} = incoming_response,
        _client_key
      )
      when status_code in [401, 407] do
    Logger.debug("#{inspect(status_code)} From: #{inspect(incoming_response.headers.from)}")
    send(route_agent(incoming_response.headers.to), {:authenticate, incoming_response})
    # DON'T implicitly returon :ok or we break the auth flow
  end

  def receive_response(
        %Message{start_line: %StatusLine{status_code: status_code}} = incoming_response,
        client_key
      )
      when status_code in [200] do
    Logger.debug("#{inspect(status_code)} From: #{inspect(incoming_response.headers.from)}")
    send(route_agent(incoming_response.headers.to), {:ok, incoming_response, client_key})
  end

  def receive_response(
        %Message{start_line: %StatusLine{status_code: status_code}} = incoming_response,
        client_key
      ) do
    Logger.debug("#{inspect(status_code)} From: #{inspect(incoming_response.headers.from)}")
    send(route_agent(incoming_response.headers.to), {:ok, incoming_response, client_key})
  end

  def receive_error(error_reason, _client_or_server_key) do
    Logger.warn("Received Error: #{inspect(error_reason)}")
  end

  defp route_agent({_display_name, uri, _tag}), do: route_agent(uri)

  defp route_agent(%Sippet.URI{} = uri) do
    case Registry.lookup(Guppi.Registry, uri.port) do
      [{pid, _agent}] when is_pid(pid) ->
        pid
        # [] -> [] # shouldn't even be possible tbh. refactor maybe?
    end
  end
end
