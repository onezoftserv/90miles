# Proposal

## Why

A flavour sign's line is drawn in the world as a speech bubble: 8 px white text with a thin outline over bright sand, on one unwrapped line of up to 100 characters, gone after 2.5 s. The owner found it hard to read in the `art-pass` playthrough (2026-11-13). Shattered Pixel Dungeon, Brogue CE and DCSS never put readable text over the map: they show it in a panel with a solid background, wrapped to the screen, and keep it until the player closes it. The owner chose that for our signs (2026-11-13), shown to the reader only.

## What Changes

- Pressing interact at a sign opens a **sign note** on the reader's own HUD: a light card with dark text, wrapped to the card's width, under the day phase, with a "[E] Cerrar" line. Nothing is sent to teammates; the press still reaches the host as an ordinary interact that changes nothing (as the bench's does).
- The note stays open until the reader presses interact or pause, walks out of the sign's reach, goes down, or a screen opens. It never pauses the run. While it is open, interact and pause act on the note only, as with the crafting list.
- **BREAKING (behaviour):** reading a sign no longer shows a speech bubble on every peer; `CoopSession.show_sign` and the sign's host-side bubble go away. Speech bubbles stay for quick chat and NPC lines.
- The close line and any note chrome text live in `hud_text.tres`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `island-generation`: "Flavour signs" — the reader sees the line in a note on their own HUD instead of a bubble over the sign on every peer.
- `inventory-hud`: adds "Sign note" (opening, contents, closing, input) and extends "Screens take input first" to the note.
- `ui-shell`: "HUD layout" — the open sign note's place under the day phase.

## Impact

- `game/scenes/levels/island_sign.gd` (no host bubble), `game/scenes/net/coop_session.gd` (`show_sign` removed).
- `game/scenes/ui/interact_prompt.gd` (a `sign_pressed` signal beside `bench_pressed`), `game/scenes/ui/run_hud.gd/.tscn`, a new `game/scenes/ui/sign_note.gd/.tscn`, `game/scenes/ui/theme/game_theme.tres` (a `HudNote` panel variation), `game/resources/hud_text.tres`.
- Tests: `test_coast_cay_solo.gd` (sign reading), new `test_sign_note.gd`, a host-plus-client case; the manual harness `tests/manual/art_pass_run.gd` checks the note instead of the bubble.
- No networking added; no new autoload.
