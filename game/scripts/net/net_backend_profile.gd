class_name NetBackendProfile
extends Resource
## One backend's row in game/resources/net_backends.tres (net-platform "Backend choice"): what
## picks it, its tuning and its text. Capabilities stay in the backend's script.

@export var id: StringName = &""
## A path, not a Script: the script is loaded only when this backend is chosen, so loading the
## table never loads every backend.
@export_file("*.gd") var backend_script: String = ""
## The build feature tag that picks this backend. "" never auto-picks (ENet is the default).
@export var feature_tag: String = ""
## Seconds a join may take to reach the host before it fails as timed out, counted from the
## request. 0 keeps the transport's own timeout (ENet).
@export_range(0.0, 60.0, 0.5) var join_timeout_s: float = 0.0
## The host lobby's note on how others join, [es, en]; "%d" is the port opened. Empty keeps the
## lobby scene's own note.
@export var lobby_note: PackedStringArray = PackedStringArray()
