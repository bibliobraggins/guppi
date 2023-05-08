defmodule Guppi.Requests do
  alias Guppi.Account, as: Account

  alias Sippet.Message, as: Message
  alias Sippet.URI, as: URI
  alias Sippet.Message.RequestLine, as: RequestLine
  # alias Sippet.Message.StatusLine, as: StatusLine

  @moduledoc """
    here we store references to most if not all the request building.
  """

  @spec register(%Account{register: true}, cseq :: non_neg_integer()) :: %Message{
          start_line: %RequestLine{method: :register}
        }
  def register(account = %Account{}, cseq) do
    %Message{
      start_line: RequestLine.new(:register, "#{account.uri.scheme}:#{account.ip}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.ip}", account.uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from:
          {account.display_name, URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"),
           %{"tag" => Message.create_tag()}},
        to:
          {account.display_name, URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"),
           %{}},
        contact: {account.display_name, URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"), %{}},
        expires: account.registration_timer,
        max_forwards: account.max_forwards,
        cseq: {cseq, :register},
        user_agent: "#{account.user_agent}",
        call_id: Message.create_call_id()
      }
    }
  end

  @spec ack(%Account{}, cseq :: non_neg_integer(), %Guppi.Call{}, ExSDP.t()) :: %Message{
          start_line: %RequestLine{method: :ack}
        }
  def ack(account, cseq, call, sdp_offer) do
    %Message{
      start_line: RequestLine.new(:ack, "#{call.to.uri.scheme}:#{call.from.ip}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.ip}", account.uri.port},
           %{"branch" => call.via.branch}}
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
      body: to_string(Guppi.Agent.Media.sdp(account, sdp_offer))
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
          nil
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

  defp contact(account) do
    {account.display_name, URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.ip}"), %{}}
  end

end
