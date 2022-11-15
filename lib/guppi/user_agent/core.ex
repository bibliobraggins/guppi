defmodule Guppi.Core do
  use Sippet.Core

  require Logger

  alias String.Chars.Sippet.Message.StatusLine
  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine
  alias Sippet.Message.StatusLine, as: StatusLine
  # alias Sippet.Transactions, as: Transactions

  @moduledoc """
    The Sippet 'Core'.
    Collection of Callbacks called when Messages are received via the
    Cores Respectively named Sippet and Transport, the 'key' is a reference to a given Sippet transaction.

    Each Guppi Agent owns its own core that receives messages on behalf of it's respective transport

    Each Core is registered to a Sippet and Transport using
    the respective Sippet :name and Transport :name fields.
  """

  def receive_request(%Message{start_line: %RequestLine{}} = ack, nil) do
    # This will happen when ACKs are received for a previous 200 OK we sent.
    GenServer.cast(route_agent(ack.headers.to), {ack})
  end

  def receive_request(%Message{} = incoming_request, server_key) do
    GenServer.call(route_agent(incoming_request.headers.to), {incoming_request.start_line.method, incoming_request, server_key})
  end

  def receive_response(%Message{start_line: %StatusLine{status_code: status_code}} = incoming_response, client_key) when status_code in [401,407] do
    GenServer.call(route_agent(incoming_response.headers.to), {:authenticate, incoming_response, client_key})
  end

  def receive_response(incoming_response, client_key) do
    GenServer.call(route_agent(incoming_response.headers.to), {:response, incoming_response, client_key})
  end

  def receive_error(error_reason, _client_or_server_key) do
    Logger.warn("Got Error: #{inspect(error_reason)}")
    # route_agent((UA/TU process), error_reason, key)
  end

  defp route_agent({_display_name, uri, _}) do
    case Registry.lookup(Guppi.Registry, uri.port) do
      [{pid, _agent}] when is_pid(pid) ->
        pid
      # _[] -> [] # shouldn't even be possible tbh. refactor maybe?
    end
  end

end
