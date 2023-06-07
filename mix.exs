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
      {:jason, "~> 1.4"},
      {:dns, "~> 2.4"},
      {:ex_sdp, "~> 0.11.0"},
      {:thousand_island, "~> 0.6.7"},
      # {:socket, "~> 0.3.13"},
      # {:poolboy, "~> 1.5.1"},
      # {:phone, "~> 0.5.6"},

      # {:dep_from_hexpm, "~> 0.3.0"},
    ]
  end
end
