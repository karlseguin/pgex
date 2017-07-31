defmodule PgEx.Mixfile do
  use Mix.Project

   @version "0.0.1"

  def project do
    [
      app: :pgex,
      deps: deps(),
      name: "PgEx",
      elixir: "~> 1.4",
      version: @version,
      elixirc_paths: paths(Mix.env),
      consolidate_protocols: Mix.env != :test,
      description: "PostgreSQL Driver for Elixir",
      package: [
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/karlseguin/pgex"
        },
        maintainers: ["Karl Seguin"],
      ],
      docs: [
        canonical: "http://hexdocs.pm/pgex",
        source_ref: "v#{@version}", main: "PgEx",
        source_url: "https://github.com/karlseguin/pgex",
      ]
    ]
  end

  defp paths(:test), do: ["lib", "test/support"]
  defp paths(_), do: ["lib"]

  def application do
    [
      applications: []
    ]
  end

  defp deps do
    [
      {:poolboy, "~> 1.5.1"},
    ]
  end
end
