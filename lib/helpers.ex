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

  defp get_local_ip([head | _tail]) when is_tuple(head) do
    [ip, _broadcast, _net_mask] = Tuple.to_list(head)

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

    ip
  end

  defp ip_string(ip) when is_tuple(ip) do
    Enum.join(Tuple.to_list(ip), ".")
  end

  def uri!(cfg) when is_map(cfg), do: struct!(Sippet.URI, cfg)

  def local_sdp!() do
    """
    v=0
    o=- 1 1 IN IP4 #{local_ip!()}
    s=0
    c=IN IP4 #{local_ip!()}
    t=0 0
    a=sendrecv
    m=audio #{Enum.random(20000..40000)} RTP/AVP 0 127
    a=rtpmap:0 PCMU/8000
    a=rtpmap:127 telephone-event/8000
    """ |> ExSDP.parse()
  end

  def sdp() do
    [
      version: 0,
      username: "Guppi",
      session_id: Enum.random(0..131_070),
      session_version: 0,
      address: local_ip!(),
      port: Enum.random(20000..40000)
    ]
  end
end
