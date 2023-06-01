defmodule Guppi.BlfHandler do
  use GenServer

  require Logger

  def start_link(opts) do
    agent =
      case Keyword.fetch(opts, :agent) do
        {:ok, nil} ->
          raise ArgumentError, "Agent name not provided"

        {:ok, agent} ->
          agent
      end

    blf_uri =
      case Keyword.fetch(opts, :blf_uri) do
        {:ok, nil} ->
          raise ArgumentError, "blf target not provided"
        {:ok, blf_uri} ->
          Sippet.URI.parse!(blf_uri)
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

    GenServer.start_link(
      __MODULE__, %{
        agent: agent,
        blf_uri: blf_uri,
        timer: timer,
        retries: retries
      })
  end

  defp schedule_subscribe(timer) when is_integer(timer) do
    :timer.send_interval(timer, :subscribe)
  end

  defp send_subscribe(agent, blf_uri) do
    Process.send(agent, {:subscribe, blf_uri}, [])
  end

  @impl true
  def init(state) do
    schedule_subscribe(state.timer)

    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    send_subscribe(state.agent, state.blf_uri)

    Process.send_after(self(), :work, state.timer, [])

    {:noreply, state}
  end

  @impl true
  def handle_info(:work, state = %{retries: 0}) do
    Logger.debug("Register attempts #{state.retries}: #{state.agent}")

    schedule_subscribe(state.timer)

    {:noreply, Map.replace(state, :retries, state.max_retries)}
  end

  @impl true
  def handle_info(:work, state) do
    Logger.debug("Register attempts #{state.retries}: #{state.agent}")

    case state.retries > 0 do
      true ->
        send_subscribe(state.agent, state.blf_uri)
        {:noreply, Map.replace(state, :retries, state.retries - 1)}

      false ->
        {:noreply, state}
    end
  end
end
