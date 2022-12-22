defmodule G711.Native do
  use Rustler, otp_app: :guppi, crate: :g711_native

  @spec ulaw_to_linear(non_neg_integer()) :: integer()
  def ulaw_to_linear(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec alaw_to_linear(non_neg_integer()) :: integer()
  def alaw_to_linear(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec linear_to_ulaw(integer()) :: non_neg_integer()
  def linear_to_ulaw(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec linear_to_alaw(integer()) :: non_neg_integer()
  def linear_to_alaw(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec ulaw_to_alaw(non_neg_integer()) :: non_neg_integer()
  def ulaw_to_alaw(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec alaw_to_ulaw(non_neg_integer()) :: non_neg_integer()
  def alaw_to_ulaw(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec compress_ulaw_buffer(<<_::_*16>>) :: <<_::_*8>>
  def compress_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec expand_ulaw_buffer(<<_::_*8>>) :: <<_::_*16>>
  def expand_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec compress_alaw_buffer(<<_::_*16>>) :: <<_::_*8>>
  def compress_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec expand_alaw_buffer(<<_::_*8>>) :: <<_::_*16>>
  def expand_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec ulaw_to_alaw_buffer(<<_::_*8>>) :: <<_::_*8>>
  def ulaw_to_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  @spec alaw_to_ulaw_buffer(<<_::_*8>>) :: <<_::_*8>>
  def alaw_to_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

end
