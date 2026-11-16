# Tasks

Build only after `damage-feedback` is merged into main (design D13). Each numbered group is one PR, green before the next starts. Groups 1 and 2, with group 3's thin rows (3.1 and 3.2), ship as one PR, because the kit's 3 px dark frame would otherwise draw over the text of the 10 px rows on main. Groups 1 and 2 ship together because `test_art_tracked.gd` requires every tracked PNG to be named by a scene or resource, and the kit's PNGs are first named by group 2's theme. For the same reason, the ramp strips join `ui_kit.json` in group 4 and the digit atlas in group 5. The groups follow the owner's answers of 2026-11-14 (Q8 a, Q9 a, Q10 a, Q11 a, Q16 a), and the owner's answers of 2026-11-15 (A1, B1, C1, D1, E1), recorded in design.md "Owner decisions".

The commands below run from the repo root, with the Godot 4.7.2 console binary:
- "Import" is `godot --headless --path game --import`, run twice on a fresh checkout.
- "Smoke" is `godot --headless --path game -s res://tests/smoke.gd`.
- "GUT" is `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.
- "Art tests" is `python -I -m unittest discover -s tools/art -p 'test_*.py'`.

## 0. Before building

- [x] 0.1 Rebase on main after `damage-feedback` merged. Read its merged `meter_bar.gd`/`.tscn`, `meters_hud.gd`/`.tscn`, `run_hud.gd` (`ChangeFloats`), `hud_notice.gd` (the effect line) and `HurtCueTuning.meter_colors`. Update design D5 if the node names or shapes differ from `dfa2a31`. Verify: D5 names only nodes that exist on main, and Import, Smoke and GUT pass before any edit.

## 1. The window kit (art-pass "Master palette"; design D2, D11)

- [x] 1.1 Tests first in `tools/art/test_ui.py`, on a fixture JSON and on the real `tools/art/ui_kit.json`. They check every piece in design D2's table:
  - its size and margin;
  - its outer corner pixel is transparent;
  - the inner diagonal of the stepped corner;
  - the bevel colours on each side;
  - every pixel in the palette with whole alpha;
  - `focus_ring` leaves its centre transparent;
  - `digits_3x5` holds two rows (cream and `#df7126`) of 12 cells of 5×7, each glyph 3×5 inside a 1 px outline;
  - `ramp_<meter>.png` has 1×5 rows in D4's order;
  - two runs give byte-identical files.

  Verify: they fail first (no `ui.py`), then pass.
- [x] 1.2 Write `tools/art/ui.py` and `tools/art/ui_kit.json` (stdlib and `png.py` only, colours by palette name). Build into `game/assets/art/ui/`, and replace `License.txt` with an own-work block in the format the art tools use. Verify: 1.1 passes and `python -I tools/art/check.py game/assets/art` is clean.
- [x] 1.3 Grep `game/` for any tracked use of `button_blue`, `button_blue_pressed`, `panel_tan` or any other Kenney UI file (a cursor too). The theme keeps the old files until group 2, which deletes them (2.2). Verify: the grep's hits are listed in the PR, and `test_art_tracked.gd` still passes with the kit beside the old files (the `ui/` exemption stays until 2.2).
- [x] 1.4 Import ×2, Smoke, GUT and Art tests pass.

## 2. Theme, colours, fonts, menus, pause and host-lost (ui-shell "Shared theme", "Readable HUD and menu text", "Pause and host-lost windows", "Menu windows"; design D3, D9, D10)

- [x] 2.1 Tests first:
  - `tests/unit/hud_contrast.gd` (`HudContrast`, WCAG luminance) and its unit test, against known pairs (`#ffedde`/`#222034` 13.91, `#d95763`/`#222034` 4.15, `#ffedde`/`#ac3232` 5.66).
  - Rewrite `test_theme.gd`:
    - HudPanel, HudPanelThin, HudNote, HudSlot, HudSlotSelected, Panel, Button (every state), LineEdit and focus are `StyleBoxTexture`s on kit files;
    - HudPanel's `modulate_color.a` is 0.94;
    - Button and title fonts are `menu_font.tres`, whose `base_font` is Pixelify Sans and whose space is at least 5 px at 16 px;
    - the theme depends on no Kenney file;
    - every font colour in the theme is a master palette colour;
    - `TooltipPanel` is `window_thin` and `TooltipLabel` is Press Start 2P 8 in `#ffedde`.
  - A new `test_menu_windows.gd`, solo and offline:
    - title, settings, join, lobby (offline host view), credits and summary instanced at 640×360;
    - every Label meets design D12's contrast pairs and font sizes;
    - a focused button and its ring lie inside the panel's inner rect;
    - the join error uses `ErrorLabel`.
  - A new case in `test_pause.gd`: the solo pause shows a `HudPanel` window centred in the view, with a "Pausa" tab and "Seguir" focused, inside 640×360.
  - A case in `test_hud_screens.gd` for host-lost in the same window.

  Verify: they fail first, then pass.
- [x] 2.2 Rewrite `game_theme.tres` to design D3 and point it at the kit. Then:
  - delete Kenney's three UI files and their `.import` files;
  - remove the `UI_DIR` exemption from `test_art_tracked.gd` (art-pass "Master palette"), and add a case: a fixture UI piece with one off-palette pixel fails and is named;
  - add `menu_font.tres` and the `PanelHeading`, `ErrorLabel` and `AlertLabel` variations.

  Verify: 2.1's theme tests pass, `test_art_tracked.gd` passes on the kit, and its new case fails as it should.
- [x] 2.3 Move `HudStyle` to D3's values (`SUN`, `CREAM`, `OUTLINE`, `TRACK`, and the new `ALERT` and `ORANGE`). In the same commit:
  - `test_inventory_strip.gd`'s `SUN_YELLOW` becomes `#fbf236`;
  - `MeterBar.PULSE_COLOR` becomes `HudStyle.ALERT`;
  - the Bleeding label moves to `AlertLabel`;
  - `QuickChatWheel` shows its selection as a `HudStyle.SUN` font colour on a `HudPanel` backdrop;
  - the name tag's strip goes to `#222034` and `#6abe30` (owner answer C1).

  Verify: `test_meters_hud.gd` (the bleeding red test still passes with `#d95763`), `test_quick_chat_wheel.gd`, the name tag tests and `test_inventory_strip.gd`, and crossing-gameplay's HUD tests if it is on main (its `CrossingHud` reads `HudStyle`), pass.
- [x] 2.4 Menus (D10):
  - delete the `#3b2a17` overrides in the shell scenes and the CheckBox overrides at `settings_screen.tscn:46-48`;
  - put headings on `PanelHeading`;
  - use `CenterContainer`s and the bottom margin in join and lobby;
  - switch the join error to `ErrorLabel` while it shows a failure;
  - put the run summary's rows in a `window_paper` inset inside its pinned rect;
  - move `sea.gdshader`'s sky, sea and sun to palette colours.

  Then update `test_credits_screen.gd:172` to assert the menu font's `base_font`. Verify: 2.1's menu tests, `test_title_screen.gd`, `test_lobby_screen.gd`, `test_run_summary.gd`, `test_credits_screen.gd` and `test_display_settings.gd` pass.
- [x] 2.5 Pause and host-lost (D9): a centred `HudPanel` with a `tab_dark` title tab; the LabelSettings go. Verify: 2.1's pause and host-lost cases pass, and `test_pause.gd` and `test_hud_screens.gd` still pass.
- [x] 2.6 Credits (D11, owner answer D1): drop the Pixel UI Pack from `game/assets/CREDITS.md`, the credits data and `test_art_credits.gd:27`, and change `docs/ASSETS.md`'s UI row to the own-work kit. Verify: `test_art_credits.gd` and `test_credits_screen.gd` pass.
- [x] 2.7 Capture the title, settings, join (failed), lobby (two players), credits and run summary at 2×, and the solo pause. Save them in `docs/ui-shell/` as `kit_*.png`, beside the before captures this change's docs PR added. Verify: the files exist and each shows the paper panel, palette buttons, the focus ring keeping its corner, and visible word gaps ("Fin del viaje").
- [x] 2.8 Import ×2, Smoke, GUT and Art tests pass.

## 3. HUD windows and thin rows (ui-shell "Shared theme", "HUD layout"; inventory-hud "Inventory strip"; design D8)

- [x] 3.1 Tests first in a new `test_hud_windows.gd`. It uses a solo, offline `RunHud` on the sandbar with exactly 1 player, and checks:
  - meters, phase and watching line are `HudPanel`s;
  - the prompt, item line, notice and weight are `HudPanelThin`s, and their rects are unchanged (notice (120,306,400,10), item line (153,318)–(487,328), weight (491,339)–(591,349));
  - the strip's backdrop draws inside y 329 to 358 and x 151 to 489;
  - the sign note is `HudNote` at (200,22), 240 wide;
  - each prompt label sits at `10 × line + 1`;
  - the craft list's and sign note's first label is at y 3 or more inside their windows;
  - every Label in the run HUD is Press Start 2P at 8 px;
  - each text and fill pair passes D12.

  Verify: it fails first, then passes.
- [x] 3.2 Apply the variations:
  - `HudPanelThin` on `ItemLinePanel`, `WeightPanel`, `HudNotice`'s panel and the prompt's panel;
  - the strip `Panel` as a `HudPanelThin` with expand margins 2/1/2/2.

  Move `InteractPrompt`'s labels to y 1 per line. Verify: 3.1, `test_interact_prompt.gd`, `test_prompt_placement.gd`, `test_inventory_strip.gd`, `test_craft_list.gd` and `test_sign_note.gd` pass, with the sign note's 7:1 still met (13.91:1).
- [x] 3.3 Fit damage-feedback's effect line to the notice row's thin window (D5), and check its cut at 50 characters still fits 400 px. Verify: damage-feedback's effect-line tests pass unchanged.
- [x] 3.4 The crossing HUD strip (design D14), if crossing-gameplay's `CrossingHud` is on main; otherwise skip it and note it for that later change. (Skipped on 2026-11-15: `CrossingHud` was not on main; its stage-2 colours follow `HudStyle` by themselves, and the restyle is noted in `TASKS.md` for crossing-gameplay.) Tests first: in the crossing HUD's own test, or `test_hud_windows.gd` for a solo raft crossing with exactly 1 player, offline, check:
  - its panel is a `HudPanel` and each line a `HudPanelThin`;
  - the strip's track and marker are palette colours;
  - the integrity steps cream, orange, alert at half and a quarter;
  - its rect stays inside x 137 to 501 and clear of the meters and the teammate list.

  Then restyle it, leaving its rect, texts and timing as they are. Verify: these checks and crossing-gameplay's HUD tests pass.
- [x] 3.5 Capture the solo HUD at 2× and 3× on sand and over deep water, the prompt with the hold ring, the sign note and the craft list. Save them as `docs/inventory-hud/kit_*.png` and `docs/ui-shell/kit_hud_*.png`. Verify: no window is square-cornered and no panel covers the centre.
- [x] 3.6 Import ×2, Smoke, GUT and Art tests pass.

## 4. Meters and teammates (survival-meters "HUD bars"; ui-shell "HUD layout", "Readable HUD and menu text"; design D4, D5, D7)

- [x] 4.1 Tests first. In `test_meters_hud.gd`:
  - ORDER becomes Salud, Sed, Hambre, Calor, Energía, Ánimo;
  - each label's rect lies left of its bar box, and the value lies right of it;
  - no label pixel overlaps a bar;
  - the window lies inside (4,4)–(136,90), with and without Sangrando;
  - the bar box is 40×7 with a 38×5 fill;
  - a value of 1 still fills 1 px;
  - each label's colour is cream above 50, `#df7126` at 50 or less and `#d95763` at 25 or less (heat: 50 and 75 or more), and never pulses;
  - critical thirst lerps the bar outline and the value colour only;
  - the edge column at values 1, 50 and 99 (0.38, 19 and 37.62 px): one shade column, 19 full columns, then 37 full columns plus one more, since the remainder is at least half a pixel;
  - the Calor tick sits at 75;
  - each fill uses its `ramp_<meter>.png`;
  - `fill_color` equals the ramp's base.

  Add the solo case: with exactly 1 player, offline, `NetManager.start_solo()`, the rows read Salud first, and thirst 40 with heat 60 turns only "Sed" and "Calor" orange.

  Verify: they fail first, then pass.
- [x] 4.2 Rebuild `meter_bar.tscn` and `meter_bar.gd` to D4: a label column with its colour steps (`WARN_LOW` and `WARN_HEAT` beside the critical constants), the `Bar` ProgressBar with ramp StyleBoxTextures and the `Edge` column, the value, the outline pulse, and `fill_color` kept as the ramp base. Move `Health` first in `meters_hud.tscn`, and set rows to 10 px with no separation. Re-fit damage-feedback's `Lost`, `Gain` and `Glow` and the shake to D5, and set `HurtCueTuning.meter_colors` to the six ramp bases. Verify: 4.1 and damage-feedback's `test_hurt_screen.gd`, its float and solo tests, and `test_run_hud.gd` pass.
- [x] 4.3 Tests first, for the teammate blocks:
  - In `test_run_hud.gd`:
    - the panel is right-anchored, with its right edge at 636;
    - three teammates fit inside x 502 to 636 and y 4 to 90;
    - a 16-character name shows whole;
    - "Desconectado", "Caído" and "Muerto" show with D7's colours;
    - each chip shows the teammate's `look_slot` base colour;
    - the bar fills to health;
    - `teammate_rows()` still returns "<name> <health> <state>";
    - with exactly 1 player, offline, there is no block.
  - In `test_sign_note.gd`'s three-teammate case: the note clears the new panel.
  - In `test_compass_needle.gd`'s check: the needle clears the panel.

  Verify: they fail first, then pass.
- [x] 4.4 Write `scenes/ui/teammate_block.tscn` and its script (D7), and make `RunHud.refresh` keep one block per teammate. Verify: 4.3 passes.
- [x] 4.5 Host plus client, in-process with `NetHarness`: extend `test_dropped_teammate_net.gd`, or add `test_teammate_blocks_net.gd`. It checks:
  - the client's block for the host and the host's block for the client show the right name, chip colour, bar and state word;
  - a dropped client reads "Desconectado" on the host;
  - a late joiner sees the same.

  Verify: it passes, and the GUT total stays under CI's 300 s.
- [x] 4.6 Two processes: run host and client on one machine, as CLAUDE.md asks for any HUD change seen in co-op. Use the existing manual co-op runner, or a `tests/manual/teammate_blocks_run.gd` on a free UDP port. The client is named with 16 characters; it drops, then rejoins. Capture the host's top-right at 3× into `docs/ui-shell/kit_teammates_x3.png`. Verify: both processes report their checks and no engine errors, and the capture shows the whole name and "Desconectado".
- [x] 4.7 Capture the solo meters at 3×, with thirst at 20 (pulsing) and with health being hit (damage-feedback's chunk). Save them as `docs/ui-shell/kit_meters_*.png`. Verify: the labels are cream on the window and Salud is first.
- [x] 4.8 Import ×2, Smoke, GUT and Art tests pass.

## 5. Hotbar (inventory-hud "Slot contents"; design D6)

- [x] 5.1 Tests first. In `test_inventory_strip.gd`:
  - the slot draw order;
  - the icon at (5,4);
  - the count's glyph pixels never inside (5,4)–(20,19), for 1-, 2- and 3-digit counts;
  - the key only on the selected slot while the keyboard is the device;
  - pressing 4 moves the key to slot 4;
  - no key on a gamepad;
  - "-" and "=" draw for slots 11 and 12;
  - the selected slot uses `HudSlotSelected`;
  - black icon rims reach 5:1 or more against `slot_well`'s fill.

  Replace the old three-row test at lines 133-150. A new `test_hud_digits.gd` covers `HudDigits` alignment and pitch. Keep the solo case (exactly 1 player, offline): a strip holding seven items.

  Verify: they fail first, then pass.
- [x] 5.2 Tests first, in a new `test_strip_dimming.gd`, solo and offline with exactly 1 player:
  - a knife with 1 use left draws its "1" from the orange row, and a lighter with 20 draws from the cream row;
  - on the raft crossing a rain cup's slot is dimmed with its icon visible, and driftwood (no use) is not;
  - a coconut with no blade is dimmed, and stops being dimmed after a knife pickup, with thirst at 50;
  - an empty slot is never dimmed;
  - dimming is worked out again on inventory, meter, status and state changes, and not every frame (a counter on the recompute stays at 0 over 60 idle frames);
  - `tooltip_text` reads "Coco · Beber" for a coconut, the name alone for driftwood, and "" for an empty slot, while selecting nothing and taking no focus.

  Verify: they fail first, then pass.
- [x] 5.3 Write `scripts/ui/hud_digits.gd`, then change `StripSlot`:
  - the icon at (5,4);
  - `HudDigits` for the count and the key, with the Labels kept as hidden text holders;
  - the orange row for the last use;
  - `dimmed` drawn at the craft list's `DIM`;
  - `tooltip_text`.

  In `InventoryStrip`:
  - show the key only while a slot is selected, and re-show keys on a selection change;
  - recompute dimming from `UsePlan.choose`, `UsePlan.actor_reason` and `ItemUser.check` on the change signals.

  Verify: 5.1, 5.2, `test_inventory_strip_net.gd` and `test_inventory_hud_solo_run.gd` pass.
- [x] 5.4 Capture the solo strip at 3×:
  - seven items;
  - the selected slot with its key;
  - a 40-stack;
  - a tool on its last use;
  - a dimmed coconut with no blade;
  - a tooltip.

  Save it as `docs/inventory-hud/kit_strip_x3.png`. Verify: no digit covers an icon, the black rims read on the wells, and the dimmed icon is still recognisable.
- [x] 5.5 Import ×2, Smoke, GUT and Art tests pass.

## 6. Docs and the whole run

- [x] 6.1 Update the docs:
  - `docs/GAME_DESIGN.md`, where it describes the HUD (meters order and look, the hotbar keys);
  - `docs/ASSETS.md` (the UI kit as own work, built by `tools/art/ui.py`);
  - `TASKS.md`: tick this change and list the follow-ups (C29 prompt over the head, C31 craft window, C32 last stand, HU10 vessel phrases, the meter rate arrows of owner answer E1).

  Verify: the docs name only behaviour in the specs.
- [x] 6.2 Run `openspec validate hud-window-kit --strict`, Import ×2, Smoke, GUT, Art tests and CI's headless game runs with 0 error lines. Verify: all pass.

## Workflow follow-up

- Archive with `/opsx:archive hud-window-kit` once the owner has seen the captures in play.
- Propose the follow-ups as their own changes: `ui-prompt-placement` (C29), `ui-craft-window` (C31), `ui-last-stand` (C32), the lash phrases (HU10, crossing), and `ui-meter-trends` (owner answer E1: rate arrows beside each meter, from damage-feedback's watches, with the bars at 34 px).
