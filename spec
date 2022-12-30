(atom(),
#{'__struct__' := 'Elixir.Sippet.Message',
'body' := 'nil' | binary(),
'headers' :=
#{atom() | binary() =>
bitstring() |
[{_, _} | {_, _, _} | {_, _, _, _} | map()] |
integer() |
{binary() | integer() | {_, _},
atom() | binary() | integer() | map()} |
{binary() | integer(), binary() | map(), map()} |
#{'__struct__' := 'Elixir.NaiveDateTime',
'calendar' := atom(),
'day' := pos_integer(),
'hour' := non_neg_integer(),
'microsecond' := {_, _},
'minute' := non_neg_integer(),
'month' := pos_integer(),
'second' := non_neg_integer(),
'year' := integer()}},
'start_line' :=
#{'__struct__' :=
'Elixir.Sippet.Message.RequestLine' |
'Elixir.Sippet.Message.StatusLine',
'version' := {integer(), integer()},
'method' => atom() | binary(),
'reason_phrase' => binary(),
'request_uri' =>
#{'__struct__' := 'Elixir.Sippet.URI',
'authority' := 'nil' | binary(),
'headers' := 'nil' | binary(),
'host' := 'nil' | binary(),
'parameters' := 'nil' | binary(),
'port' := 'nil' | char(),
'scheme' := 'nil' | binary(),
'userinfo' := 'nil' | binary()},
'status_code' => 1..1114111},
'target' := 'nil' | {atom() | binary(), binary(), integer()}})