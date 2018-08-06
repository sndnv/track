defmodule Track.MixProject do
  use Mix.Project

  def project do
    [
      app: :track,
      version: "1.0.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        qa: :test
      ],
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:poison, "~> 4.0.1"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.9.1", only: :test}
    ]
  end

  defp escript do
    [
      main_module: Track
    ]
  end

  defp aliases do
    [
      build: ["clean", "format", "deps.get", "compile", "escript.build"],
      qa: ["build", "coveralls.html"]
    ]
  end
end
