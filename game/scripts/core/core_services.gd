class_name CoreServices
extends RefCounted
## The global services every scene and headless script can rely on (core-services spec).
## Changing this list needs a spec change; test_core_services.gd compares it with the spec.

const NAMES: Array[StringName] = [&"GameState", &"NetManager", &"WeatherManager", &"DialogueService", &"AudioManager"]


## Autoload names registered in the project settings.
static func registered_autoloads() -> Array[StringName]:
	var names: Array[StringName] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("autoload/"):
			names.append(StringName(key.trim_prefix("autoload/")))
	return names


## Unlisted and missing services in `registered`, compared with NAMES.
static func check_names(registered: Array[StringName]) -> PackedStringArray:
	var errors: PackedStringArray = []
	for service: StringName in registered:
		if not NAMES.has(service):
			errors.append("unlisted global service: %s (the core-services spec lists %s)" % [service, NAMES])
	for service: StringName in NAMES:
		if not registered.has(service):
			errors.append("missing global service: %s" % service)
	return errors


## Checks the project's autoload settings and that every service is in the tree under `root`.
static func check(root: Node) -> PackedStringArray:
	var errors := check_names(registered_autoloads())
	for service: StringName in NAMES:
		if root.get_node_or_null(NodePath(String(service))) == null:
			errors.append("global service not in the tree: %s" % service)
	return errors
