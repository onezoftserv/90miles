extends GutTest
## core-services: exactly five global services, available from startup.

# The list from the core-services spec. Kept here on purpose, separate from CoreServices.NAMES,
# so changing the service set means changing the spec, the code and this test together.
const SPEC_SERVICES: Array[StringName] = [&"AudioManager", &"DialogueService", &"GameState", &"NetManager", &"WeatherManager"]


# Array[StringName].sort() does not sort by text, so compare sorted strings instead.
func _sorted(names: Array[StringName]) -> PackedStringArray:
	var texts := PackedStringArray(names)
	texts.sort()
	return texts


func test_code_list_matches_the_spec() -> void:
	assert_eq(_sorted(CoreServices.NAMES), _sorted(SPEC_SERVICES))


func test_project_registers_exactly_the_spec_services() -> void:
	assert_eq(_sorted(CoreServices.registered_autoloads()), _sorted(SPEC_SERVICES))


func test_check_reports_nothing_for_the_project() -> void:
	assert_eq(CoreServices.check(get_tree().root), PackedStringArray())


func test_check_names_an_unlisted_service() -> void:
	var errors := CoreServices.check_names(SPEC_SERVICES + ([&"ShopManager"] as Array[StringName]))
	assert_eq(errors.size(), 1, "one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "ShopManager")


func test_check_names_a_missing_service() -> void:
	var without_audio: Array[StringName] = SPEC_SERVICES.filter(func(n: StringName) -> bool: return n != &"AudioManager")
	var errors := CoreServices.check_names(without_audio)
	assert_eq(errors.size(), 1, "one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "AudioManager")


func test_every_service_is_in_the_tree() -> void:
	for service: StringName in SPEC_SERVICES:
		assert_not_null(get_tree().root.get_node_or_null(NodePath(service)), "%s is in the tree" % service)


func test_each_service_is_a_singleton_running_its_registered_script() -> void:
	for service: StringName in SPEC_SERVICES:
		var setting: String = ProjectSettings.get_setting("autoload/%s" % service, "")
		assert_true(setting.begins_with("*"), "%s is registered as a singleton" % service)
		var node: Node = get_tree().root.get_node_or_null(NodePath(service))
		var script := node.get_script() as Script if node else null
		assert_not_null(script, "%s has a script" % service)
		if script:
			assert_eq(script.resource_path, setting.trim_prefix("*"), "%s runs its registered script" % service)


func test_entry_check_names_wrong_registrations() -> void:
	var node := Node.new()
	node.set_script(load("res://scripts/autoload/audio_manager.gd"))
	assert_eq(CoreServices.check_entry(&"AudioManager", "*res://scripts/autoload/audio_manager.gd", node), PackedStringArray())
	assert_string_contains("\n".join(CoreServices.check_entry(&"AudioManager", "res://scripts/autoload/audio_manager.gd", node)), "not a singleton")
	assert_string_contains("\n".join(CoreServices.check_entry(&"AudioManager", "*res://scripts/autoload/net_manager.gd", node)), "runs res://scripts/autoload/audio_manager.gd")
	node.free()


# core-services: "Services hold no content data". Content values belong in .tres files, so a
# service script declares no constants and no exported (designer-tunable) properties.
func test_services_hold_no_content_values() -> void:
	for service: StringName in SPEC_SERVICES:
		var path: String = String(ProjectSettings.get_setting("autoload/%s" % service, "")).trim_prefix("*")
		var script := load(path) as Script
		assert_not_null(script, "%s script loads" % service)
		if script == null:
			continue
		assert_eq(script.get_script_constant_map().size(), 0, "%s declares no constants" % service)
		var exported: PackedStringArray = []
		for prop: Dictionary in script.get_script_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_EDITOR:
				exported.append(String(prop["name"]))
		assert_eq(exported, PackedStringArray(), "%s exports no tunable values" % service)


func test_game_state_owns_the_content_catalog() -> void:
	var game_state: Node = get_tree().root.get_node_or_null(^"GameState")
	assert_not_null(game_state)
	if game_state:
		assert_true(game_state.get(&"content") is ContentCatalog)
