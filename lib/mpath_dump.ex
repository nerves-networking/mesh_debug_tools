# SPDX-FileCopyrightText: 2020 Connor Rigby
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule MeshDebugTools.MpathDump do
  def collect(ifname) do
    [{["interface", ^ifname, "mac_address"], mac}] =
      VintageNet.match(["interface", ifname, "mac_address"])

    [{["interface", ^ifname, "addresses"], addresses}] =
      VintageNet.match(["interface", ifname, "addresses"])

    ipv4_address =
      Enum.find_value(addresses, fn
        %{family: :inet, address: address} ->
          :inet.ntoa(address)

        _ ->
          false
      end)

    {station_dump, 0} = System.cmd("iw", ["dev", ifname, "station", "dump"])
    {mpath_dump, 0} = System.cmd("iw", ["dev", ifname, "mpath", "dump"])
    mpath_dump = screenscrape_mpath_dump(mpath_dump)
    station_dump = screenscrape_station_dump(station_dump)

    info = %{
      ifname: ifname,
      mac: mac,
      station_dump: station_dump,
      mpath_dump: mpath_dump,
      ipv4_address: ipv4_address
    }

    build(info)
  end

  def build(info) do
    me = info.mac

    hop_conns =
      Enum.map(
        info.mpath_dump,
        fn
          %{dest: dest, next: "00:00:00:00:00:00"} = mpath ->
            "\"#{me}\" -- \"#{dest}\"[style=dotted label=\"sn:#{mpath.sn}\\nflags:#{mpath.flags}\"]"

          %{dest: same, next: same} = mpath ->
            "\"#{me}\" -- \"#{same}\"[label=\"sn:#{mpath.sn}\\nflags:#{mpath.flags}\"]"

          %{dest: dest, next: next} = mpath when dest != me ->
            "\"#{dest}\" -- \"#{next}\"[label=\"sn:#{mpath.sn}\\nflags:#{mpath.flags}\"]"

          %{dest: dest, next: next} = mpath when dest == me ->
            "\"#{dest}\" -- \"#{next}\"[label=\"sn:#{mpath.sn}\\nflags:#{mpath.flags}\"]"
        end
      )

    """
    graph \"#{info.mac}\" {
    \t"#{info.mac}"[color="blue"]
    \t#{Enum.join(hop_conns, "\n\t")}
    }
    """
  end

  defp screenscrape_mpath_dump(mpath_dump) do
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
  end

  defp screenscrape_station_dump(station_dump) do
    station_dump
    |> String.trim()
    |> String.split("Station ")
    |> tl()
    |> Enum.map(&String.split(&1, "\n"))
    |> Enum.map(fn [station | info] ->
      data =
        info
        |> Enum.map(fn line ->
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
  end
end
