## Why

A run ends with a card that says only who died and for how long. Milestone B's last summary task asks for the death to mean something. Each player gets the cause of their death and a Cuban one-liner. The summary shows the run's totals. A solo player can go again without the title. The data model already expects death lines (`DialogueData.Kind.DEATH_LINES`), and `docs/CONTENT_MANIFEST.md` lists "death one-liners (20)".

## What Changes

- Every health loss names a cause. `SurvivalMeters.harm(amount, cause)` records it, and `death_cause` is set just before `dead`. The causes are `thirst`, `drowning`, the attacking creature's id (`reef_shark`, `land_crab`) and `other`. A downed player or a last stand keeps the cause that put them down. The cause replicates to clients before `dead`.
- A removed player counts as `removed`, unless their meters died while they were away. Every peer and late joiners get the causes.
- 20 handwritten draft death one-liners as content (`game/resources/dialogue/death_one_liners.tres`), read by `DeathLines`. Each line is picked from a new run seed the host rolls at each run start and sends in the world state.
- The summary (`RunSummary` and a wider `SummaryScreen` built from `SummaryRow`s) shows islands reached, days, length, companions and texts ("ninguno" until they exist), and one row per player. Each row has the fate, the cause label, the one-liner and an empty, hidden tip line. Each entry carries `cause`.
- "Otra vez" restarts a solo run cleanly. Co-op summaries offer only "Volver al inicio". A client's summary survives the host leaving. The HUD (and its pause menu) goes when the summary shows, and a new run never starts paused.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: adds "Cause of death" and "Cause ids".
- `coop-networking`: adds "Removed player's cause".
- `endings-progression`: adds "Cause of death on the run summary", "Death one-liners", "One-liner picked by the run seed", "Run summary totals", "Restart from the summary" and "A fresh run starts clean".

All three are ADDED requirements only: `ui-shell` has no main spec yet (its "Screen flow" sentence is refined, not modified; see D7), and the unarchived `secret-cay` and `coop-reconnect` changes MODIFY the blocks nearest to these.

## Solo

Solo is first class. All causes, the summary and the restart are tested with exactly 1 player, offline. One solo player dies of thirst on the sandbar, drowns in a crossing, is struck by a shark, pinched by a crab and poisoned. One reaches the coast cay and restarts clean on the sandbar.

## Not in this change

Endings and companions' fates, Experiencia carry-over and levels, keepsakes and the profile, challenge toggles, AI-generated one-liners (the backend), `la_captura` and capture deaths, a profanity toggle (the soft variants are written now), English UI strings, a co-op rematch with the same peers, seeding crossings or islands from the run seed, spectating, high scores or a run history file.

## Status causes (checked after PR #26, `status-sync`)

No status takes health today. Bleeding (the only status the game sets) is a flag the HUD and the sharks read; `SurvivalMeters.tick` has no status branch, and the shark's damage goes through `harm` with the shark's own id. So there is no `bleeding` cause and no status line. Rule for later: when a status starts taking health, it gets its own cause id, lines and a test in the same change.

## Confirmed by the owner (2026-11-08)

- **D3 Co-op restart.** Co-op summaries (host and clients) offer only "Volver al inicio"; a client keeps its summary if the host leaves; solo gets "Otra vez" (a clean new run).
- **D2 Creature causes.** A creature kill records the creature's id (`reef_shark`, `land_crab`); new creatures fall back to `other` lines.
- **D8 Hunger, heat, energy, morale.** Not causes: they take no health.
- **D12 A downed death's cause.** A downed death keeps the cause that downed the player.
- **D6 Removed, but already dead.** A removed player who had already died keeps that cause.
- **D9 Fallback id.** `other`.
- **D4 and D5 The pick.** The line is `(run_seed + n) mod count`, from a `run_seed` the host adds to the world state now.
- **D13 Profanity.** Full lines are shown until the profanity toggle exists; the soft variants are written and tested.
- **D11 The 20 lines** are drafts for the owner's voice pass (also stated in the data file's name, "Frases de muerte (borrador)").
- **D1 Days.** "Días" is the clock's day, from 1.
- **D10 Labels.** The summary labels live in code, Spanish, like the other shell strings.
- **D7 No `ui-shell` delta.**

## Provisional decisions

Confirmed by the owner as they stand on 2026-11-08, at the archive. Each is data or a named constant. The 20 lines carry the owner's review of 2026-11-08 (two drowning lines rewritten, ETECSA named in a lost-signal line, the Cuban contractions) and stay drafts for the voice pass.

- The 20 line texts (split thirst 4, drowning 4, reef_shark 4, land_crab 2, removed 3, other 3), at most 120 characters per language.
- Panel 576x328 at (32, 16), scroll area at least 200 px, row separation 6, wrap at about 68 glyphs.
- Strings: "Murió (%s)", "Sobrevivió", "(se fue en: %s)"; labels "sed", "ahogamiento", "desconexión", "causa desconocida"; "Islas: %d", "Días: %d", "Duración:", "Compañeros: ninguno", "Textos: ninguno", "%d salvados, %d perdidos"; "Otra vez", "Volver al inicio", "El anfitrión cerró la partida."
- The run seed is `randi()`, rolled per run start by the host or solo; it is not yet used for crossings or islands.
- The summary's `Fate`, `Line` and `Tip` labels use the `PanelLabel` theme variation.

## Impact

- **Code:** `survival_meters.gd`, a new `death_cause.gd`, `player.tscn` (one more replicated property), `crossing.gd`, `creature_threats.gd`, `creature_world.gd`, `night_thief.gd`, `coop_session.gd`, `island_travel.gd`, `game_shell.gd`, `summary_screen.gd/.tscn`, and new `death_lines.gd`, `run_summary.gd`, `summary_row.gd`.
- **Content:** `game/resources/dialogue/death_one_liners.tres`.
- **Network:** one more replicated property before `dead`; `record_removed` and `receive_lobby` carry the causes; `run_seed` and `islands` join the world state.
- **Tests:** five new files (about 49 tests) plus one joiner test and the pinned field list.
