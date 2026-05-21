defmodule PasseurHass.MixProject do
  use Mix.Project

  def project do
    [
      app: :passeur_hass,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP tools for reading Home Assistant entity state via the REST API",
      package: package(),
      source_url: "https://github.com/jfim/passeur_hass"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PasseurHass.Application, []}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jfim/passeur_hass"}
    ]
  end

  defp deps do
    [
      {:anubis_mcp,
       git: "https://github.com/jfim/anubis-mcp.git",
       branch: "non-upstreamed-fixes",
       override: true},
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
