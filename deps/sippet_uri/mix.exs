defmodule SippetUri.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :sippet_uri,
      version: @version,
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Sippet URI",
      docs: [logo: "logo.png"],
      source_url: "https://github.com/balena/elixir-sippet-uri",
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Docs dependencies
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # Test dependencies
      {:excoveralls, "~> 0.10", only: :test},
      {:credo, "~> 1.2", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    An Elixir SIP-URI parser fully compatible with RFC 3261.
    """
  end

  defp package do
    [
      maintainers: ["Guilherme Balena Versiani"],
      licenses: ["BSD"],
      links: %{"GitHub" => "https://github.com/balena/elixir-sippet-uri"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end
end
