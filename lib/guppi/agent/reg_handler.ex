defmodule Guppi.RegistrationHandler do
  use GenServer

  require Logger

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    agent =
      case Keyword.fetch(opts, :agent) do
        {:ok, nil} ->
          raise ArgumentError, "Agent name not provided"

        {:ok, agent} ->
          agent
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

    Logger.log(:debug, "starting Registration Handler for user: #{agent}")

    GenServer.start_link(__MODULE__, %{
      agent: agent,
      retries: retries,
      max_retries: retries,
      timer: timer,
      registered: false
    })
  end

  defp schedule_registration(timer) when is_integer(timer) do
    :timer.send_interval(timer, :register)
  end

  defp send_register(agent) do
    Process.send(agent, :register, [])
  end

  @impl true
  def init(state) do
    schedule_registration(state.timer)

    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, state) do
    send_register(state.agent)

    Process.send_after(self(), :work, state.timer, [])

    {:noreply, state}
  end

  @impl true
  def handle_info(:work, state = %{retries: 0}) do
    Logger.debug("Register attempts #{state.retries}: #{state.agent}")

    schedule_registration(state.timer)

    {:noreply, Map.replace(state, :retries, state.max_retries)}
  end

  @impl true
  def handle_info(:work, state) do
    Logger.debug("Register attempts #{state.retries}: #{state.agent}")

    case state.retries > 0 do
      true ->
        send_register(state.agent)
        {:noreply, Map.replace(state, :retries, state.retries - 1)}

      false ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_, _) do
    Logger.warn("WHY DID MY Registration handler STOP")
  end
end
