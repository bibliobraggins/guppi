defmodule Guppi.Requests do
  require Logger

  alias Sippet.Message, as: Message
  alias Sippet.URI, as: URI
  alias Sippet.Message.RequestLine, as: RequestLine
  # alias Sippet.Message.StatusLine, as: StatusLine

  @moduledoc """
    here we store references to most if not all the request building.
  """

  def message(method, opts) do
    Kernel.apply(__MODULE__, method, [opts])
  end

  def register(opts) when is_list(opts) do
    %Message{
      start_line: RequestLine.new(:register, opts[:account].uri),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{opts[:account].ip}", opts[:account].uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from:
          {opts[:account].display_name,
           URI.parse!(
             "#{opts[:account].uri.scheme}:#{opts[:account].uri.userinfo}@#{opts[:account].ip}"
           ), %{"tag" => Message.create_tag()}},
        to:
          {opts[:account].display_name,
           URI.parse!(
             "#{opts[:account].uri.scheme}:#{opts[:account].uri.userinfo}@#{opts[:account].ip}"
           ), %{}},
        contact:
          {opts[:account].display_name,
           URI.parse!(
             "#{opts[:account].uri.scheme}:#{opts[:account].uri.userinfo}@#{opts[:account].ip}"
           ), %{}},
        expires: opts[:account].registration_timer,
        max_forwards: opts[:account].max_forwards,
        cseq: {opts[:cseq], :register},
        user_agent: "#{opts[:account].user_agent}",
        call_id: Message.create_call_id()
      }
    }
  end

  def ack(opts) when is_list(opts) do
    %Message{
      start_line:
        RequestLine.new(:ack, "#{opts[:call].from.uri.scheme}:#{opts[:call].from.uri.host}"),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{opts[:account].ip}", opts[:account].uri.port},
           %{"branch" => opts[:call].via.branch}}
        ],
        from:
          {"#{opts[:account].display_name}", opts[:call].to.uri, %{"tag" => Message.create_tag()}},
        to:
          {opts[:account].display_name,
           URI.parse!(
             "#{opts[:account].uri.scheme}:#{opts[:account].uri.userinfo}@#{opts[:account].ip}"
           ), %{}},
        contact: contact(opts[:account]),
        expires: opts[:account].refresh_timer,
        max_forwards: opts[:account].max_forwards,
        cseq: {opts[:call], :ack},
        user_agent: "#{opts[:account].user_agent}",
        call_id: opts[:call].id
      },
      body: opts[:sdp_offer]
    }
  end

  def subscribe(opts) when is_list(opts) do
    blf_uri = opts[:blf_uri]

    subscribe = %Message{
      start_line: RequestLine.new(:subscribe, blf_uri),
      headers: %{
        via: [
          {{2, 0}, :udp, {"#{opts[:account].ip}", opts[:account].uri.port},
           %{"branch" => Message.create_branch()}}
        ],
        from:
          {"#{opts[:account].display_name}", blf_uri, %{"tag" => Message.create_tag()}},
        to: {"", blf_uri, %{}},
        contact: contact(opts[:account]),
        event: "presence",
        accept: "application/dialog-info+xml",
        expires: opts[:account].subscription_timer,
        max_forwards: opts[:account].max_forwards,
        cseq: {opts[:cseq], :subscribe},
        user_agent: "#{opts[:account].user_agent}",
        call_id: "#{blf_uri.authority}_#{opts[:cseq]}"
      }
    }

    subscribe
  end

  def contact(account) do
    {"#{account.display_name}",
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
