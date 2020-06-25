defmodule MeshDebugTools.MpathDump do
  @nodes [
    "meshy-node-2142.local",
    "meshy-node-eb30.local",
    "meshy-node-7e4b.local",
    "meshy-node-fd86.local",
    "meshy-gateway-4877.local"
  ]

  def setup_nodes do
    case Node.start(:"console@meshy-controller.local") do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    true = Node.set_cookie(:meshy)

    for node <- @nodes do
      case Node.connect(:"meshy@#{node}") do
        true ->
          true

        false ->
          IO.puts "connecting to #{node}"
          cmd = [
            "-o",
            "StrictHostKeyChecking no",
            node,
            "use Toolshed; cmd(\"epmd -daemon\"); Node.start(:\"meshy@#{node}\"); Node.set_cookie(:meshy)"
          ]

          System.cmd("ssh", cmd, into: IO.stream(:stdio, :line))
          true = Node.connect(:"meshy@#{node}")
      end
    end

    :ok
  end

  def collect do
    :ok = setup_nodes()

    info =
      for hostname <- @nodes do
        node = :"meshy@#{hostname}"

        {mac, ifname} =
          case :rpc.call(node, VintageNet, :match, [["interface", "mesh0", "mac_address"]]) do
            [] ->
              [{["interface", "usbWifi0", "mac_address"], mac}] =
                :rpc.call(node, VintageNet, :match, [["interface", "usbWifi0", "mac_address"]])

              {mac, "usbWifi0"}

            [{["interface", "mesh0", "mac_address"], mac}] ->
              {mac, "mesh0"}
          end

        [{["interface", ^ifname, "addresses"], addresses}] =
          :rpc.call(node, VintageNet, :match, [["interface", ifname, "addresses"]])

        ipv4_address =
          Enum.find_value(addresses, fn
            %{family: :inet, address: address} ->
              :inet.ntoa(address)

            _ ->
              false
          end)

        {station_dump, 0} =
          :rpc.call(node, System, :cmd, ["iw", ["dev", ifname, "station", "dump"]])

        {mpath_dump, 0} = :rpc.call(node, System, :cmd, ["iw", ["dev", ifname, "mpath", "dump"]])

        mpath_dump =
          mpath_dump
          |> String.trim()
          |> String.split("\n")
          |> tl()
          |> Enum.map(&String.split(&1, " "))
          |> Enum.map(fn [dest, next, info] ->
            [_ifname, sn, metric, qlen, exptime, dtim, dret, flags] = String.split(info, "\t")

            %{
              dest: dest,
              next: next,
              sn: sn,
              metric: metric,
              qlen: qlen,
              exptime: exptime,
              dtim: dtim,
              dret: dret,
              flags: flags
            }
          end)

        station_dump =
          station_dump
          |> String.trim()
          |> String.split("Station ")
          |> tl()
          |> Enum.map(&String.split(&1, "\n"))
          |> Enum.map(fn [station | info] ->
            data =
              info
              |> Enum.map(fn(line) ->
                String.trim(line) |> String.split("\t")
              end)
              |> Enum.map(fn
                [key, "", value] ->
                  {String.trim(key) |> String.trim_trailing(":"), value}

                [key, value] ->
                  {String.trim(key) |> String.trim_trailing(":"), value}

                [keyvalue] ->
                  case String.split(keyvalue, ":", parts: 2) do
                    [key, value] -> {key, value}
                    [""] -> {nil, nil}
                    unknown -> raise("unknown value: #{inspect(unknown)}")
                  end
              end)
            |> Map.new()
            [station | _] = String.split(station, " ")
            {station, data}
          end)
          |> Map.new()

        %{
          node: node,
          ifname: ifname,
          mac: mac,
          station_dump: station_dump,
          mpath_dump: mpath_dump,
          ipv4_address: ipv4_address
        }
      end

    build(info)
  end

  @gateway :"meshy@meshy-gateway-4877.local"
  def build(infos) do
    for %{node: node} <- infos do
      # IO.inspect(node, label: "Ping")
      :rpc.call(@gateway, Node, :ping, [node])
    end

    gateway_info =
      Enum.find(infos, fn
        %{node: @gateway} -> true
        _ -> false
      end)

    # main_conns =
    #   Enum.map(gateway_info.station_dump, fn {station, _} ->
    #     "\"#{gateway_info.mac}\" -- \"#{station}\""
    #   end)

    # path_conns =
    #   Enum.flat_map(infos, fn %{mpath_dump: dump} ->
    #     Enum.map(dump, fn
    #       %{dest: same, next: same} -> ""
    #       %{dest: dest, next: next} ->
    #       "\"#{dest}\" -- \"#{next}\""
    #     end)
    #   end)

    hop_conns = Enum.map(gateway_info.mpath_dump,
      fn
        %{dest: dest, next: "00:00:00:00:00:00"} = info ->
        "\"#{gateway_info.mac}\" -- \"#{dest}\"[style=dotted label=\"sn:#{info.sn}\\nflags:#{info.flags}\"]"

        %{dest: same, next: same} = info ->
          "\"#{gateway_info.mac}\" -- \"#{same}\"[label=\"sn:#{info.sn}\\nflags:#{info.flags}\"]"

        %{dest: dest, next: next} = info when dest != @gateway ->
        "\"#{dest}\" -- \"#{next}\"[label=\"sn:#{info.sn}\\nflags:#{info.flags}\"]"
        #  <> "\n\t" <> "\"#{gateway_info.mac}\" -- \"#{dest}\""

        %{dest: dest, next: next} = info when dest == @gateway ->
          "\"#{dest}\" -- \"#{next}\"[label=\"sn:#{info.sn}\\nflags:#{info.flags}\"]"

      end)

    # gw_conns = Enum.map(gateway_info.mpath_dump,
    #   fn
    #     %{dest: dest, next: _next} ->
    #     "\"#{gateway_info.mac}\" -- \"#{dest}\""
    #   end)

    all_conns = hop_conns

    # labels =
    #   Enum.map(infos, fn
    #     %{mac: mac, node: @gateway = node} ->
    #       "\"#{mac}\" [color=\"blue\" label=\"#{mac}\\n #{node}\"]"

    #     %{mac: mac, node: node} ->
    #       "\"#{mac}\" [color=\"grey\" label=\"#{mac}\\n #{node}\"]"
    #   end)

    """
    graph \"#{gateway_info.mac}\" {
    \t"#{gateway_info.mac}"[color="blue"]
    \t#{Enum.join(all_conns, "\n\t")}

    }
    """
  end
end
