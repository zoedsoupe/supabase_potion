defmodule Supabase.MixProject do
  use Mix.Project

  @version "0.5.1"
  @source_url "https://github.com/supabase-community/supabase-ex"

  def project do
    [
      app: :supabase_potion,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(e) when e in [:dev, :test], do: ["lib", "priv", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Supabase.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mime, "~> 2.0"},
      {:finch, "~> 0.16"},
      {:jason, "~> 1.4"},
      {:ecto, "~> 3.10"},
      {:mox, "~> 1.2", only: :test},
      {:ex_doc, ">= 0.0.0", runtime: false, only: [:dev, :prod]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      contributors: ["zoedsoupe"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/supabase_potion"
      },
      files: ~w[lib mix.exs README.md LICENSE]
    }
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp description do
    """
    Complete Elixir client for Supabase.
    """
  end
end
