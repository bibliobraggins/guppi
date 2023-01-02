defmodule Guppi.Requests do

  alias Guppi.Account, as: Account

  alias Sippet.Message, as: Message
  alias Sippet.URI, as: URI
  alias Sippet.Message.RequestLine, as: RequestLine
  #alias Sippet.Message.StatusLine, as: StatusLine

  @moduledoc """
    here we store references to most if not all the request building.
  """

  @spec register(%Account{register: true}, cseq :: non_neg_integer()) :: %Message{start_line: %RequestLine{method: :register}}
  def register(account = %Account{}, cseq) do
    %Message{
      start_line: RequestLine.new(:register, "#{account.uri.scheme}:#{account.realm}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.uri.host}", account.uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from:
          {"",
           URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.realm}"),
           %{"tag" => Message.create_tag()}},
        to:
          {"",
           URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.realm}"),
           %{}},
        contact: {"", account.uri, %{}},
        expires: account.registration_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :register},
        user_agent: "Guppi/0.1.0",
        call_id: Message.create_call_id()
      }
    }
  end

  @spec ack(%Account{}, cseq :: non_neg_integer(), %Guppi.Call{}, ExSDP.t()) :: %Message{start_line: %RequestLine{method: :ack}}
  def ack(account, cseq, call, sdp_offer) do
    %Message{
      start_line: RequestLine.new(:ack, "#{call.to.uri.scheme}:#{call.from.uri.host}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.uri.host}", account.uri.port},
           %{"branch" => call.via.branch}}
        ],
        from:
          {"",
           call.to.uri,
           %{"tag" => Message.create_tag()}},
        to:
          {call.from.caller_id, call.from.uri, call.from.tag},
        expires: account.registration_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :ack},
        user_agent: "Guppi/0.1.0",
        call_id: call.id,
      },
      body: to_string(Guppi.Agent.Media.sdp(account, sdp_offer))
    }
  end

end
