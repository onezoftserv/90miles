extends GutTest
## net-platform "Platform backend", scenario "Transport stays in the seam". Outside
## res://scripts/net/, no game script names the ENet peer or a platform peer class, calls the
## NetPeers factory, or lists the machine's addresses. This enforces the rejection of DCSS's
## USE_TILE_WEB checks scattered across its UI (design.md, Reference games). Tests and helpers
## live under res://tests and are not scanned.
##
## The scan cannot pass by finding nothing: a planted name checks the matcher, and the walk is
## checked to reach the game's real scripts.

const ROOTS: PackedStringArray = ["res://scripts", "res://scenes"]
const SEAM: String = "res://scripts/net/"
## Scripts, and scenes in case one ever embeds a script.
const EXTENSIONS: PackedStringArray = ["gd", "tscn"]
## What only the seam may name.
const NAMES: PackedStringArray = [
	"ENetMultiplayerPeer",
	"SteamMultiplayerPeer",
	"EOSGMultiplayerPeer",
	"NetPeers.create_server",
	"NetPeers.create_client",
	"NetPeers.bound_port",
	"IP.get_local_addresses",
]

var _patterns: Dictionary[String, RegEx] = {}


func test_no_transport_outside_the_seam() -> void:
	var hits: PackedStringArray = []
	for path: String in _scanned():
		hits.append_array(_hits(path, FileAccess.get_file_as_string(path)))
	assert_eq(hits, PackedStringArray(), "transport names outside %s" % SEAM)


func test_the_scan_catches_a_planted_name() -> void:
	for planted_name: String in NAMES:
		var planted := "extends Node\n\n\nfunc _ready() -> void:\n\tvar x: Variant = %s\n" % planted_name
		assert_eq(_hits("res://planted.gd", planted), PackedStringArray(["res://planted.gd:5 %s" % planted_name]),
				"%s is caught" % planted_name)
	var two := "var a := ENetMultiplayerPeer.new()\nvar b := IP.get_local_addresses()\n"
	assert_eq(_hits("res://two.gd", two),
			PackedStringArray(["res://two.gd:1 ENetMultiplayerPeer", "res://two.gd:2 IP.get_local_addresses"]),
			"every hit, with its line")
	var clean := "\n".join(PackedStringArray([
		"var port: int = NetPeers.DEFAULT_PORT",
		"var most: int = NetPeers.MAX_PLAYERS",
		"var ok: bool = NetPeers.is_valid_address(address, port)",
		"var shown := NetPeers.lan_addresses(NetManager.host_info().addresses)",
		"var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()",
		"var target := NetJoinTarget.at_address(address, port)",
		"var MyENetMultiplayerPeerish := 0",
		"var request := NetManager.request_host(port)",
	]))
	assert_eq(_hits("res://clean.gd", clean), PackedStringArray(), "near misses are not hits")


func test_the_scan_reaches_the_game_scripts() -> void:
	var scanned := _scanned()
	assert_gt(scanned.size(), 100, "the walk found the game's scripts")
	assert_has(scanned, "res://scenes/shell/game_shell.gd")
	assert_has(scanned, "res://scenes/net/coop_session.gd", "res://scenes/net/ is not the seam")
	assert_has(scanned, "res://scripts/autoload/net_manager.gd")
	assert_has(scanned, "res://scenes/shell/lobby_screen.tscn")
	var in_seam: PackedStringArray = []
	for path: String in scanned:
		if path.begins_with(SEAM):
			in_seam.append(path)
	assert_eq(in_seam, PackedStringArray(), "the seam itself is not scanned")
	var seam_file := "res://scripts/net/net_peers.gd"
	assert_false(_hits(seam_file, FileAccess.get_file_as_string(seam_file)).is_empty(),
			"the seam does name the transport, so the matcher works on a real file")


## Every script and scene under ROOTS, outside the seam, sorted.
func _scanned() -> PackedStringArray:
	var found: PackedStringArray = []
	for root: String in ROOTS:
		found.append_array(_files_under(root))
	found.sort()
	return found


func _files_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if (dir_path + "/").begins_with(SEAM):
		return found
	for sub: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_files_under(dir_path.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir_path):
		if EXTENSIONS.has(file.get_extension()):
			found.append(dir_path.path_join(file))
	return found


## "path:line name" for every name on every line of `text`, in order.
func _hits(path: String, text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var lines := text.split("\n")
	for i: int in lines.size():
		for seam_name: String in NAMES:
			if _pattern(seam_name).search(lines[i]) != null:
				found.append("%s:%d %s" % [path, i + 1, seam_name])
	return found


# The name as a whole word: "NetPeers.create_server" but not "MyNetPeers.create_servers".
func _pattern(seam_name: String) -> RegEx:
	if not _patterns.has(seam_name):
		var pattern := RegEx.new()
		pattern.compile("\\b%s\\b" % seam_name.replace(".", "\\."))
		_patterns[seam_name] = pattern
	return _patterns[seam_name]
