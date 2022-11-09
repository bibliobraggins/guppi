defmodule Guppi.Media do
  use GenServer

  def start_link, do: start_link []
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    {:ok, ["started"]}
  end


end
