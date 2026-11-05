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


## Checks the project's autoload settings and every service's node under `root`.
static func check(root: Node) -> PackedStringArray:
	var errors := check_names(registered_autoloads())
	for service: StringName in NAMES:
		var setting: String = ProjectSettings.get_setting("autoload/%s" % service, "")
		if setting.is_empty():
			continue
		errors.append_array(check_entry(service, setting, root.get_node_or_null(NodePath(String(service)))))
	return errors


## Problems with one service: its autoload setting must be a singleton ("*" prefix) and its
## node must exist and run the script the setting points at.
static func check_entry(service: StringName, setting: String, node: Node) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not setting.begins_with("*"):
		errors.append("global service %s is not a singleton (autoload/%s = %s)" % [service, service, setting])
	if node == null:
		errors.append("global service not in the tree: %s" % service)
		return errors
	var expected := setting.trim_prefix("*")
	var script := node.get_script() as Script
	var actual := script.resource_path if script != null else "<no script>"
	if actual != expected:
		errors.append("global service %s runs %s, but autoload/%s points at %s" % [service, actual, service, expected])
	return errors
