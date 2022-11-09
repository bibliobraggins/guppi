defmodule Guppi.Register do
  alias Sippet.Message
  alias Sippet.Message.RequestLine

  def register(account) do
    uri = account.uri

    %Message{
      start_line: RequestLine.new(:register, "#{uri.scheme}:#{uri.host}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{account.uri.authority}", uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from: {"#{account.display_name}", account.uri, %{"tag" => Message.create_tag()}},
        to: {"#{account.display_name}", uri, %{}},
        cseq: {1, :register},
        user_agent: "Guppi/0.1.0",
        call_id: Message.create_call_id()
      }
    }
    |> Message.validate()
  end
end
