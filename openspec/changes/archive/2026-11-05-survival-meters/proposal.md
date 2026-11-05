# Proposal

## Why

Thirst is meant to be the main pressure of a 60–90 minute run, but the §4 numbers were written without a clock: at 1 thirst/min a full meter lasts longer than the run, and heat can never reach sunstroke (review item 18). `PlayerBody` already spends energy from a stub `SurvivalMeters`, and Milestone A's playtest ("can 2 players survive 3 days?") needs all six meters, real numbers and something on screen.

## What Changes

- **Clock.** One explicit ratio: 1 in-game hour = 30 real seconds (a 24 h day = 12 real minutes, as the data model already assumes). Provisional anchor: dawn starts at 06:00, so the day phase is 08:00–18:00, dusk 18:00–20:00 and night 20:00–06:00, and the 10:00–16:00 heat window is the middle 3 real minutes of the day phase. `weather-daynight` will run this clock; meters only read the phase and the midday flag.
- `SurvivalMeters` grows from energy only to all six meters (0–100, heat rising 0 → 100). The energy API (`energy`, `spend_energy`, `gain_energy`, `energy_changed`) keeps working.
- Retuned drains, all in one tuning resource (per real second in data, per minute below):

| Rule | §4 / spec today | Provisional |
| --- | --- | --- |
| Thirst base (at rest) | 1/min | **6/min** (0.1/s) |
| Thirst in direct sun / swimming / at night | ×2 / ×3 / ×0.5 | same factors: 12 / 18 / 3 per min |
| Hunger | 0.5/min, ×2 crafting or swimming | **3/min** (0.05/s), ×2 → 6/min |
| Heat rise, direct sun 10:00–16:00 | 2/min | **45/min** (0.75/s); scorching calm ×2 |
| Heat fall | 4/min in shade or water | **45/min** (0.75/s) in shade, in water, or outside 10:00–16:00; 0 at night |
| Energy, morale, health rates | swim 3/s, run 0.5/s, build 1/s; morale −5/min alone at night, +2/min with a teammate; thirst 0 → health −2/s | unchanged |

  What that means at the 30 s hour, for one player starting full at dawn:

| Play style | Thirst lost per day | Thirst lasts |
| --- | --- | --- |
| Whole day phase in direct sun | 87 | 1.15 days (≈ 14 min) |
| Half the day phase in sun | 72 | 1.39 days (≈ 17 min) |
| Resting in shade all day | 57 | 1.75 days (≈ 21 min) |

  Hunger lasts 2–2.8 days (36–51 per day). Heat: a player who never leaves the midday sun reaches sunstroke after 133 s (≈ 14:30 in-game), 67 s in scorching calm; half sun, half shade never does on a normal day; sunstroke clears 53 s after reaching shade.
- **3-day sandbar check** (2 players, half-sun play): 2 × 3 × 72 = 432 thirst, minus 200 banked, leaves about 230 to find. Ten coconuts give 150 (300 if "2 uses" means two drinks). A solar still at today's "1 cup per 2 in-game hours" would give +40 per real minute and make thirst irrelevant, so this check assumes **crafting-inventory rescales the still to 1 cup per 12 in-game hours (6 real minutes)**: one still built by the end of day 1 adds 4 cups (160) by day 3. Coconuts plus one still (≈ 310) or coconuts plus a few rain cups get 2 players through 3 days with effort; coconuts alone do not. This depends on two numbers crafting-inventory owns (still yield, coconut uses).
- Thresholds and states: thirst 0 drains health 2/s; hunger 0 caps energy at 50; sunstroke from heat 100 until heat < 60 (screen blur, speed −40%); morale < 20 sets a hallucinating state; health 0 downs a co-op player for 90 s (revive at 30 health) or kills a solo player. Timed changes (seawater −30 over 120 s, poison −20 over 30 s) are a meter primitive.
- `SurvivalMeters` now owns the downed state that `PlayerBody` kept as a placeholder; the body follows it.
- HUD: six labelled bars (Sed, Hambre, Calor, Energía, Ánimo, Salud) for the local player at 640×360 with the committed pixel font, plus the sunstroke blur. No ui-shell owns the HUD budget yet (review item 23), so this is a self-contained widget in the top-left corner that a later layout can move.
- `docs/GAME_DESIGN.md` §4 and §5 are updated to the same numbers and the clock.

**Provisional decisions, all confirmed by the user 2026-11-05** (each is one value or one rule). Also decided: only fresh-water cups (coconut, rain, still, well) revive, not seawater or rum; crafting-inventory applies it per item.
1. Every number in the table above, and the dawn-at-06:00 anchor.
2. Swimming ×3 replaces sun ×2 instead of stacking with it (no ×6); night ×0.5 multiplies whichever applies, so swimming at night is ×1.5 (there is no sun at night).
3. Outside 10:00–16:00 heat falls everywhere, not only in shade or water.
4. Morale is one meter per player; "morale is shared" (§10) is read as party-wide events: an ally's death or a squall hits every player.
5. A meal (+10 energy) is anything that restores hunger, so a coconut counts (data-model question 32).
6. Hunger reaching 0 lowers energy above 50 to 50 at once.
7. Downed players keep losing thirst and hunger; a downed teammate still counts as company for morale.
8. A co-op player whose teammates are only down (not dead) is not solo and still gets the 90 s. (What "solo" means is a user decision below.)
9. Energy never regenerates on its own: only sleep (+50 per night in shelter) and meals (+10).
10. Heat never costs health: §4 listed heat as a health drain with no number, and the spec's sunstroke only blurs and slows. Give a number if sunstroke should also hurt.
11. A lit fire within 5 tiles counts as company at night: it stops the −5/min "alone at night" drain (it does not give the +2/min of a teammate). Without it, one player can never stop the night drain: one fire a night (+5) still nets −20 per night, so a solo player would hallucinate around night 5 of a 5–7 night run. Fire is visible to patrols, so it stays a trade-off.

12. The downed-timer bonuses also lengthen a co-op player's 90 s, as endings-progression already says ("each player's own level applies to their downed timer").

**Decided by the user (2026-11-05), implemented here:**
- "Solo" means a player with no other living player: a one-player run, or the last one alive in co-op.
- Solo last stand: at 0 health a solo player is not downed; they get a last stand of 0 s base (run 1 stays brutal: death at once) plus the downed-timer bonuses: Experiencia +5 s per level and the +10 s point boost. endings-progression owns those numbers; the meters read one bonus value.
- Medalla de la Caridad, "one free revive per run": when the holder would go down or die with it unused, they stand at 30 health instead and it is used up. It fires by itself, so it works solo.
- During a solo last stand the player lies still (immobile, not draggable) and can drink a reviving cup they carry to stand at 30 health (confirmed on the PR, 2026-11-05).

**Solo play** (the game must be fully playable by one player). Nothing in the meters needs a teammate: a solo player is never downed (decision 8), so revive, feeding and dragging never apply to them, and decision 11 lets them hold morale. Solo budget on the sandbar: one player playing half in the sun loses 3 × 72 = 216 thirst in 3 days. Minus the 100 they start with, that leaves 116 to find, and ten coconuts give 150, so the sandbar's coconuts alone are enough (9 used if they drink below 15 thirst). A solo week with a fire every night and a squall every day ends at morale 65.

**Open questions** (not decided here):
- Which cups revive (review item 51)? Revive is an item effect (`EffectData.REVIVE`), so crafting-inventory decides per item; the recommendation is fresh water only, not seawater.
- Swimming energy versus 60–120 s crossings (review item 19) stays with player-movement and crossing; nothing changes here.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: every requirement gets the retuned numbers, the clock ratio and exact scenarios; "Meter component" adds the tuning resource and host-only simulation; "Morale" makes hallucinations a state whose visuals come later; "Health and downed state" makes the meters own the downed timer; a "HUD bars" requirement is added.
- `weather-daynight`: "Day cycle" defines the in-game clock (30 s per hour, dawn at 06:00) so heat's 10:00–16:00 window has a meaning.

## Impact

- `game/scripts/components/survival_meters.gd` (extended), new `SurvivalTuning` resource with its `.tres`, a meter context and a timed-change helper.
- Small additive changes to player-movement code: a speed factor for sunstroke in `MovementModel`, shade in `TerrainQuery`/`GridTerrain`, `PlayerBody` ticking the meters on the host and following their downed state.
- New HUD scene under `game/scenes/ui/`, shown in the movement playground.
- `docs/GAME_DESIGN.md` §4 and §5; `TASKS.md` §3.
- Tests: GUT for every scenario. Syncing meters to clients stays with `coop-networking`; items that drink, eat or revive come with `crafting-inventory`; the day cycle with `weather-daynight`.
