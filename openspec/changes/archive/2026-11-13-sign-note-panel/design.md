# Design

## Context

- `IslandSign` (`game/scenes/levels/island_sign.gd`) is an `Interactable` with prompt "[E] Mirar". On the host its `interacted` handler calls `CoopSession.show_sign.rpc(name)`, and every peer runs `show_bubble`: a `SpeechBubble` (8 px PixelifySans, 2 px black outline, a 96 px label with no wrap) over the sign for `SpeechBubble.SHOW_S` = 2.5 s.
- The coast cay's four lines are 66 to 100 characters long. On one line, over sand, for 2.5 s, they can't be read (art-pass playthrough, 2026-11-13).
- The world and the HUD share the 640×360 budget, so the bubble's glyphs are already as big as the HUD's: the problem is backing, wrapping and time, not font size.
- The crafting list already shows the pattern this change needs. `InteractPrompt` emits `bench_pressed` on the local press, `RunHud` opens `CraftList` on this peer, the list holds interact (`PlayerBody.hud_holds_interact`) and takes pause before the pause menu, and it closes on leaving reach, going down or a screen showing. The host still gets an ordinary press on the bench, which does nothing.

## Goals / Non-Goals

**Goals:**
- A sign's line can be read in full at 1× by one player, solo or in co-op, for as long as they like.
- Reading a sign uses the bench's local-open path, adding no new networking.

**Non-Goals:**
- Changing quick-chat or NPC speech bubbles (they stay in the world; NPC dialogue gets its own window in `npcs-dialogue`).
- A journal of read signs, a title per sign, or icons (SPD's Document list); possible later.
- Making the HUD font bigger or changing UI scaling.

## Decisions

**D1. Reference games: text the player reads lives in a panel, not on the map.**
- *Borrowed, Shattered Pixel Dungeon:*
  - `windows/WndStory`: a parchment-skinned window with dark text, sized to fit the text, that stays until tapped.
  - `windows/WndMessage`: a plain panel with a minimum width and wrapped text.
  - `PixelScene.renderTextBlock` / `RenderedTextBlock` with a `maxWidth`: wrap to a width and size the box from the result.
  - From these we take the light card with dark text, the fitted height and dismiss-on-input.
- *Rejected, Shattered Pixel Dungeon:*
  - `WndStory.setDelays`, the timed lock that blocks dismissal: a flavour line doesn't need it.
  - `effects/FloatingText` (1 s text that floats over a character): SPD keeps it for numbers and status words, which is the use our bubble is wrongly stretched to.
- *Borrowed, Brogue CE:* from `printTextBox` in `IO.c`, a solid back colour behind the box and a minimum width, as the main legibility tools.
- *Rejected, Brogue CE:* the `--MORE--` acknowledgement in `message()` that blocks everything; our note never pauses and walking away closes it.
- *Brogue and DCSS:*
  - Both show "look" text in a log (Brogue `flavorMessage`, DCSS `mpr` into the message window).
  - Rejected for now: we have no message log, and a log line is still small text in a corner.
  - DCSS's `describe.cc` pop-ups (`ui::Popup`, a scroller) confirm the panel approach.
- No code, data or text copied.

**D2. A HUD scene `SignNote`, opened locally like the crafting list.**
- `InteractPrompt` gains `sign_pressed(sign: IslandSign)`, emitted where it emits `bench_pressed`.
- `RunHud` opens `%SignNote` with the sign.
- The note holds interact while open and until interact is released (the same `hud_holds_interact` flag the list uses, set by either).
- It takes pause first, and closes when the reach check (`InteractionPicker.REACH_PX` plus the list's slack) fails, the body goes down or leaves, or `set_screen_shown(true)`.
- Opening one while the crafting list is open can't happen, because the list holds interact. Opening the list while a note is open can't happen either, because the note holds interact.
- *Alternative:* a host RPC to the reader (`show_sign.rpc_id`). Rejected: it adds a round trip and a message for something every peer already has (signs are built into the level on every peer).

**D3. Layout and text.**
- The card is 240 px wide at x = 200 (centred) with its top at y = 22, under the day phase's box.
- Inside, there is 4 px padding at the sides and 3 px at the top and bottom. The text is a `Label` with `autowrap_mode = AUTOWRAP_WORD_SMART` and 232 px of width, so 29 glyphs per line at `HudStyle.GLYPH_PX`. Lines are 10 px high. A 4 px gap is followed by the close line.
- The height is padding + lines × 10 + gap + 10. At the 8-line cap that is 6 + 80 + 4 + 10 = 100, so the card ends by y = 122, well above the player and the prompt in the centre. The longest coast cay line wraps to 4 lines, which makes a 60 px card.
- The style is a new theme variation `HudNote`, a `StyleBoxFlat`: fill `HudStyle.CREAM`, 1 px border and text `HudStyle.OUTLINE`, so contrast is well above 7:1. The cream is the HUD's own text colour, so no new palette entry is needed. Labels inside use `HudNoteText`: the theme font, `OUTLINE` colour and no outline.
- The text comes from `IslandSign.line(session.locale)`. The close line is `HudText` `lines[&"close_note"]` = ("[%s] Cerrar", "[%s] Close"), with the key from the prompt's key label code.

**D4. The host-side bubble goes.**
- `IslandSign._on_interacted` and `CoopSession.show_sign` are removed.
- The sign keeps `hold_time_s = 0` and its prompt. The host's interact on it is a no-op, as the bench's is.
- Tests that read the bubble (`test_coast_cay_solo.gd`) are rewritten to read the note.

**D5. A data test guards the fit.**
- A unit test wraps every sign line of every `IslandLayoutData` in `game/resources/islands/` with the note's own wrap function (`SignNote.wrap_count(text) -> int`, which measures with the theme font) and requires at most 8 lines.
- A long line added later fails the test instead of overflowing the card.

## Risks / Trade-offs

- Teammates no longer see what a sign says unless they read it themselves. The owner chose this (2026-11-13).
- `Label` autowrap measures with the real font, and our GLYPH_PX estimate (8 px) is a monospace assumption. The fit test uses the label's own `get_line_count()` after layout rather than a character count, so a proportional font can't overflow.
- Walking away at the 1-tile edge could flicker the note open and shut. The crafting list's reach slack avoids that, and the note reuses the same constant.
