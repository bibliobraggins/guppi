defmodule Guppi.RegistrationHandler do
  use GenServer

  require Logger

  def start_link(opts) do
    IO.puts("starting reg handler for #{opts[:name]}")

    agent =
      case Keyword.fetch(opts, :name) do
        {:ok, agent} ->
          agent

        _ ->
          raise ArgumentError, "Agent name not provided"
      end

    cseq =
      case Keyword.fetch(opts, :cseq) do
        {:ok, cseq} when is_integer(cseq) ->
          cseq

        _ ->
          0
      end

    retries =
      case Keyword.fetch(opts, :retries) do
        {:ok, retries} when is_integer(cseq) ->
          retries

        _ ->
          5
      end

    timer =
      case Keyword.fetch(opts, :timer) do
        {:ok, timer} when is_integer(cseq) ->
          # seconds
          timer * 100

        _ ->
          360_000
      end

    Logger.log(:debug, "starting Registration Handler for user: #{opts[:agent]}")

    GenServer.start_link(__MODULE__, %{agent: agent, cseq: cseq, retries: retries, timer: timer})
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
    Logger.debug("Register attempt #{state.retries}", state.agent)

    send_register(state.agent, state.cseq)

    {:noreply, state}
  end

  defp schedule_registration(timer) when is_integer(timer) do
    Process.send_after(self(), :register, timer)
  end

  defp send_register(agent, cseq) do
    Process.send(agent, {cseq, :register}, [])
  end
end
