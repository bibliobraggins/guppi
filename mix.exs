defmodule Guppi.MixProject do
  use Mix.Project

  def project do
    [
      app: :guppi,
      version: "0.1.0",
      elixir: ">= 1.12.3",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :crypto
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sippet, "~> 1.0.10"},
      {:phone, "~> 0.5.6"},
      {:ex_sdp, "~> 0.10.0"},
      {:jason, "~> 1.4"},
      {:socket, "~> 0.3.13"},
      {:poolboy, "~> 1.5.1"},
      {:ex_libsrtp, "~> 0.5.1"},
      {:membrane_common_c, "~> 0.13.0"},
      {:membrane_raw_audio_format, "~> 0.9.0"},
      {:membrane_udp_plugin, "~> 0.8.0"},
      {:membrane_realtimer_plugin, "~> 0.5.0"},
      {:membrane_audio_mix_plugin, "~> 0.10.0"},
      {:membrane_rtp_plugin, "~> 0.15.0"},
      {:membrane_rtp_opus_plugin, "~> 0.6.0"},
      {:membrane_opus_plugin, "~> 0.15.0"},
      {:membrane_portaudio_plugin, "~> 0.13.0"},
      {:membrane_file_plugin, "~> 0.12.0"},
      {:membrane_wav_plugin, "~> 0.7.0"},
      {:membrane_ffmpeg_swresample_plugin, "<= 0.16.0"},
      {:membrane_fake_plugin, "~> 0.8.0"},
      {:dialyxir, "~> 1.2"},
      {:g7xx_plugin, git: "https://github.com/bibliobraggins/g7xx_plugin.git"}

      # {:dep_from_hexpm, "~> 0.3.0"},
    ]
  end
end
