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
      mod: {Guppi, []},
      extra_applications: [
        :logger,
        :crypto,
        :rustler,
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sippet, "~> 1.0"},
      {:socket, "~> 0.3"},
      {:dns, "~> 2.4.0"},
      {:ex_sdp, "~> 0.7.2"},
      {:jason, "~> 1.4"},
      {:rustler, "~> 0.26.0"},
      {:zigler, "~> 0.9.1"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
