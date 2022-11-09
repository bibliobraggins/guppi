defmodule Guppi.Helpers do
  require Logger

  def local_ip!() do
    get_interfaces()
    |> get_local_ip()
    # |> is_private?()
    |> ip_string()
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
    """
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

  def validate_session(sdp) do
    case ExSDP.parse(sdp) do
      {:ok, parsed} -> IO.inspect(parsed)
      {:error, error} -> error
    end
  end

  def test do
    """
    INVITE sip:192.168.0.203 SIP/2.0
    Allow-Events: conference,talk,hold
    Via: SIP/2.0/UDP 192.168.0.224:5060;branch=z9hG4bK149f2c5eCDEB0324
    User-Agent: PolycomVVX-VVX_450-UA/6.4.3.5018
    To: <sip:192.168.0.203>
    Supported: replaces, 100rel
    Max-Forwards: 70
    From: "VVX 450" <sip:VVX450@192.168.0.224>;tag=AF2E436D-4B04B5AB
    CSeq: 1 INVITE
    Content-Type: application/sdp
    Content-Length: 352
    Contact: <sip:VVX450@192.168.0.224>
    Call-ID: c9eed99f10837678ee3f8739cc3a53e7
    Allow: INVITE, ACK, BYE, CANCEL, OPTIONS, INFO, MESSAGE, SUBSCRIBE, NOTIFY, PRACK, UPDATE, REFER
    Accept-Language: en
    """
  end
end
