# Design

## Context

Read on main `cb7834f`, 2026-11-14. The motivation is in proposal.md.

### The theme today (`game/scenes/ui/theme/game_theme.tres`)

- **StyleBoxFlats with square corners:**
  - `HudPanel` (`_afeyr`): navy `(0.04, 0.08, 0.13)` at 0.75, with a white border at 0.22.
  - `HudNote` (`_note`): cream `#f4efe0` with a navy border.
  - `HudSlot` and `HudSlotSelected`: a 1 px frame only, cream at 0.35 or `#ffcc00`, with no fill.
  - The LineEdit (`_7jsoh`).
  - The focus frame (`_8fmfx`).
- **Kenney 9-slices** in `assets/art/ui/`: `button_blue.png`, `button_blue_pressed.png` and `panel_tan.png`, used with STRETCH. The tan panel's tick marks stretch into 14×8 blocks.
- **Fonts:** HUD text is Press Start 2P at 8 px (`HudStyle.GLYPH_PX`, every character budget). Buttons and titles are Pixelify Sans at 16 and 32 px; at 16 px its space glyph is 3 px wide.

### Colours outside the theme

- **`HudStyle`** (`scripts/ui/hud_style.gd`): `SUN #ffcc00`, `CREAM #f4efe0`, `TRACK` (cream at 0.35) and `OUTLINE (0.04, 0.08, 0.13)`. None is a palette colour.
- **Code and scene overrides:**
  - `MeterBar.PULSE_COLOR`, and the Bleeding label `(0.9, 0.2, 0.2)`;
  - `QuickChatWheel.SELECTED_COLOR`;
  - five shell scenes with `#3b2a17` font colours;
  - `settings_screen.tscn:46-48`, which overrides the CheckBox's colours;
  - `pause_menu.tscn` and `host_lost_screen.tscn`, whose titles use LabelSettings rather than the theme.

### Panels and rects today

| Panel | Rect or rule today | Fixed by |
|---|---|---|
| Meters (`meters_hud.tscn`) | A `HudPanel` at (4,4) holding six `MeterBar` rows: a 96×10 ProgressBar with Label and Value children inside, 2 px apart, in the order Sed, Hambre, Calor, Energía, Ánimo, Salud, then the Sangrando tag | `test_meters_hud.gd` ORDER and LABELS; the 160×90 budget |
| Phase | (260,4)–(380,18) | `run_hud.tscn` |
| Teammates | `TeammatesPanel` at (520,4), grows right, one Label per teammate ("Papo 100 Caído") | `run_hud.gd` `refresh` |
| Needle | 24×24, top-centre under the phase | secret-cay |
| Note label | `NoteLabel` at (140,46), 360 px wide | secret-cay, a HudPanel |
| Sign note | (200,22), 240 px wide, up to 8 lines | `sign_note.gd` |
| Craft list | (4,162)–(244,302), `PADDING` (4,3) | `craft_list.gd` |
| Notice | (120,306), 400×10 | `hud_notice.gd` |
| Item line | (153,318)–(487,328) | `inventory_strip.tscn` |
| Strip | (153,330)–(487,356); slots 26×26, 2 px apart | inventory-hud |
| Weight | (491,339)–(591,349) | `inventory_strip.tscn` |
| Watching line | centred, 240×16, at y 334 | dead-spectate |
| Interact prompt | lines × 10 px, labels at y 0, inside (4,22)–(636,302) | `interact_prompt.gd` |

**`StripSlot`**
- 26×26.
- Three 8 px text rows: the key at (2,1), the letters at (1,9), the count at (1,17).
- The icon at (5,5). The count covers part of the icon (13 of the knife's 66 pixels).

### Constraints any new layout must keep

- **The secret cay's note label starts at x 140.** The design pass's 142 px meters window would end at x 146 and overlap it. This change therefore narrows the window (D4).
- **The sign note spans x 200 to 440 from y 22, and the note label x 140 to 500 from y 46.** A teammate list taller than one row must start right of x 500 (D7).
- **`damage-feedback` (branch `claude/damage-feedback-1cc261`, read at `dfa2a31`; every owner question answered; being built) adds:**
  - `Lost` and `Gain` ColorRects and a `Glow` Panel inside `MeterBar/Bar`;
  - a 1 px shake of the health bar;
  - a full-screen `HurtOverlay` in `MetersHud`;
  - a `ChangeFloats` control beside `Marks`;
  - an effect line on the notice row;
  - a wasted-use refusal.

  It moves and restyles nothing. This change builds only after it merges (proposal "Order"), and D5 re-fits those nodes.

### Captures and mocks (copied from the 2026-11-14 design pass)

Each PNG is at 2× unless its name says `_x3`.

**`docs/ui-shell/`**
- `before_hud_meters_phase_top_x3.png`: labels on pastel fills.
- `before_coop_host_teammate_list_x3.png`: plain text rows.
- `before_hud_pause_menu.png`: no window.
- `before_menu_title.png`, `before_menu_settings.png`, `before_menu_join_failed.png`, `before_menu_lobby_two_players.png`, `before_menu_credits.png` and `before_menu_run_summary.png`: stretched ticks, "Fin delviaje", buttons on the border.
- `mock_meters_before_after_x3.png`: the pass's route-B mock.
  - Its "after" still lists Sed first and is 142 px wide.
  - This design puts Salud first and narrows the window to 132 px (D4); the bar style and ramps are the mock's.

**`docs/inventory-hud/`**
- `before_hud_strip_selected_bottom_x3.png`: digits over icons, rims lost on navy.
- `before_hud_sign_note.png`, `before_hud_craft_list.png` and `before_hud_prompt_bench.png`.
- `mock_hotbar_padded_alternative_x3.png`: the padded hotbar of Q11 (b).
  - The owner declined it; it is kept only to record the choice.
  - Its well colour `#3f3f74` is not used (2.17:1 against black rims).

The build adds `kit_*.png` captures of the result beside these (tasks 2.7, 3.5, 4.6, 4.7, 5.4).

## Goals / Non-Goals

**Goals:**
- One window family in the master palette, built by a recipe, with no hand-painted PNG in `game/`.
- Keep every rect the specs pin, keep the 8 px HUD font and its character budgets, and keep the 640×360 rules: nothing in the centre, the sign note's place, the bottom band.
- Every text reaches the contrast in ui-shell "Readable HUD and menu text", and a test proves it for the 1-player HUD and every menu.

**Non-Goals:**
- Prompt placement over the local head (design pass C29).
- The craft list sized to its rows, with a needs block (C31).
- The last-stand band (C32).
- Per-vessel lash phrases (HU10).
- The padded-hotbar alternative (Q11 b).
- Choosing the single pixel font (Q16, later).
- Icons for meters.
- Changes to `hud_text.tres` lines.
- Moving any simulation, network or save code.

## Decisions

### D1. Reference games (ideas only, nothing copied)

**Shattered Pixel Dungeon** (`core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`)
- `Chrome.get(Type)` (`Chrome.java`) cuts every window kind from one small sheet as a NinePatch with its own margin. A window is 20×20 with a margin of 6, a button 6×6 with a margin of 2, and SCROLL is a paper look with uneven margins.
  - **Borrowed:** one kit of tiny 9-slice pieces with per-kind margins. Our `window_dark`, `window_thin`, `window_paper`, `panel_paper`, `slot_well` and `button` map onto WINDOW, TOAST, SCROLL, TAG and GREY_BUTTON.
  - **Rejected:** SCROLL's uneven margins. Uneven chrome is exactly what made today's tan panel crowd a focused button (HU8).
- `ui/ItemSlot.java` `layout()` puts the count in one corner, a second label in the opposite corner, and the level bottom-right. A label that would collide is hidden, and all are snapped to whole pixels.
  - **Borrowed:** the corner discipline. The count goes bottom-right and the key top-left, never over the icon.
  - **Rejected:** shrinking text to 0.8 scale, which blurs a pixel font. We use a smaller bitmap instead (D6).
- `ui/StatusPane.java` keeps a fixed-width portrait cap and stretches only the body. Below about a third of health it blinks the portrait toward red at `FLASH_RATE` (1.5 blinks a second).
  - **Borrowed:** the label column is fixed and only the bar has length.
  - **Already ours:** a pulse that tints a frame, never the text.
- `ui/HealthBar.java` `level(Char)` rounds the fill up to a whole pixel, so a sliver of health never reads as empty.
  - **Borrowed** for the meter bars and the teammate bar.
  - **Rejected:** its pure red and green.
- `ui/Toolbar.java` and `QuickSlotButton` show a slot's hotkey only in a tooltip.
  - **Rejected:** we show the selected slot's key on the slot (Q11 a).

**Brogue CE** (`src/brogue/IO.c`)
- `refreshSideBar` lists the player first and others after. `printMonsterInfo` gives every ally the same health row as the player, then a state line ("(Ally)", "(Captive)").
  - **Borrowed:** the teammate blocks. Name, then a health bar and the state word, in a fixed order.
  - **Rejected:** sorting by distance. Our list order is the session's.
- `printProgressBar` draws the label inside the bar and the empty part as the fill's hue darkened toward black. It also bands alternate rows and blends the text toward the fill.
  - **Borrowed:** the empty part in the darkest step of the meter's own ramp.
  - **Rejected:** the label inside the bar. It is the cause of the 1.47:1 labels, and route A was declined (Q10).
  - **Rejected:** row banding, which reads as noise at 5 px.

**DCSS** (`crawl-ref/source/`)
- `output.cc` `class colour_bar` (used as `HP_Bar`) has a default, a gain, a loss and an empty colour, and keeps the last width so the lost cells show for one redraw.
  - **Already borrowed** by damage-feedback for the lost chunk.
  - **Here:** the chunk and the empty part are palette steps (D5).
- `tilereg-inv.cc` `InventoryRegion::pack_buffers` layers each cell in order: slot background, selected marker, cursor, item, then quantity.
- `tilereg-grid.cc` `GridRegion::draw_number` draws quantities from a set of digit tiles (`TILEI_NUM0`…), not from a font.
  - **Borrowed:** the layer order. Well, selection ring, icon, digits, then the hold ring.
  - **Borrowed:** a tiny digit atlas for counts and keys (D6).
  - **Rejected:** the character-grid stat panel (`tilereg-stat.cc` `StatRegion::render`).

**Don't Starve Together** (dontstarve.wiki.gg, read 2026-11-14; `docs/REFERENCE_DST.md` "Inventory slots", "Durability", "UI ideas gathered from other sections")
- **Inventory page:** one bar of 15 slots, with the worn slots beside it.
  - Wearables show a durability percentage over the icon.
  - Food shows freshness as a coloured fill in the slot's background, going from green to yellow to red.
  - **Borrowed:** the slot background as an information layer. Our well is a flat mid-grey, so a later freshness or wear fill can tint it without touching the icon.
  - **Rejected:** a number over the icon. Our counts sit outside the icon's square.
  - The page does not say how stack counts or hotkeys are drawn [unverified].
- **Health page:** health is a heart-shaped badge in the upper-right corner that empties as health falls; a reduced maximum shows as a black part.
  - **Not borrowed:** round badges. Six meters at 640×360 fit as rows, not dials.
  - **Borrowed:** health is the one meter with its own shape and place. For us that means it comes first.
  - Its exact neighbours on screen are [unverified].
- **Sanity page:** an arrow on the badge shows the direction and speed of change. **Not borrowed here:** damage-feedback's drain glow covers "draining now".
- **Hunger page:** the meter flashes while starving. **Already ours:** the critical pulse, now on the outline.
- **Day-Night Cycle page:** a segmented clock face. **Not in this change:** a later day strip must stay inside the phase tag's 14 px band (design pass 4.4).

**The owner's reference pass** (2026-11-14; the coordinator's brief `reference-feedback-hud.md`, "HUD and inventory restyle" and its raw reports; names spot-checked in `reference/`)

*Meter rows*
- **Borrowed: a strict grid with label colour steps.** The rows are a strict grid: the label column, the bar at a fixed x, then the value. The label's colour steps at a warning and a danger threshold. Sources: DCSS `output.cc` `_print_stats_hp` (the caption colour `Options.status_caption_colour`, the bar from a fixed column, `hp_colour` yellow then red); Brogue `IO.c` `printMonsterInfo` (the nutrition label's states).
  - Ours: orange (`#df7126`, 4.93:1) at 50 or less (heat 50 or more), and the alert red (`#d95763`) at the critical 25 (heat 75), both steady. The outline and value pulse only at the critical step (D4).
  - Today's design doc has no warning number (`docs/GAME_DESIGN.md` §4 names only 0, 20, 60 and 100 as rule thresholds). The 50 is a HUD constant beside `CRITICAL_LOW`, not a rule.
- **Borrowed, in palette steps: a shaded edge pixel.** The pixel at the fill's edge shows the fraction it holds (Brogue `IO.c` `printProgressBar`). A 38 px bar is 0.38 px per point, so the edge column is drawn in the ramp's shade colour while it holds less than half a pixel, and as a full column from half up. That doubles the bar's resolution with no blended colour (D4).
- **Rejected: alternate rows a shade darker** (`printProgressBar`). Our bars already stand 3 px apart on the window fill. A darker row tone than `#222034` would be `#000000` (1.32:1, invisible), and a lighter one would cut the labels' contrast.
- **Deferred, own change: rate arrows.** DST's "Sanity" page shows a small arrow beside a meter, sized by how fast it moves. Our 132 px row has no free cell. A 5 px arrow cell takes the bar from 40 to 34 px, and the arrow reads its rate from damage-feedback's per-meter watches once they are on main. It is owner question E.
- **Borrowed: rows that show only while they apply.** DST's "Wetness/DST" page shows its wetness meter under the others only while the player is wet. "Sangrando" already works this way. Any later status row goes under the six meters the same way. The 90 px budget holds two such rows (4 + 6 + 60 + 20 = 90); a third needs its own layout (D4).

*Slots*
- **Borrowed: the count corner.**
  - The count shows only above 1: DCSS `tilereg-inv.cc` `_fill_item_info`.
  - The uses left turn orange on the last use: SPD `ui/ItemSlot.java`, whose status corner takes `WARNING` (orange) on a last throw.
  - Durability as a number on the slot: DST "Durability" page.
  - Ours: tools never stack (crafting-inventory), so a slot never needs a count and a uses number together. Both share the bottom-right place, and the uses digits turn `#df7126` at 1 use left.
  - **Rejected: a second corner for uses.** Every other corner crosses the icon's square or the key.
- **Borrowed: dimmed slots and recipes, never hidden.** Sources:
  - SPD `windows/WndBag.java` `ItemSelector.itemSelectable()`;
  - DCSS `TILEI_FLAG_INVALID` in `tilereg-inv.cc`, and `quiver.h` `is_valid`, which is kept apart from `is_enabled`;
  - Brogue `Items.c` `displayInventory`, which greys rows.

  Ours: a slot whose item has a use that the use button would refuse right now is dimmed (D6). The craft list already dims recipes that are short of something. An item with no use at all (driftwood) is never dimmed, or most of the strip would be grey.
- **Rejected: a dimmed placeholder when a stack runs out.** SPD `QuickSlot.java` `isNonePlaceholder` and `replacePlaceholder`, and DCSS `quiver.h` `find_replacement` and `on_item_pickup`, keep one. Our slots are the host's inventory slots, not quickslots, and a pickup goes to the first free slot (crafting-inventory). A placeholder would promise a refill the host never makes. It needs slot memory in crafting-inventory first.
- **Borrowed: a delayed tooltip with the item's name and its verb.** Sources: DCSS `tilereg-inv.cc` `InventoryRegion::update_tip_text`, and the webtiles action panel's delayed hover tip (`action_panel.js`). Ours is for the mouse only; the selected item's line already does this job for the keyboard and the gamepad (D6, inventory-hud "Slot tooltip").
- **Deferred: a picked-up item's sprite flying into the strip** (SPD `ui/Toolbar.java` `PickedUpItem`). It is a client-side flourish for a later change.
- **Rejected: re-sorting on pickup** (SPD `items/Item.java` `itemComparator` in `collect()`; Brogue `Items.c` `addItemToPack`). It would move items under the player's number keys.
- **Rejected: a key label on every slot.** The owner chose Q11 (a).
- **Rejected: DST's cursor "hand" slot and mouse-only item actions** ("Inventory" page). They break gamepad parity and the host-owned slot model.

**GBA-era windows** (general knowledge, described in words; no asset used)
- **Pokémon FireRed and LeafGreen:**
  - The text box is a cream fill with a dark outer line, a lighter inner line, and corners rounded by a one-pixel step. It is the model for `window_paper`.
  - The battle status box has a short label, a thin bar over a dark empty track, and the number beside it. It is the model for the meter rows.
- **A Link to the Past:**
  - The item screen is a dark window with a bevelled rim and each item in its own recessed square, with a bright bracket for the selection. It is the model for `window_dark`, the wells and the selection ring.
  - Life comes first and is the most prominent thing on the HUD: Salud first.

### D2. A recipe-built 9-slice kit, drawn through StyleBoxTexture

A new `tools/art/ui.py` (stdlib and `tools/art/png.py` only) reads `tools/art/ui_kit.json` and writes each piece to `game/assets/art/ui/`.
- **Pixels:** colours by palette name, whole alpha, nearest filter. The tracked PNGs are rebuilt byte for byte (K35, as for terrain).
- **Licence:** `game/assets/art/ui/License.txt` becomes an own-work block.
- **Tests:** `tools/art/test_ui.py` checks each piece's size, its margins, the transparent outer corner pixel, palette membership and that a rebuild is byte-identical.

**Alternative: StyleBoxFlat with `corner_radius`.** Rejected: with the viewport's integer stretch it anti-aliases corner pixels into colours that are not on the palette.

**Alternative: hand-painted PNGs.** Rejected: the art rules say pieces are rebuilt by recipes and never painted into `game/`, and a recipe keeps the bevel and outline rules in one place.

#### The pieces

Contrasts are relative-luminance ratios (`palette.luminance`). Every colour is in `master_palette.gpl`.

| Piece | Size and margin | Pixels | Used by |
|---|---|---|---|
| `window_dark` | 10×10, margin 3 | Row and column 0: outline `#222034`, the corner pixel transparent and its inner diagonal `#222034`, a one-step rounded corner. Row and column 1: bevel, `#d9a066` top and left, `#8f563b` bottom and right. The rest is fill `#222034`. | `HudPanel`: meters, phase, teammates, craft list, watching line, pause, host-lost, the quick-chat backdrop, the popup |
| `window_thin` | 6×6, margin 2 | Outline and fill both `#222034`, with the 4 corner pixels transparent | `HudPanelThin`: the prompt, item line, notice, weight and the strip's backdrop |
| `tab_dark` | 10×10, margin 3 | `window_dark` without its bottom outline row | The "Pausa" tab and the host-lost tab |
| `window_paper` | 10×10, margin 3 | Outline `#222034` with the corner stepped; bevel `#ffffff` top and left, `#e4b488` bottom and right; fill `#ffedde` | `HudNote` (sign note) |
| `panel_paper` | 10×10, margin 3 | Outline `#663931`, corner stepped; bevel `#f6dcb4` top and left, `#c08a5a` bottom and right; fill `#eec39a`; the same along every edge | `Panel` and `PanelContainer` in the menus |
| `slot_well` | 8×8, margin 3 | Outline `#222034` with its corner pixels cut; a recessed bevel, `#696a6a` top and left, `#9badb7` bottom and right; fill `#847e87` | `HudSlot` |
| `slot_selected` | 8×8, margin 3 | Outer ring `#fbf236`, inner ring `#df7126`, corners cut, fill `#847e87` | `HudSlotSelected` |
| `button`, `button_hover`, `button_pressed` | 10×10, margin 3 | Outline `#222034`, corner stepped. Normal: bevel `#639bff` top and left, `#3f3f74` bottom and right, fill `#306082`. Hover: the same fill with a `#cbdbfc` top and left bevel. Pressed: fill `#3f3f74`, the bevel swapped, content 1 px lower. Disabled: the normal piece at `modulate` alpha 0.5. | `Button`, `OptionButton` |
| `focus_ring` | 6×6, margin 2, expand 1 | Ring `#fbf236`. The outer corner pixel is transparent and the inner diagonal pixel is filled, so the button's own transparent corner never shows the backdrop. Transparent centre. | Button, OptionButton, CheckBox and LineEdit focus |
| `line_edit` | 8×8, margin 3 | Outline `#222034`, an inner shade `#c08a5a` top and left, fill `#ffedde` | `LineEdit` |
| `check_off`, `check_on` | 9×9 | Outline `#222034`, fill `#ffedde`; "on" adds a tick with a 2 px stroke in `#222034` | CheckBox icons |
| `arrow_down` | 7×4 | A chevron in `#ffedde`, rows 7, 5, 3 and 1 px wide | OptionButton `arrow` |
| `scroll_track`, `scroll_grabber` | 6×6 margin 2; 6×8 margin 3 | Track: outline `#222034`, fill `#3f3f74`. Grabber: outline `#222034`, bevel `#eec39a` and `#8f563b`, fill `#d9a066` | VScrollBar |
| `radio_off`, `radio_on` | 7×7 | A stepped circle in `#ffedde`; "on" adds a 3×3 `#fbf236` dot | PopupMenu radio items |
| `digits_3x5` | 12 cells of 5×7, two rows | The glyphs 0–9, "-" and "=", 3×5 each, with a baked 1 px `#222034` outline. Row 0 is `#ffedde`; row 1 is `#df7126`, for the last use. | `HudDigits` (D6) |

**Changes from the design pass's §4.1**
- **Button hover:** the pass used a `#5b6ee1` fill, which puts cream at 3.87:1. Hover keeps the normal fill, lightens the top bevel and draws its text white (6.73:1).
- **Digit atlas:** added to the kit.

### D3. Theme values and the colour move, in one commit

**Theme values** (design pass §4.2, kept unless noted)
- `HudPanel`:
  - `StyleBoxTexture` `window_dark`, `texture_margin_*` 3, content margins 4/3/4/3;
  - `axis_stretch_*` TILE (the strips are uniform, so tiling shows no seam);
  - `modulate_color` `(1, 1, 1, 0.94)` (Q9);
  - the variation name stays `&"HudPanel"`, because `RunHud.panel_rects()`, `run_hud.gd` and three tests key on it.
- `HudPanelThin`: `window_thin`, margins 2, content margins 4/1/4/1, the same stretch and modulate.
- `HudNote`: `window_paper`, margins 3, content margins 4/3/4/3, opaque.
- `HudSlot` and `HudSlotSelected`: `slot_well` and `slot_selected`, margins 3, no content margin.
- Button and OptionButton:
  - the button set, content margins 6/3/6/3;
  - `focus` = `focus_ring` with `expand_margin_*` 1;
  - `font_color` `#ffedde`, `font_focus_color` `#fbf236` (5.72:1), `font_hover_color` `#ffffff`.
- CheckBox: `StyleBoxEmpty` for its states (it sits on paper), the check icons, text `#45283c`.
- `Panel` and `PanelContainer`: `panel_paper`, content margins 8/6/8/9 (the bottom 9 leaves room under a focused button), TILE.
- `LineEdit`: `line_edit`, content margins 4/3/4/3, the focus ring.
- `VScrollBar`: the track and grabber.
- `PopupMenu`:
  - panel `window_dark`;
  - hover a `StyleBoxFlat` row in `#306082` with `anti_aliasing = false` and no radius;
  - font colours `#ffedde` and `#fbf236`;
  - the radio icons.

**Text styles**
- `Label`: `#ffedde`, with the shadow `#222034` at full alpha, offset (1,1).
- `HudCount`: a 1 px `#222034` outline.
- `PanelLabel` and `CreditsLabel`: `#45283c` (7.96:1 on `#eec39a`), no shadow.
- `PanelHeading` (new, base `HeadingLabel`): `#45283c` at 16.
- `ErrorLabel` (new, base `Label`):
  - `#ffedde` text on a `normal` `StyleBoxFlat` band in `#ac3232` (5.66:1);
  - `anti_aliasing` off, no radius;
  - set at runtime only while an error shows.
  - The pass's `#ac3232` text on paper gives 3.97:1, under the 4.5:1 rule.
- `HudNoteText`: `#222034` (13.91:1 on `#ffedde`).
- `AlertLabel` (new, base `Label`): `#d95763`, for "Sangrando" and the state words.
- `TooltipPanel` and `TooltipLabel` (the engine's tooltip types):
  - the panel is `window_thin`, with content margins 4/1/4/1;
  - the label is Press Start 2P 8 in `#ffedde`;
  - so any tooltip, the slot tooltip first (D6), is in the kit.

**Fonts**
- `game/assets/fonts/menu_font.tres`: a `FontVariation` of Pixelify Sans with `spacing_space = 2`, so a space is 5 px at 16. It is used for Button, OptionButton, CheckBox, LineEdit, TitleLabel, HeadingLabel, PanelHeading and CreditsLabel.
- Press Start 2P 8 stays the default font.

**`HudStyle`**, changed in the same commit as the theme, so that code and theme never disagree:

| Constant | Today | New value |
|---|---|---|
| `SUN` | `#ffcc00` | `#fbf236` |
| `CREAM` | `#f4efe0` | `#ffedde` |
| `OUTLINE` | `(0.04, 0.08, 0.13)` | `#222034` |
| `TRACK` | cream at 0.35 | `#3f3f74` (opaque; 8.47:1 under cream text, still clearly "empty" beside `#fbf236`) |
| `ALERT` (new) | — | `#d95763` |
| `ORANGE` (new) | — | `#df7126` |

**Code-side colour moves**
- `MeterBar.PULSE_COLOR` goes to `HudStyle.ALERT`.
- The Bleeding tag moves to the `AlertLabel` variation. `#d95763` passes `test_meters_hud.gd`'s check (red 0.85 > 0.7; green 0.34 and blue 0.39 < 0.4).
- `QuickChatWheel.SELECTED_COLOR` becomes a font colour of `HudStyle.SUN`, not a modulate.
- The name tag's health strip:
  - the track becomes `#222034`;
  - the fill becomes the Salud base `#6abe30`, the same green as the meters and teammate bars.
  - The pass's `#d95763` fill is not used, so health is one colour everywhere and red stays the alert colour.
- `title_screen`'s `sea.gdshader` takes palette colours: a sky ramp, `#222034` to `#306082` sea, and a `#fbf236` sun in place of today's third yellow `#ffd15c`.

### D4. The meters window (route B, Q10), fitted to x 136

The pass's mock row (56 + 4 + 46 + 4 + 24 + margins) is 142 px wide and would overlap the note label at x 140. The row is narrowed:

| x in content | Part |
|---|---|
| 0–55 | label, 7 glyphs ("Energía"), cream, on the window |
| 58–97 | bar box, 40×7: a 1 px outline round a 38×5 bar, at y 1–7 of the 10 px row |
| 100–123 | value, 3 glyphs, right-aligned, cream |

- Content width 124, plus margins 4 and 4, gives a window 132 px wide at (4,4), ending at x 136, 4 px clear of 140.
- Rows are 10 px with no separation. Six rows give 60 + 6 = 66 px tall (y 4–70); with the Sangrando row it is 76 (y 4–80). That is inside 160×90 and inside the new (4,4)–(136,90) rule.
- **The bar** stays a `ProgressBar` named `Bar` (damage-feedback hangs its nodes there). Its look:
  - fill row 0 is the highlight, rows 1–3 the base, row 4 the shade;
  - the empty part is the ramp's darkest step;
  - the fill is rounded up to a whole pixel while the value is above 0 (SPD `HealthBar`).
  - The fill and background are `StyleBoxTexture`s from a 1×5 ramp strip per meter, built by `ui.py` as `ramp_<meter>.png`, stretched across with nearest filtering, so each row keeps its colour.

**The ramps** (pass §4.4):

| Meter | Highlight | Base | Shade | Empty | Note |
|---|---|---|---|---|---|
| Salud | `#99e550` | `#6abe30` | `#4b692f` | `#323c39` | |
| Sed | `#cbdbfc` | `#639bff` | `#5b6ee1` | `#3f3f74` | |
| Hambre | `#eec39a` | `#d9a066` | `#8f563b` | `#45283c` | |
| Calor | `#fbf236` | `#df7126` | `#ac3232` | `#45283c` | plus a 1 px `#d95763` tick at 75; Calor fills as it rises |
| Energía | `#ffffff` | `#fbf236` | `#8a6f30` | `#524b24` | |
| Ánimo | `#ffedde` | `#d77bba` | `#76428a` | `#45283c` | |

- **Order:** Salud, Sed, Hambre, Calor, Energía, Ánimo, by moving the `Health` node first in `meters_hud.tscn`. Nothing else keys on row order: `bars()` and `bar_for()` read the nodes.
- **The label's colour** is steady and stepped (DCSS `hp_colour`):
  - cream above the warning step;
  - `HudStyle.ORANGE` at the warning step, `WARN_LOW` 50 or less (heat `WARN_HEAT` 50 or more);
  - `HudStyle.ALERT` at the critical step (`CRITICAL_LOW` 25, `CRITICAL_HEAT` 75).

  The constants sit beside today's critical ones in `MeterBar`. The label never pulses.
- **The critical pulse** lerps only the bar box's outline and the value's font colour between their steady colours and `HudStyle.ALERT`, at the existing 1 Hz.
- **The edge column** (Brogue `printProgressBar`, in palette steps):
  - the fill is `v / 100 × 38` px: its whole columns, plus one more full column when the remainder is at least half a pixel;
  - a remainder under half a pixel draws a 1×5 `Edge` ColorRect in the ramp's shade colour;
  - any value above 0 therefore shows at least a shade column.
- **Status rows** ("Sangrando", and any later one) go under the six meters only while they apply, one 10 px row each. The 90 px budget holds two; a third status needs its own layout in its own change.
- **The window** is the `HudPanel` it already is, so `panel_rect()` and `RunHud.panel_rects()` are unchanged.

### D5. Damage-feedback inside the kit

`damage-feedback` merges first. Its branch at `dfa2a31` has these parts:
- hit and drain cues, with Q1–Q4 answered A;
- item-use feedback: change floats ("+15 Sed", "Sin sangrado"), gain slices, an effect line, and refusals of uses that would change nothing (Q5–Q7 open).

Its cues keep their behaviour and timing; only their geometry and colours change here.

**The bar's slices**
- **Lost:** the `Lost` ColorRect is placed inside the 38×5 fill area, from the new fill's end to the old value, in `HudStyle.ALERT`.
- **Gain:** the `Gain` ColorRect spans the gained part in the ramp's highlight colour across all 5 rows, and blends into the fill as before. Its "fill lightened" becomes this palette step.
- **The 2-frame brightening** lerps the fill texture's modulate toward white. It is not a new colour.

**Drain glow:** the `Glow` Panel becomes the bar box's 1 px outline drawn steady in `#ac3232`. The precedence is pulse (`ALERT`), then glow (`#ac3232`), then plain (`#222034`).

**Shake:** offsets the bar box ±1 px inside its 2 px side gaps. The label and value stay put, so the row's text never jitters.

**Edge overlay:** stays a full-screen overlay. It is not a window and not a `HudPanel`.

**Change floats** (`ChangeFloats`, D9 there)
- They stay world-anchored HUD marks in Press Start 2P 8.
- Each float gets the `HudCount` 1 px `#222034` outline, so its meter colour reads over sand, sea and foam alike.
- Damage-feedback's test keeps `HurtCueTuning.meter_colors` equal to each `MeterBar.fill_color`. `MeterBar` therefore keeps a `fill_color` export, set to the ramp's base colour (D4), and the build updates `meter_colors` to the same six bases in the same commit.

**Effect line and refusals** (Q5 A there): they share the notice row (120,306, 400×10), which becomes `HudPanelThin`. Damage-feedback owns their text and timing; this change only draws the row.

**No floating damage numbers:** none, per Q3 A there.

### D6. The hotbar slots (Q11 a)

Inside the 26×26 slot (x and y from the slot's top-left):
- **The well** comes from `slot_well`: outline at 0 and 25, bevel at 1 and 24, fill 2–23.
- **The icon** moves 1 px up, to (5,4)–(20,19).
- **The count** is right-aligned so its last glyph column is x 23, with glyph rows 20–24. The baked outline takes rows 19–25 and so merges with the slot's own outline. No glyph pixel enters the icon's square (rows 4–19).
- **The key** shows on the selected slot only, while the device is the keyboard. Its glyph is at x 2–4, y 2–6 (columns 2–4 lie left of the icon's column 5). The atlas has "-" and "=" for slots 11 and 12.
- **Letters** for an item with no icon stay Press Start 2P 8 at (1,9). No icon is drawn under them.
- **The use ring** stays radius 10 and 2 px wide, in `HudStyle.SUN`.
- **Draw order**, from DCSS `pack_buffers`: well, selection ring, icon, letters, digits, use ring.

**The last use:** a tool's uses left draw from the atlas's orange row when exactly 1 use is left (SPD `ItemSlot` `WARNING`). A stack's count is always cream, since tools never stack.

**Dimmed slots**
- A slot is dimmed when its item has a use (`UsePlan.choose` finds one) and that use would be refused now. The test is the one the use button already runs on a press: `UsePlan.actor_reason`, then `ItemUser.check`, including damage-feedback's wasted-use reason.
- An empty slot, and an item with no use (`NO_USE`), are never dimmed.
- The strip works this out again only when something it reads changes: the inventory, the bound body's meters or statuses, the downed or crossing state, or the selection. It never runs every frame.
- A dimmed slot draws its icon, letters and digits at the craft list's `DIM` (alpha 0.4) over the well. The well itself stays opaque, so it is still a slot, and the icon stays visible.
- The host still decides every use.

**The slot tooltip** (inventory-hud "Slot tooltip")
- `StripSlot` sets `tooltip_text` to "<item name> · <verb>": the name from the item's content, the verb from `hud_text.tres` for the use `UsePlan.choose` picks. The name alone when it has no use, and "" for an empty slot.
- The engine shows it after `gui/timers/tooltip_delay_sec` (0.5 s), on the kit's `TooltipPanel`, near the pointer and inside the viewport.
- Tooltips come from the mouse only, so a gamepad never shows one. It takes no focus.

`HudDigits` (a `Control`, `scripts/ui/hud_digits.gd`) draws a string of the atlas's glyphs right- or left-aligned at a 4 px pitch, the outlines overlapping. It replaces `count_label` and `key_label` as the drawn text. Those Labels stay as hidden text holders for the tests and the `count_text` API, so the existing strip tests keep reading `.text`.

**The strip's backdrop:**
- `Panel` (153,330)–(487,356) takes `HudPanelThin` with `expand_margin` 2 left, right and bottom and 1 at the top. It draws (151,329)–(489,358), clear of the item line (ends at 328) and the weight (starts at 491), and 2 px above the view's bottom edge.
- With 13 slots the row is 362 px wide (139–501) and the weight moves right with it, as `_layout` does today.

**Contrast:**
- Black icon rims on `#847e87`: 5.32:1. Today they are 1.41:1 on the navy.
- `#222034` rims on `#847e87`: 4.01:1.
- Cream digits on the well: 3.47:1, but each digit carries its own `#222034` outline, at 13.91:1 to the glyph.

### D7. The teammate blocks

**The window**
- `window_dark`, right-anchored: `TeammatesPanel` takes `anchor_left = anchor_right = 1`, `offset_right = -4`, a fixed width of 134 and `grow_horizontal = GROW_DIRECTION_BEGIN`. It spans x 502–636.
- Content margins are 3/3/3/3, so the content is 128 px, exactly 16 glyphs. The frame's fill row still sits between the bevel and the text.

**Each teammate block** is 20 px tall:

| Line | x | Content |
|---|---|---|
| 1 | 0–127 | The name in cream. A 16-character name fits whole, so no name is ever cut. |
| 2 | 0–5 | A 6×6 chip: a 1 px `#ffedde` ring round a 4×4 of the teammate's clothing base colour (the base shade of row `look_slot + 1` of `player_ramps.png`; `look_slot` is already replicated on every peer) |
| 2 | 8–29 | A 22×6 health bar on the Salud ramp, with a 1 px outline round a 20×4 fill |
| 2 | 32–127 | The state word, up to 12 glyphs ("Desconectado") |

- **State word colours:** "Caído" and "Muerto" are `ALERT` (4.15:1); "Desconectado" is `#9badb7` (6.84:1).
- **Height:** blocks are 2 px apart, so three teammates take 70 px (y 4–74). That is clear of the phase (ends at x 380), the needle, the sign note (ends at x 440) and the note label (ends at x 500).
- **`RunHud.teammate_rows()`** keeps returning "<name> <health> <state>" for each block, so `test_run_hud.gd` and `test_dropped_teammate_net.gd` keep their text checks.
- **The blocks** are built by a small `TeammateBlock` scene, `scenes/ui/teammate_block.tscn`, rather than plain Labels.

**Alternatives:**
- **One line per teammate:** at least 238 px wide. It crosses the sign note (x ≤ 440) or the phase, so it is rejected.
- **Cutting names at 14 glyphs to keep a wider bar:** rejected while 16 glyphs fit.
- **Dropping the chip for a 28 px bar:** declined by the owner (B1, 2026-11-15).

### D8. Thin windows and the 10 px rows

`window_thin` has a 1 px frame, so a 10 px row holds the 8 glyph rows (y 1–8) and the 1 px shadow (y 9 falls on the bottom outline, the same colour).
- **`InteractPrompt`** places its labels at y 0. They move to `y = 10 × line + 1`; the box stays `lines × 10` px tall, so `Prompt placement`'s rects are unchanged.
- **`CraftList`** (`PADDING` (4,3)) and **`SignNote`** (`PADDING` (4,3)) already clear a 3 px frame. Their first glyph row lands on the frame's fill row. No change, but a test pins it.
- **`ItemLine` and `Weight`** are vertically centred Labels, already at y 1.
- **`HudNotice`** is the same.

### D9. Pause, host-lost and the wheel

**`PauseMenu`** (layer 9) keeps its 60% `Shade`.
- Its `Box` moves into a centred `PanelContainer` (`HudPanel`), with a `tab_dark` `PanelContainer` holding the "Pausa" `PanelHeading`. The tab sits on the window's top edge, overlapping it by 1 px.
- The LabelSettings go, and the theme draws the title.
- The window is about 136×56, centred.

**`HostLostScreen`** gets the same structure.

**`QuickChatWheel`**:
- draws its backdrop as a `HudPanel` square instead of the black square;
- shows its selected entry in `HudStyle.SUN` as a font colour.

### D10. Menus

**Panels**
- The tan panel's ticks go, together with the Kenney file, and `panel_paper` replaces it.
- The five shell scenes lose their `#3b2a17` overrides and use `PanelLabel` or `PanelHeading`.
- `settings_screen.tscn:46-48` loses its CheckBox colour overrides.

**Layout**
- Join and lobby centre their rows in a `CenterContainer`. Bottom margin 9.
- The join error switches to `ErrorLabel` while it shows a failure line, and back to `PanelLabel` for "Conectando…".
- The run summary keeps its pinned rect (coop-rematch modifies "Run summary"; this change does not). Its rows sit in a `window_paper` inset, so the empty two thirds read as a frame, not a void.

**Owner Q16 (a):** the word spacing is fixed now through `menu_font.tres`. The single pixel font is a later change.

### D11. The UI folder joins the palette rule; Kenney's UI files leave

- `button_blue.png`, `button_blue_pressed.png` and `panel_tan.png` are deleted with their `.import` files.
- `License.txt` becomes the own-work block for the kit.
- `test_art_tracked.gd` drops its `UI_DIR` exemption, so palette and alpha now apply to `art/ui/` (art-pass "Master palette").
- `test_theme.gd` keeps "only tracked art" and lists the new files.
- **The Pixel UI Pack's credit:** art-pass "Credits list every pack used" lists packs whose files are tracked. With none left, its line in `CREDITS.md`, the credits data and `test_art_credits.gd:27` goes.
  - The owner chose to drop it (D1, 2026-11-15).
  - Before deleting, the build greps for any other tracked use (for example a cursor).

### D12. How contrast is tested

A test helper, `tests/unit/hud_contrast.gd` (`HudContrast`), computes WCAG relative luminance from a `Color`, the same formula as `tools/art/palette.py` `luminance`.

**Tests read** the theme's font colours and the kit's fill colours, read from the built PNG's centre pixel rather than restated.

**Pairs checked:**

| Text | Fill | Minimum |
|---|---|---|
| Labels | `window_dark` | 4.5:1 |
| `HudNoteText` | `window_paper` | 7:1 (inventory-hud "Sign note") |
| `PanelLabel` | `panel_paper` | 4.5:1 |
| Button text, every state but disabled | its button piece | 4.5:1 |
| `ErrorLabel` | its band | 4.5:1 |
| `AlertLabel` | `window_dark` | 4:1 |
| Black | `slot_well` | 5:1 |

**Font sizes:** every Label in the run HUD is Press Start 2P at 8, and every menu label is the menu font at 16 or 32.

### D13. Build order and PR stages

The change is applied in five PRs, each green on import ×2, smoke and GUT:
1. The kit art (`ui.py`), the palette rule for `art/ui/`, and the Kenney removal with credits.
2. Theme, `HudStyle` and fonts, and the menus, pause and host-lost (no HUD geometry change).
3. HUD windows: phase, thin rows, prompt `y = 1`, wheel, watching line and sign note.
4. Meters (route B) with damage-feedback's nodes re-fitted, and the teammate blocks with their host-plus-client test.
5. Hotbar wells, digits and the key on the selected slot.

The whole change builds after `damage-feedback` is on main, because stages 2–5 edit files it edits:
- `settings_screen` (its checkbox);
- `meter_bar` and `meters_hud`;
- `run_hud` (`ChangeFloats`);
- `hud_notice` (the effect line).

Stage 1 touches none of them and could go first if the owner wants the kit early.

### D14. The crossing HUD strip joins the kit later

`crossing-gameplay` (on its branch; crossing "Crossing HUD and telegraphs") adds a `CrossingHud` CanvasLayer under the crossing, on every peer. It draws:
- a progress strip from the departure island to the next;
- the vessel's integrity ("Balsa 70/100");
- short telegraph lines.

It sits top-centre under the day phase, in the sign note's place, since no sign opens at sea. It is built from today's `HudStyle`, in its own node, and edits nothing of ours.

**What carries over by itself:** when stage 2 moves `HudStyle` to the palette, every colour it reads from `HudStyle` follows: `SUN`, `CREAM`, `OUTLINE`, and `TRACK`, which becomes opaque `#3f3f74`.

**Stage 3 then restyles it in the kit,** if it is on main by then; otherwise in the first HUD change after it lands:
- Its panel takes `HudPanel`, and each telegraph line a `HudPanelThin` 10 px row.
- The strip is a bar box like the meters' (D4): a 1 px outline round a track in the deep-sea steps (`#2a5578`, `#3a6f92`), and the vessel marker in `#fbf236`.
- The integrity reads cream, steps to `HudStyle.ORANGE` at half and to `ALERT` at a quarter, the same steps as the meter labels.
- Its rect, its texts and its timing stay crossing-gameplay's.
- The kit's tests add it to the HUD-window and contrast checks, and to the rule that it stays clear of the meters (x ≤ 136) and the teammate list (x ≥ 502).

**If it does not land first,** nothing here waits for it. Task 3.4 is then skipped, and noted for that later change.

## Risks / Trade-offs

- **[The empty track is 1.2–1.8:1 against the window]** A bar's length reads from its fill, not from its outline. → This is accepted for the GBA look: the pass's mock reads, and Pokémon's empty track is the same idea. If a capture shows otherwise, the bar box's bottom row can take `#45283c` at no layout cost.
- **[94% modulate also fades the outline]** The outline stays `#222034` at 94%. On `#ffffff` foam that is still about 11:1. → The test measures against the opaque piece; the over-world check is a capture.
- **[Damage-feedback lands with a different node shape]** → D5 names only its public nodes (`Lost`, `Glow`, `Bar`). Stage 4 starts by reading the merged code and updates D5 if they differ.
- **[The menu FontVariation widens lines]** → `test_credits_screen.gd` "fits across" and the settings layout test run on the new font. Any line that no longer fits is wrapped or shortened in its scene, never by shrinking the font.
- **[A 22 px teammate bar is coarse]** One pixel is 5 health. → The number is gone from the block, but the name tag over the head shows the strip too. The owner chose the chip with the 22 px bar (B1).
- **[GUT time]** CI's GUT step is close to its 300 s timeout. → The new tests are pure layout and colour reads with no real-time waits. The one net test reuses `NetHarness` and awaits only the sync.
- **[Merge with in-flight work]** `art-wave-1` and `crossing-gameplay` touch terrain and crossing, not `scenes/ui/`, `scenes/shell/` or the theme. `crossing-gameplay`'s `CrossingHud` reads `HudStyle`, so stage 2's colour move reaches it (D14). → Rebase before each stage. Stage 2 runs the crossing HUD tests if that change is on main.

## Migration Plan

There are no saves or settings to migrate. Each stage is a revertible PR, and stage 1's deleted Kenney files come back with a revert.

## Owner decisions

**Taken on 2026-11-14 (recommended answers):**
- Q8 (a): dark GBA windows for the HUD, cream paper for notes, all in the palette.
- Q9 (a): 94% opaque.
- Q10 (a): a label column with thin bars, Salud first.
- Q11 (a): today's slots, small digits, the key on the selected slot only.
- Q16 (a): the word spacing now, one pixel font later.

**Taken on 2026-11-15 (recommended answers, through the coordinator's option dialog):**
- A1: scope as written. Prompt placement (C29), the craft window (C31) and the last-stand band (C32) follow as their own small changes.
- B1: each teammate block has the full name, then a clothing chip, a 22 px health bar and the state word (D7).
- C1: the name tag's strip over a teammate's head is the Salud green (D3).
- D1: the Kenney Pixel UI Pack's credit is dropped once its files go (D11).
- The two departures from the design pass are accepted: the 132 px meters window (D4) and the teammate blocks at x 502–636 (D7).

**Still open.** The specs and tasks are written with the first, recommended option; another answer changes only stage 4.
- **E. Rate arrows beside each meter** (DST "Sanity" page; D1).
  1. *(Recommended)* Later, as their own change, using damage-feedback's per-meter watches. The bar then goes from 40 to 34 px.
  2. In this change, in stage 4, with the bar at 34 px now.
  3. Never.

## Open Questions

- How a later freshness or wear state tints the slot well (DST's slot background) waits for a change that adds spoilage or wear. The flat `#847e87` fill leaves room for it.
