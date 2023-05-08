defmodule Guppi.BlfHandler do
  use GenServer

  require Logger

  def start_link(agent, blf_target, timer \\ Integer) do

    timer =
      case timer do
        {:ok, timer} ->
          timer * 100
        nil ->
          360000
      end

    GenServer.start_link(__MODULE__, {agent, blf_target, timer})
  end

  @impl true
  def init({agent, blf_target, timer}) do
    {:ok, {agent, blf_target, timer}, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subcribe, {agent, blf_target, timer}) do
    send(agent, {:subscribe, blf_target})

    {:noreply, {agent, blf_target, timer}, {:continue, :wait}}
  end

  @impl true
  def handle_continue(:wait, {agent, blf_target, timer}) do
    Process.sleep(timer)

    {:noreply, {agent, blf_target, timer}, {:continue, :subscribe}}
  end

end
