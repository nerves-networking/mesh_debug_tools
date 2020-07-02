# MeshDebugTools

## Mpath Dump

```elixir
iex()> MeshDebugTools.MpathDump,.collect("mesh0")) |> IO.puts()
graph "00:0f:02:36:51:4c" {
        "00:0f:02:36:51:4c"[color="blue"]
        "00:0f:02:36:51:4c" -- "00:0f:00:cf:e3:de"[label="sn:32830\nflags:0x15"]
        "00:0f:02:36:51:4c" -- "04:03:d6:d7:07:69"[style=dotted label="sn:0\nflags:0x0"]
        "00:0f:02:36:51:4c" -- "98:41:5c:17:38:3a"[style=dotted label="sn:0\nflags:0x0"]
}
```