defmodule MeshDebugTools.MixProject do
  use Mix.Project

  def project do
    [
      app: :mesh_debug_tools,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:iw, github: "connorrigby/elixir-iw"},
      {:vintage_net,
       github: "nerves-networking/vintage_net", branch: "main", override: true, start: false}
    ]
  end
end
