class_name NetBackendTable
extends Resource
## net-platform "Backend choice" and "Failure reasons": every backend's profile and the failure
## lines, in game/resources/net_backends.tres at the top of res://resources (beside
## hud_text.tres, so ContentCatalog.unregistered_folders() never sees a new folder). Lines are
## Spanish first with English beside, [es, en], read with HudText.pick(). Anything missing or
## unreadable falls back to ENet.

const PATH: String = "res://resources/net_backends.tres"
const ENET_ID: StringName = &"enet"
const ENET_SCRIPT: String = "res://scripts/net/enet_backend.gd"

# load_shipped() copies these fields one by one: a new @export must be copied there too.
@export var default_id: StringName = ENET_ID
@export var profiles: Array[NetBackendProfile] = []
## The reason's line per NetFailure.Reason, [es, en]. NONE and CANCELLED have none.
@export var failure_texts: Dictionary[NetFailure.Reason, PackedStringArray] = {}


# The static functions never check a value against this script's own type (`NetBackendTable.new()`,
# `as NetBackendTable`, or returning a loaded Resource as one): beside the typed
# Array[NetBackendProfile] export, that made a GUT process leak every loaded script at exit on
# 4.7.2 (2026-11-14). So they build with a bare new() and copy a loaded table's fields in.

## A copy of the table at `path` (the shipped one unless given), or enet_only() if it cannot be
## read or is not a NetBackendTable.
static func load_shipped(path: String = PATH) -> NetBackendTable:
	var loaded: Resource = load(path) if ResourceLoader.exists(path) else null
	if loaded == null or loaded.get_script() == null \
			or (loaded.get_script() as Script).get_global_name() != &"NetBackendTable":
		return enet_only()
	var table: NetBackendTable = new()
	table.default_id = loaded.get(&"default_id")
	table.profiles.assign(loaded.get(&"profiles"))
	table.failure_texts.assign(loaded.get(&"failure_texts"))
	return table


## The in-code fallback: one ENet profile, no texts.
static func enet_only() -> NetBackendTable:
	var table: NetBackendTable = new()
	table.profiles.append(_enet_profile())
	return table


static func _enet_profile() -> NetBackendProfile:
	var profile := NetBackendProfile.new()
	profile.id = ENET_ID
	profile.backend_script = ENET_SCRIPT
	return profile


## The profile with `profile_id`, or null.
func profile(profile_id: StringName) -> NetBackendProfile:
	for row: NetBackendProfile in profiles:
		if row != null and row.id == profile_id:
			return row
	return null


## The first listed profile whose feature tag is present (`has_feature` is OS.has_feature in the
## game), otherwise the default, otherwise ENet. Never null.
func pick(has_feature: Callable) -> NetBackendProfile:
	for row: NetBackendProfile in profiles:
		if row != null and not row.feature_tag.is_empty() and bool(has_feature.call(row.feature_tag)):
			return row
	var chosen := profile(default_id)
	return chosen if chosen != null else _enet()


## A new backend from `chosen`'s script, with its profile set. EnetBackend, with ENet's profile,
## if the script is missing or is not a NetBackend.
func create(chosen: NetBackendProfile) -> NetBackend:
	if chosen != null and _is_backend_script(chosen.backend_script):
		var backend := (load(chosen.backend_script) as Script).new() as NetBackend
		if backend != null:
			backend.profile = chosen
			return backend
	var fallback := EnetBackend.new()
	fallback.profile = _enet()
	return fallback


## The reason's line in `locale`, formatted with `args`; "" for NONE, CANCELLED or a missing line.
func failure_text(reason: NetFailure.Reason, args: Array = [], locale: String = "es") -> String:
	if reason == NetFailure.Reason.NONE or reason == NetFailure.Reason.CANCELLED:
		return ""
	return _format(HudText.pick(failure_texts.get(reason, PackedStringArray()), locale), args)


## `chosen`'s lobby note in `locale` with the port opened; "" when the profile has none.
func lobby_note(chosen: NetBackendProfile, port: int, locale: String = "es") -> String:
	if chosen == null:
		return ""
	return _format(HudText.pick(chosen.lobby_note, locale), [port])


func _enet() -> NetBackendProfile:
	var listed := profile(ENET_ID)
	return listed if listed != null else _enet_profile()


# Whether `path` is a script that extends NetBackend, checked before anything is instantiated.
static func _is_backend_script(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return false
	var current: Script = script
	while current != null:
		if current.get_global_name() == &"NetBackend":
			return true
		current = current.get_base_script()
	return false


# Formats `line` only when it has placeholders for exactly the arguments given, so a line and its
# arguments that do not match show the line as written instead of raising a format error.
static func _format(line: String, args: Array) -> String:
	if line.is_empty() or args.is_empty():
		return line
	var placeholders: int = line.count("%") - 2 * line.count("%%")
	if placeholders != args.size():
		return line
	return line % args
