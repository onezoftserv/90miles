extends GutTest
## coop-reconnect "Player identity": each install keeps a random player id and a separate
## secret across launches; malformed ones are replaced; loading never writes a file. Offline.

const PATH: String = "user://test_player_identity_settings.cfg"
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_new_identity_is_random_hex() -> void:
	var first := PlayerIdentity.create()
	var second := PlayerIdentity.create()
	assert_true(PlayerIdentity.is_hex(first.id, PlayerIdentity.ID_LENGTH), "32 hex characters")
	assert_true(PlayerIdentity.is_hex(first.secret, PlayerIdentity.SECRET_LENGTH), "64 hex characters")
	assert_true(first.is_valid())
	assert_ne(first.id, second.id)
	assert_ne(first.secret, second.secret)
	assert_ne(first.id, first.secret.left(PlayerIdentity.ID_LENGTH), "the secret is not derived from the id")


func test_the_form_is_checked() -> void:
	assert_false(PlayerIdentity.is_hex("", 32))
	assert_false(PlayerIdentity.is_hex("0123456789abcdef0123456789abcde", 32), "one short")
	assert_false(PlayerIdentity.is_hex("0123456789abcdef0123456789abcdeg", 32), "not hex")
	assert_false(PlayerIdentity.is_hex("0123456789ABCDEF0123456789ABCDEF", 32), "lowercase only")
	assert_true(PlayerIdentity.is_hex("0123456789abcdef0123456789abcdef", 32))
	assert_false(PlayerIdentity.from("abc", "def").is_valid())


func test_the_secret_is_compared_as_a_hash() -> void:
	var identity := PlayerIdentity.create()
	var digest := PlayerIdentity.hash_secret(identity.secret)
	assert_eq(digest.size(), 32, "SHA-256")
	assert_eq(digest, PlayerIdentity.hash_secret(identity.secret))
	assert_ne(digest, PlayerIdentity.hash_secret(PlayerIdentity.create().secret))


func test_an_install_keeps_its_player_id() -> void:
	var first := GameSettings.load_from(PATH)
	assert_true(first.identity.is_valid(), "made on first launch")
	assert_false(first.identity_stored, "not saved yet")
	assert_eq(first.save(), OK)
	assert_true(first.identity_stored)
	var again := GameSettings.load_from(PATH)
	assert_eq(again.identity.id, first.identity.id, "the same id on the next launch")
	assert_eq(again.identity.secret, first.identity.secret)
	assert_true(again.identity_stored)


func test_a_malformed_identity_is_replaced() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "id", "not-an-id")
	config.set_value("player", "secret", 42)
	config.save(PATH)
	var settings := GameSettings.load_from(PATH)
	assert_true(settings.identity.is_valid())
	assert_ne(settings.identity.id, "not-an-id")
	assert_false(settings.identity_stored)


func test_loading_writes_nothing() -> void:
	GameSettings.load_from(PATH)
	assert_false(FileAccess.file_exists(PATH), "load_from never creates the file")


func test_the_shell_saves_a_new_identity_at_once() -> void:
	NetManager.start_solo()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = PATH
	add_child_autofree(shell)
	assert_true(FileAccess.file_exists(PATH), "saved on the first launch")
	assert_eq(GameSettings.load_from(PATH).identity.id, shell.settings.identity.id)
