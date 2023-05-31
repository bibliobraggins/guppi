defmodule Guppi.Requests do
  require Logger

  alias Guppi.Config.Account, as: Account

  alias Sippet.Message, as: Message
  alias Sippet.URI, as: URI
  alias Sippet.Message.RequestLine, as: RequestLine
  # alias Sippet.Message.StatusLine, as: StatusLine

  @moduledoc """
    here we store references to most if not all the request building.
  """

  def message(method, account, cseq) do
    Kernel.apply(__MODULE__, method, [account, cseq])
  end

  def register(account = %Account{}, cseq) do
    %Message{
      start_line: RequestLine.new(:register, account.uri),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.ip}", account.uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from:
          {account.display_name,
           URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"),
           %{"tag" => Message.create_tag()}},
        to:
          {account.display_name,
           URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"), %{}},
        contact:
          {account.display_name,
           URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"), %{}},
        expires: account.registration_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :register},
        user_agent: "#{account.user_agent}",
        call_id: Message.create_call_id()
      }
    }
  end

  def ack(account, cseq, call, sdp_offer) do
    %Message{
      start_line: RequestLine.new(:ack, "#{call.from.uri.scheme}:#{call.from.uri.host}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.ip}", account.uri.port}, %{"branch" => call.via.branch}}
        ],
        from: {"#{account.display_name}", call.to.uri, %{"tag" => Message.create_tag()}},
        to: {call.from.caller_id, call.from.uri, call.from.tag},
        contact: contact(account),
        expires: account.registration_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :ack},
        user_agent: "#{account.user_agent}",
        call_id: call.id
      },
      body: sdp_offer
    }
  end

  def subscribe(account, cseq, blf_uri) do
    %Message{
      start_line: RequestLine.new(:subscribe, "sip:" <> blf_uri),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.ip}", account.uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from: {
          account.display_name,
          account.uri,
          %{"tag" => Message.create_tag()}
        },
        to: {
          "",
          blf_uri,
          %{}
        },
        contact: contact(account),
        event: "dialog",
        Accept: "application/dialog-info+xml",
        expires: account.subscription_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :subscribe},
        user_agent: "#{account.user_agent}",
        call_id: "#{blf_uri}_#{cseq}"
      }
    }
  end

  def contact(account) do
    {account.display_name,
     URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"), %{}}
  end

  # updates cseq, via, and from headers for a given request.
  # appropriate for authentication challenges. may be useful elsewhere.
  def via(message) do
    message
    |> Message.update_header(:cseq, fn {seq, method} ->
      {seq + 1, method}
    end)
    |> Message.update_header_front(:via, fn {ver, proto, hostport, params} ->
      {ver, proto, hostport, %{params | "branch" => Message.create_branch()}}
    end)
    |> Message.update_header(:from, fn {name, uri, params} ->
      {name, uri, %{params | "tag" => Message.create_tag()}}
    end)
  end
end
