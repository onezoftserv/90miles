class_name NetHostInfo
extends RefCounted
## What the host's lobby shows about how others join (ui-shell "Lobby"), as the backend reports
## it when hosting is ready.

## ENet: the UDP port actually opened. 0 when the backend has no port.
var port: int = 0
## ENet: the LAN IPv4 addresses ("Tu IP: …"). Empty for a backend joined by invite.
var addresses: PackedStringArray = PackedStringArray()
