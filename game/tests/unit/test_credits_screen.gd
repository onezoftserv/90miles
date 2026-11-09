extends GutTest
## art-pass "Credits screen" and the ui-shell "Title screen" delta ("Credits offered offline"):
## offline, with no session, the title offers "Créditos" before "Salir"; its description names the
## art, the fonts and their licences; it opens a screen that lists every entry of credits.tres, the
## CC BY packs first with "CC BY 4.0", the licence's address and the source page, then the CC0 and
## OFL lines, in Pixelify Sans, scrolling when taller than the screen; "Volver" and Esc return to
## the title. Solo first-class: no network peer exists at any point (design.md D10, P8, K20).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_credits_screen_settings.cfg"
const SCREEN_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const CREDITS_INDEX: int = 4
const CC_BY: String = "CC BY 4.0"
const CC_BY_URL: String = "https://creativecommons.org/licenses/by/4.0/"
const PIXELIFY_SANS: String = "res://assets/fonts/PixelifySans[wght].ttf"
## Containers sort and labels wrap over the next frames.
const LAYOUT_FRAMES: int = 3


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	return shell


# No port, no peer, no run: what a solo player has on the title.
func _assert_offline(shell: GameShell, when: String) -> void:
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "the offline peer %s" % when)
	assert_false(NetManager.is_online(), "no network peer %s" % when)
	assert_null(shell.session, "no session %s" % when)


func _open_credits(shell: GameShell) -> CreditsScreen:
	(shell.screen as TitleScreen).buttons()[CREDITS_INDEX].pressed.emit()
	return shell.screen as CreditsScreen


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func _down_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_down"
	event.pressed = true
	return event


# The page as the screen's plain-text line shows it, without its scheme.
func _bare(url: String) -> String:
	return url.trim_prefix("https://").trim_prefix("http://")


func _index_of(texts: Array[String], part: String) -> int:
	for i: int in texts.size():
		if texts[i].contains(part):
			return i
	return -1


func test_the_title_offers_credits_before_quit_inside_the_screen() -> void:
	var shell := _shell()
	await wait_frames(LAYOUT_FRAMES)
	var buttons := (shell.screen as TitleScreen).buttons()
	assert_eq(buttons.size(), 6)
	assert_eq(buttons[CREDITS_INDEX - 1].text, "Ajustes")
	assert_eq(buttons[CREDITS_INDEX].text, "Créditos")
	assert_eq(buttons[CREDITS_INDEX + 1].text, "Salir")
	for button: Button in buttons:
		assert_true(SCREEN_RECT.encloses(button.get_global_rect()), "%s inside 640×360: %s" % [button.text, button.get_global_rect()])
	_assert_offline(shell, "on the title")


func test_focusing_credits_names_the_art_the_fonts_and_their_licences() -> void:
	var shell := _shell()
	var title := shell.screen as TitleScreen
	title.buttons()[CREDITS_INDEX].grab_focus()
	assert_string_contains(title.description.text, "arte")
	assert_string_contains(title.description.text, "fuentes")
	assert_string_contains(title.description.text, "licencias")
	_assert_offline(shell, "while Créditos has focus")


func test_pressing_credits_opens_the_credits_screen() -> void:
	var shell := _shell()
	var screen := _open_credits(shell)
	assert_eq(shell.flow, GameShell.Flow.CREDITS)
	assert_not_null(screen, "the credits screen")
	assert_eq(get_viewport().gui_get_focus_owner(), screen.back_button, "Volver has focus")
	_assert_offline(shell, "on the credits screen")


func test_the_cc_by_packs_come_first_with_the_licence_address_and_source() -> void:
	var shell := _shell()
	var texts := _open_credits(shell).entry_texts()
	var credits := ArtCredits.standard()
	assert_eq(texts.size(), credits.entries.size(), "one line per credits entry")
	var attribution: Array[ArtCredit] = []
	for entry: ArtCredit in credits.entries:
		if entry.attribution_required:
			attribution.append(entry)
	assert_eq(attribution.size(), 3, "DawnLike, Tiny, Tiny Heroes - Animals and Kyrise")
	for i: int in attribution.size():
		var entry := attribution[i]
		assert_string_contains(texts[i], entry.line_es)
		assert_string_contains(texts[i], CC_BY)
		assert_string_contains(texts[i], CC_BY_URL)
		assert_string_contains(texts[i], _bare(entry.source))
	var first_three := "\n".join(PackedStringArray(texts.slice(0, attribution.size())))
	for part: String in ["DawnLike", "DragonDePlatino", "paleta de DawnBringer", "Tiny, Tiny Heroes - Animals", "Kacper Woźniak", "Kyrise's Free 16x16 RPG Icon Pack"]:
		assert_string_contains(first_three, part)
	_assert_offline(shell, "while the credits show")


func test_then_the_cc0_and_ofl_lines_from_the_credits_data() -> void:
	var shell := _shell()
	var texts := _open_credits(shell).entry_texts()
	var last_courtesy: int = -1
	var first_font: int = texts.size()
	for entry: ArtCredit in ArtCredits.standard().entries:
		var at := _index_of(texts, entry.line_es)
		assert_gt(at, -1, "%s is listed" % entry.pack)
		if entry.attribution_required:
			continue
		assert_gt(at, 2, "%s after the CC BY packs" % entry.pack)
		assert_false(texts[at].contains(CC_BY_URL), "%s carries no CC BY address" % entry.pack)
		if entry.licence.begins_with("SIL OFL"):
			first_font = mini(first_font, at)
		else:
			last_courtesy = maxi(last_courtesy, at)
	assert_lt(last_courtesy, first_font, "the CC0 packs before the OFL fonts")
	assert_string_contains(texts[_index_of(texts, "MetroCity")], "(CC0)")
	assert_string_contains(texts[_index_of(texts, "Pixelify Sans")], "SIL OFL 1.1")


func test_a_modified_pack_is_marked() -> void:
	var shell := _shell()
	var texts := _open_credits(shell).entry_texts()
	for entry: ArtCredit in ArtCredits.standard().entries:
		var text := texts[_index_of(texts, entry.line_es)]
		assert_eq(text.contains("modificado"), entry.modified, entry.pack)


func test_the_list_is_in_pixelify_sans_inside_the_screen_and_scrolls() -> void:
	var shell := _shell()
	var screen := _open_credits(shell)
	await wait_frames(LAYOUT_FRAMES)
	assert_eq(screen.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "lines wrap, never scroll sideways")
	assert_gt(screen.list_height(), SCREEN_RECT.size.y, "taller than the screen")
	assert_gt(screen.list_height(), screen.scroll.size.y, "taller than its view")
	assert_true(SCREEN_RECT.encloses(screen.scroll.get_global_rect()), "the view inside 640×360")
	assert_true(SCREEN_RECT.encloses(screen.back_button.get_global_rect()), "Volver inside 640×360")
	for label: Label in screen.entry_labels():
		assert_eq(label.get_theme_font(&"font").resource_path, PIXELIFY_SANS, label.text)
		assert_eq(label.get_theme_font_size(&"font_size"), 16, label.text)
		assert_lte(label.get_global_rect().end.x, SCREEN_RECT.end.x, "%s fits across" % label.text)
	screen._unhandled_input(_down_event())
	await wait_frames(1)
	assert_gt(screen.scroll.scroll_vertical, 0, "the down key scrolls the list")
	screen.scroll.scroll_vertical = 100000
	await wait_frames(1)
	assert_gt(screen.scroll.scroll_vertical, int(SCREEN_RECT.size.y / 2.0), "scrolls to the end")
	_assert_offline(shell, "while scrolling")


func test_volver_returns_to_the_title() -> void:
	var shell := _shell()
	var screen := _open_credits(shell)
	screen.back_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(shell.screen is TitleScreen)
	_assert_offline(shell, "back on the title")


func test_esc_returns_to_the_title() -> void:
	var shell := _shell()
	var screen := _open_credits(shell)
	screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(shell.screen is TitleScreen)
	_assert_offline(shell, "after Esc")


func test_a_solo_player_reads_the_credits_then_plays() -> void:
	var shell := _shell()
	_open_credits(shell)
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "solo opens no port")
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
