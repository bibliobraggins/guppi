defmodule Guppi.RegistrationHandler do
  use GenServer

  require Logger

  def start_link(opts) do
    agent =
      case Keyword.fetch(opts, :name) do
        {:ok, nil} ->
          raise ArgumentError, "Agent name not provided"
        {:ok, agent} ->
          agent
      end

    cseq =
      case Keyword.fetch(opts, :cseq) do
        {:ok, nil} ->
          0
        {:ok, cseq} when is_integer(cseq) ->
          cseq
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
        {:ok, timer} when is_integer(cseq) ->
          # seconds
          timer * 100
      end

    Logger.log(:debug, "starting Registration Handler for user: #{agent}")

    GenServer.start_link(__MODULE__, %{
      agent: agent,
      cseq: cseq,
      retries: retries,
      timer: timer,
      registered: false
    })
  end

  @impl true
  def init(state) do
    schedule_registration(state.timer)

    {:ok, state, {:continue, :register}}
  end

  @impl true
  def handle_continue(:register, state) do
    send_register(state.agent, state.cseq)

    Process.send_after(self(), :register, state.timer, [])

    {:noreply, state}
  end

  @impl true
  def handle_info(:register, state) do
    Logger.debug("Register attempt #{state.retries}: #{state.agent}")

    send_register(state.agent, state.cseq)

    {:noreply, state}
  end

  @impl true
  def terminate(_, _) do
    Logger.warn("WHY DID MY GENSERVER STOP")
  end

  defp schedule_registration(timer) when is_integer(timer) do
    IO.inspect("timer: #{timer} seconds")
    :timer.send_interval(timer, :register)
  end

  defp send_register(agent, cseq) do
    Process.send(agent, {cseq, :register}, [])
  end
end
