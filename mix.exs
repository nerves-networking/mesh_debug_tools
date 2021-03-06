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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:iw, github: "connorrigby/elixir-iw"},
      {:vintage_net,
       github: "nerves-networking/vintage_net", branch: "main", override: true, start: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
