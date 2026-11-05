extends GutTest
## core-services: exactly five global services, available from startup.

# The list from the core-services spec. Kept here on purpose, separate from CoreServices.NAMES,
# so changing the service set means changing the spec, the code and this test together.
const SPEC_SERVICES: Array[StringName] = [&"AudioManager", &"DialogueService", &"GameState", &"NetManager", &"WeatherManager"]


func test_code_list_matches_the_spec() -> void:
	var names: Array[StringName] = CoreServices.NAMES.duplicate()
	names.sort()
	assert_eq(names, SPEC_SERVICES)


func test_project_registers_exactly_the_spec_services() -> void:
	var registered: Array[StringName] = CoreServices.registered_autoloads()
	registered.sort()
	assert_eq(registered, SPEC_SERVICES)


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


func test_game_state_owns_the_content_catalog() -> void:
	var game_state: Node = get_tree().root.get_node_or_null(^"GameState")
	assert_not_null(game_state)
	if game_state:
		assert_true(game_state.get(&"content") is ContentCatalog)
