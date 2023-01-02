defmodule Guppi.Helpers do
  require Logger

  def local_ip!() do
    get_interfaces()
    |> get_local_ip()
    |> ip_string()
  end

  def local_ip() do
    get_interfaces()
    |> get_local_ip()
  end

  defp get_interfaces() do
    {:ok, address_list} = :inet.getif()
    address_list
  end

  defp get_local_ip([head | _tail]) do
    {ip, _broadcast, _net_mask} = head

    case ip do
      {10, _, _, _} ->
        ip

      {172, 16..31, _, _} ->
        ip

      {192, 168, _, _} ->
        ip

      _ ->
        Logger.warn("Guppi should only use regular private IP addresses, got: #{ip}")
        ip
    end
  end

  defp ip_string(ip) when is_tuple(ip) do
    Enum.join(Tuple.to_list(ip), ".")
  end

  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
