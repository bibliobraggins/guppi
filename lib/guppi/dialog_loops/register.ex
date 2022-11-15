defmodule Guppi.Register do

  alias Sippet.Message, as: Message
  alias Sippet.Message.RequestLine, as: RequestLine

  def make_register(agent) do
    account = agent.account

    cseq = case Map.has_key?(account, :cseq) do
      true ->
        account.cseq+1
      false ->
        1
    end
    %Message{
      start_line: RequestLine.new(:register, "#{account.uri.scheme}:#{account.realm}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.uri.host}", account.uri.port}, %{"branch" => Message.create_branch()}}
        ],
        from: {"", Sippet.URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.realm}"), %{"tag" => Message.create_tag()}},
        to: {"", Sippet.URI.parse!("#{account.uri.scheme}:#{account.uri.userinfo}@#{account.realm}"), %{}},
        contact: {"", account.uri, %{}},
        expires: 3600,
        max_forwards: 70,
        cseq: {cseq, :register},
        user_agent: "Guppi/0.1.0",
        call_id: Message.create_call_id()
      }
    }
  end
end
