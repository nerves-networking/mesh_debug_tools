defmodule Mix.Tasks.MeshDebug.Mpath do
  @shortdoc "mix mesh_debug.mpath meshy-gateway-4877.local mesh0"
  @moduledoc """
  # Usage:
      mix mesh_debug.mpath meshy-gateway-4877.local mesh0
  """
  use Mix.Task

  def run([hostname, ifname]) do
    node = :"meshy@#{hostname}"
    {:ok, _} = Node.start(:"console@meshy-controller.local")
    true = Node.set_cookie(:meshy)
    true = Node.connect(node)

    {:ok, [{^node, :loaded, _}]} = IEx.Helpers.nl([node], MeshDebugTools.MpathDump)
    :rpc.call(node, MeshDebugTools.MpathDump, :collect, [ifname]) |> IO.puts()
  end
end
