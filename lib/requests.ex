defmodule Guppi.Requests do

  alias Sippet.Message, as: Message
  alias Sippet.URI, as: URI
  alias Sippet.Message.RequestLine, as: RequestLine
  #alias Sippet.Message.StatusLine, as: StatusLine

  def register(account = %Guppi.Account{}, cseq) do
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

  def ack(account = %Guppi.Account{}, cseq, call = %Guppi.Call{}) do
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
      body: Guppi.Helpers.local_sdp!(account)
    }
    |> IO.inspect()
  end

end
