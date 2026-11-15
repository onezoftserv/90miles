# Proposal

## Why

The owner asked on 2026-11-14 whether the HUD and inventory should be improved, after the art and HUD design pass found that every UI box is a hard rectangle in one of four unrelated looks, all off the master palette:
- the 75% navy HUD panel;
- Kenney's tan panel;
- the cream note card;
- Kenney's cyan buttons.

The pass also found readability defects:
- meter labels sit on pastel fills (cream on Energía is 1.47:1);
- Salud is the last of six equal rows;
- slot digits cover the icons;
- black icon rims vanish on the navy slot (1.41:1);
- the teammate list can run off the right edge;
- the pause menu has no window;
- the menus' pixel font drops word gaps ("Fin delviaje").

The owner chose the recommended answers on 2026-11-14:
- Q8 (a): dark rounded GBA windows for the HUD and cream paper windows for notes, all in the game palette;
- Q9 (a): 94% opaque;
- Q10 (a): a label column with thin bars, Salud first;
- Q11 (a): keep today's slots, with small digits and the key shown only on the selected slot;
- Q16 (a): fix the menu word spacing now and choose one pixel font later.

## What Changes

**One window kit in the master palette** (ui-shell "Shared theme"; art-pass "Master palette")
- A new art recipe, `tools/art/ui.py`, builds every UI 9-slice from palette colours with whole alpha:
  - the dark HUD window, its thin form and its tab;
  - the cream paper window;
  - the menus' paper panel;
  - the slot well and the selected slot;
  - the buttons and the focus ring;
  - the line edit, the check box, the dropdown arrow, the scroll bar and the popup's radio marks;
  - a 3×5 digit atlas.
- Corners are rounded by a stepped pixel. Each window has a 1 px dark outline and a light top-left, dark bottom-right bevel.
- `game_theme.tres` and `HudStyle` move to palette colours in one step. HUD windows are 94% opaque.
- Kenney's three UI files leave `assets/art/ui/`, and art-pass's exemption for that folder ends: every UI image is on the palette.
- Menus use a Pixelify Sans variation with wider word spaces. The single pixel font stays a later decision (Q16).

**HUD panels in the kit** (ui-shell "HUD layout")
- Meters (Q10, route B):
  - one dark window at (4,4), at most 132 px wide, so it stays clear of the secret cay's note label at x 140;
  - each row a strict grid: a label column, a thin pre-shaded bar on the meter's own ramp at a fixed x, and the value;
  - the bar's edge pixel shows a half-filled column in the ramp's shade colour;
  - the order is Salud, Sed, Hambre, Calor, Energía, Ánimo;
  - a label turns a steady orange at the warning step and alert red at the critical one;
  - the critical pulse moves off the label onto the bar's outline and the value;
  - status rows such as Sangrando show only while they apply.
- The day phase, the watching line and the quick-chat wheel move onto dark windows.
- The interact prompt, the item line, the refusal notice and the weight move onto thin windows, which keep their rects.
- Teammate list:
  - right-anchored at the view's right edge, so it can no longer run off-screen;
  - one block per teammate: the full name, then a clothing-colour chip, a small health bar and the state word;
  - it stays clear of the day phase, the sign note and the note label.
- The sign note becomes a cream paper window at the same place.
- Pause and host-lost show in a centred dark window with a title tab.
- Damage-feedback's cues fit inside the kit. It merges first, and this change re-fits its nodes rather than redesigning them:
  - the lost and gained slices on each bar;
  - the drain glow;
  - the shake;
  - the edge flash;
  - the item-use change floats ("+15 Sed");
  - the effect line on the notice row;
  - the wasted-use refusals.

**Hotbar** (inventory-hud "Inventory strip", "Slot contents"; Q11 a)
- The slots keep their 26×26 rects.
- Each slot is a recessed grey well, so black icon rims read at 5.32:1.
- The selected slot has a yellow and orange ring.
- The icon sits at (5,4). The count is drawn in small 3×5 digits bottom-right, and never over the icon.
- The slot key shows only on the selected slot, and only while the keyboard is the last device used.
- A tool's uses left turn orange on its last use.
- A slot whose use the use button would refuse right now is dimmed, never hidden. An item with no use is never dimmed.
- Resting the mouse on a slot shows a delayed tooltip with the item's name and verb.
- These ideas come from the owner's reference pass (SPD, Brogue, DCSS, DST). Its rejected ideas are recorded in design D1: auto-sorting, keys on every slot, empty-stack placeholders and a cursor "hand" slot.

**Menus** (ui-shell "Shared theme", new "Menu windows")
- Paper panels with even edges replace the tan panel with its stretched ticks.
- Palette buttons with a bevel, and a focus ring that keeps the button's stepped corner.
- Centred content, with room under a focused button.
- Error lines in cream on a red band.
- The kit's check box, dropdown arrow, popup and scroll bar.
- The colour overrides in five shell scenes are deleted.

**Readable text** (ui-shell, new "Readable HUD and menu text")
- Steady text is 4.5:1 or more against the fill under it. The alert red is the one exception, at 4.15:1 on the dark window; it is used only for short alert words and pulsing values.
- The HUD stays Press Start 2P at 8 px, and menus Pixelify Sans at 16 and 32 px.

**Not in this change** (each its own later change):
- lifting the prompt over the local head (design pass C29);
- sizing the craft list to its rows, with a needs block headed by the recipe (C31);
- the last-stand band (C32);
- per-vessel lash phrases (HU10, crossing);
- the padded hotbar alternative (Q11 b).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ui-shell`:
  - MODIFIED "Shared theme": the window kit in the palette, 94% HUD windows, the menu word spacing;
  - MODIFIED "HUD layout": the label column and thin bars with Salud first, the meters' budget, and the right-anchored teammate blocks;
  - ADDED "Readable HUD and menu text";
  - ADDED "Pause and host-lost windows";
  - ADDED "Menu windows".
- `inventory-hud`:
  - MODIFIED "Inventory strip": the strip window and the slot wells;
  - MODIFIED "Slot contents": the icon place, the small digits, the last use in orange, the dimmed slots, the key on the selected slot only, the two-colour selection ring;
  - ADDED "Slot tooltip".
- `survival-meters`: MODIFIED "HUD bars": Salud first, and each label left of its bar rather than inside it.
- `art-pass`: MODIFIED "Master palette": the `art/ui/` exemption ends.

## Impact

**New files**
- Art: `tools/art/ui.py`, `tools/art/ui_kit.json` and `tools/art/test_ui.py`. The built PNGs go in `game/assets/art/ui/`, with an own-work `License.txt` that replaces Kenney's.
- `game/assets/fonts/menu_font.tres`, a FontVariation.
- `game/scripts/ui/hud_digits.gd` (`HudDigits`), which draws the 3×5 digits.

**Edited files**
- `game/scenes/ui/theme/game_theme.tres` and `game/scripts/ui/hud_style.gd`.
- `game/scenes/ui/meter_bar.gd` and `.tscn`, and `meters_hud.tscn`: the rows, the order and the ramps.
- `game/scripts/ui/strip_slot.gd`, and `inventory_strip.gd` and `.tscn`.
- `run_hud.gd` and `.tscn`: the teammate blocks.
- `interact_prompt.gd`: its labels move to y 1.
- `pause_menu.tscn`, `host_lost_screen.tscn` and `quick_chat_wheel.gd`.
- `name_tag.gd`: palette colours.
- The shell scenes: title, settings, lobby, join, credits, summary, and `sea.gdshader`'s colours.

**Tests**
- Updated:
  - `test_theme.gd`, `test_meters_hud.gd`, `test_inventory_strip.gd`, `test_run_hud.gd`, `test_sign_note.gd`, `test_credits_screen.gd`;
  - `test_art_tracked.gd`: the `ui/` exemption goes;
  - `test_art_credits.gd`, if the Pixel UI Pack line goes.
- New tests:
  - layout rects;
  - contrast;
  - font sizes;
  - the 1-player HUD;
  - the teammate list, host plus client.

**Credits:** `game/assets/CREDITS.md` and the credits data, if no Kenney UI file stays tracked.

**Not touched:** the simulation, networking, saves, the HUD text file's lines, and any rect the specs pin:
- the strip at y 330 to 356;
- the item line, the notice and the weight;
- the phase at (260,4);
- the sign note at (200,22);
- the craft list at (4,162);
- the prompt bounds.

**Order:** build after `damage-feedback` merges, because both edit `meter_bar` and `meters_hud`.
