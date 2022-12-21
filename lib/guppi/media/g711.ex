defmodule G711.Native do
  use Rustler, otp_app: :guppi, crate: :g711_native

  def ulaw_to_linear(_), do: :erlang.nif_error(:nif_not_loaded)
  def linear_to_ulaw(_), do: :erlang.nif_error(:nif_not_loaded)
  def compress_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)
  def expand_ulaw_buffer(_), do: :erlang.nif_error(:nif_not_loaded)

end
