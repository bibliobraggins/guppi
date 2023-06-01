defmodule Guppi.BlfHandler do
  use GenServer

  require Logger

  def start_link(opts) do
    agent =
      case Keyword.fetch(opts, :name) do
        {:ok, nil} ->
          raise ArgumentError, "Agent name not provided"

        {:ok, agent} when is_map(agent) ->
          agent
      end

    blf_uri =
      case Keyword.fetch(opts, :blf_uri) do
        {:ok, nil} ->
          raise ArgumentError, "blf target not provided"
        {:ok, blf_uri = %Sippet.URI{}} ->
          blf_uri
      end

    retries =
      case Keyword.fetch(opts, :retries) do
        {:ok, nil} ->
          5

        {:ok, retries} when is_integer(retries) ->
          retries
      end

    timer =
      case Keyword.fetch(opts, :timer) do
        {:ok, nil} ->
          360_000

        {:ok, timer} when is_integer(timer) ->
          timer * 100
      end

    Logger.log(:debug, "Starting Presence Handler for user: #{agent}")

    GenServer.start_link(__MODULE__, {agent, blf_uri, timer, retries})
  end

  @impl true
  def init({agent, blf_uri, timer, retries}) do
    {:ok, {agent, blf_uri, timer, retries}, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subcribe, {agent, blf_uri, timer, retries}) do
    send(agent, {:subscribe, blf_uri})

    {:noreply, {agent, blf_uri, timer, retries}, {:continue, :wait}}
  end

  @impl true
  def handle_continue(:wait, {agent, blf_uri, timer, retries}) do
    Process.sleep(timer)

    {:noreply, {agent, blf_uri, timer, retries}, {:continue, :subscribe}}
  end
end
