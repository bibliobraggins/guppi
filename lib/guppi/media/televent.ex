defmodule Televent do
  @moduledoc """

    Event  encoding (decimal)
    _________________________
    0--9                0--9
    *                     10
    #                     11
    A--D              12--15
    Flash                 16

  """

  @type event :: <<_::5>>
  @type e :: <<_::1>>
  @type r :: <<_::1>>
  @type volume :: <<_::5>>
  @type duration :: <<_::16>>

  defstruct [
    :event,
    :e,
    :r,
    :volume,
    :duration
  ]

  @type t :: %__MODULE__{
          event: event(),
          e: e(),
          r: r(),
          volume: volume(),
          duration: duration()
        }

  @valid [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "*", "#", "A", "B", "C", "D", :flash]

  def process(input) do
    if Enum.member?(@valid, input) == true do
      case input do
        0 -> <<0::5>>
        1 -> <<1::5>>
        2 -> <<2::5>>
        3 -> <<3::5>>
        4 -> <<4::5>>
        5 -> <<5::5>>
        6 -> <<6::5>>
        7 -> <<7::5>>
        8 -> <<8::5>>
        9 -> <<9::5>>
        "*" -> <<10::5>>
        "#" -> <<11::5>>
        "A" -> <<12::5>>
        "B" -> <<13::5>>
        "C" -> <<14::5>>
        "D" -> <<15::5>>
        :flash -> <<16::5>>
      end
    end
  end
end
