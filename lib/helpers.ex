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

  def uri!(cfg) when is_map(cfg), do: struct!(Sippet.URI, cfg)

  def local_sdp!(account) do
    """
    v=0
    o=- 1 1 IN IP4 #{account.uri.host}
    s=0
    c=IN IP4 #{account.uri.host}
    t=0 0
    a=sendrecv
    m=audio #{Enum.random(20000..40000)} RTP/AVP 0 127
    a=rtpmap:0 PCMU/8000
    a=rtpmap:127 telephone-event/8000
    """
  end

  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
