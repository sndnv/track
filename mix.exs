defmodule Track.MixProject do
  use Mix.Project

  def project do
    [
      app: :track,
      version: "1.0.0",
      elixir: "~> 1.7.2",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.travis": :test,
        qa: :test
      ],
      escript: escript(),
      docs: [
        main: "Track",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :table_rex]
    ]
  end

  defp deps do
    [
      {:poison, "~> 4.0.1"},
      {:elixir_uuid, "~> 1.2"},
      {:table_rex, "~> 2.0.0"},
      {:asciichart, "~> 1.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
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
      build: ["deps.get", "clean", "format", "compile", "escript.build"],
      qa: ["build", "coveralls.html"]
    ]
  end

  @github_url "https://github.com/sndnv/track"

  def package do
    [
      name: :track,
      description: "Simple time/task tracking terminal utility",
      files: ["lib", "mix.exs", "LICENSE", "README.md"],
      maintainers: ["Angel Sanadinov"],
      licenses: ["Apache 2.0"],
      links: %{
        "Github" => @github_url
      },
      source_url: @github_url,
      homepage_url: @github_url,
      docs: [
        main: "Track",
        extras: ["README.md"]
      ]
    ]
  end
end
