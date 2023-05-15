defmodule Guppi.Helpers do
  require Logger

  def local_ip!() do
    get_interfaces()
    |> validate_ip()
    |> stringify()
  end

  def local_ip() do
    get_interfaces()
    |> validate_ip()
  end

  defp get_interfaces() do
    {:ok, address_list} = :inet.getif()

    address_list
  end

  defp validate_ip([{ip, _, _} | _tail]) do
    case ip do
      {10, 0..255, 0..255, 0..255} ->
        ip

      {172, 16..31, 0..255, 0..255} ->
        ip

      {192, 168, 0..255, 0..255} ->
        ip

      {127, 0..255, 0..255, 0..255} ->
        ip

      _ ->
        ip
    end
  end

  defp stringify(ip) do
    :inet.ntoa(ip)
    |> to_string()
  end

  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
