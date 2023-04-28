defmodule Televent do
  @moduledoc """

    This module is a stub for now, but I hope to implement some sort of rfc2833 DTMF and hook detection logic.

    Probably want to use this as the place for converting between an event on the line and an internal message.

    Event    Hex    (decimal)
    _________________________
    0--9     0x00       0--9
    *        0x00         10
    #        0x00         11
    A--D     0x00     12--15
    Flash    0x00         16

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

  def process(input) do
    case input do
      "0" -> struct(__MODULE__, [event: <<0::5>>, ])
      "1" -> struct(__MODULE__, [event: <<1::5>>, ])
      "2" -> struct(__MODULE__, [event: <<2::5>>, ])
      "3" -> struct(__MODULE__, [event: <<3::5>>, ])
      "4" -> struct(__MODULE__, [event: <<4::5>>, ])
      "5" -> struct(__MODULE__, [event: <<5::5>>, ])
      "6" -> struct(__MODULE__, [event: <<6::5>>, ])
      "7" -> struct(__MODULE__, [event: <<7::5>>, ])
      "8" -> struct(__MODULE__, [event: <<8::5>>, ])
      "9" -> struct(__MODULE__, [event: <<9::5>>, ])
      "*" -> struct(__MODULE__, [event: <<10::5>>, ])
      "#" -> struct(__MODULE__, [event: <<11::5>>, ])
      "A" -> struct(__MODULE__, [event: <<12::5>>, ])
      "B" -> struct(__MODULE__, [event: <<13::5>>, ])
      "C" -> struct(__MODULE__, [event: <<14::5>>, ])
      "D" -> struct(__MODULE__, [event: <<15::5>>, ])
      "F" -> struct(__MODULE__, [event: <<16::5>>, ])
    end
  end
end
