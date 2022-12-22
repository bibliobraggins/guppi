defmodule G711.Native do
  use Rustler, otp_app: :guppi, crate: :g711_native

  def ulaw_to_linear(_), do: :erlang.nif_error(:nif_not_loaded)
  def linear_to_ulaw(_), do: :erlang.nif_error(:nif_not_loaded)
  def compress_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)
  def expand_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  def ulaw_to_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)
  def alaw_to_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

  def alaw_to_linear(_), do: :erlang.nif_error(:nif_not_loaded)
  def linear_to_alaw(_), do: :erlang.nif_error(:nif_not_loaded)
  def compress_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)
  def expand_alaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

end
