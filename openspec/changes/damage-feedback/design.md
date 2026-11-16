# Design

## Context

**What takes health today (surveyed 2026-11-14 on main a9dede9)**

| Source | Where | Kind | Size |
|---|---|---|---|
| Shark strike on a swimmer near an island | `CreatureWorld.strike` → `SurvivalMeters.harm` | hit (and sets BLEEDING) | `reef_shark.damage` 25 |
| Crab pinch | `CreatureWorld.pinch` → `harm` | hit | `land_crab.damage` 5 |
| Shark bite on a crossing swimmer | `Crossing.bite_swimmer` → `harm` | hit (and sets BLEEDING) | `shark_swimmer_damage` 25 |
| Drowning (no energy while in the water) | `Crossing._swim` → `harm` each frame | drain | `drown_health_per_s` 10/s |
| Thirst at 0 | `SurvivalMeters.tick` | drain | `dry_health_per_s` 2/s |
| Manzanillo | `METER_ADD` health −50 over 60 s, via `_advance_timed` | drain | 0.83/s |

The brief's list does not quite match the code:
- Bleeding is only a status flag. It makes a reef shark pick the swimmer and blocks the binoculars swim, but it takes no health itself.
- The crossing's fall-in (`Crossing.throw_in`) costs 10 energy, not health. Drowning follows only once energy runs out.
- Raw-food poison, the guao touch and oyster cuts are `APPLY_STATUS` effects, which `EffectApplier` skips with a warning. They take nothing today.
- `GrabData.damage_per_s` and the weather damage fields exist as data only.

Both `harm` (one call for a hit, or one per frame for drowning) and direct writes reach the `health` setter, which emits `meter_changed`. So the classifier must work from the value, not from which function was called.

**How health reaches each peer**
- Only the host ticks meters (`PlayerBody._tick_meters`). A client's own health is never predicted.
- `StateSync` replicates `SurvivalMeters:health` with `spawn = true`, `replication_mode = ALWAYS` (unreliable) and `replication_interval = 0.05`. A client sees health in steps of about 20 Hz, and a lost packet merges two steps.
- `IslandTravel._land` writes the carried health on the host. It is the same body with the same value, so it causes no change.

**Drawing**
- `PlayerLook` (`art_view`) draws each body every frame in `step(delta)`. `_draw_pose` sets `sprite.visible` every frame, so a blink cannot toggle visibility.
- `player_look.gdshader` multiplies by `COLOR` (modulate), so a white flash needs its own uniform.
- `test_art_sim_invariance` strips every `art_view` node and compares 600 frames.

**Item uses (added 2026-11-14 when the owner widened the change)**
- The strip picks the use (`UsePlan.choose`) and checks it as the host will (`UsePlan.actor_reason`, then `ItemUser.check`). On a refusal it shows a line from `HudText.refusals` on its `HudNotice` row (y 306–316, 400 px, under the band's top) for 2 s. Otherwise it sends `CoopSession.use_item`.
- The host's `use_for` returns a bool that `request_use` drops, so nothing confirms a use beyond the bars moving.
- `ItemUser.use` applies effects through `EffectApplier`. It interprets these kinds:
  - METER_ADD (a hunger gain at once is a meal: `eat()` adds energy);
  - CURE_STATUS;
  - REVIVE;
  - GIVE_ITEM and TAKE_ITEM;
  - START_ROUTE;
  - SET_FLAG and CLEAR_FLAG.

  It skips every other kind, APPLY_STATUS among them.
- Sábila cures SUNBURN, then BLEEDING, and can go on a teammate. Item descriptions (`description_es`) are never shown in play.
- `status_flags` replicates to every peer (status-sync), so a cure is visible everywhere.

**HUD and settings**
- `MeterBar` pulses at 25 or less (`MeterBar.is_critical`).
- `MetersHud` already holds a full-screen `Blur` overlay (mouse ignored, not a `HudPanel`), so `RunHud.panel_rects()` does not count it.
- `GameSettings` keeps name, fullscreen, scale and pixel filter in `user://settings.cfg`.
- `AudioManager` is an empty stub.

## Goals / Non-Goals

**Goals:**
- The same cue on the host, a client, a late joiner and a watcher, computed only from replicated health.
- Nothing on the wire, no simulation code touched, and the art/sim invariance run passes with a hit inside it.
- Every number lives in a `.tres`.

**Non-Goals:**
- Knockback or invulnerability frames: both change the simulation.
- Hit messages in a log (we have none), cues per cause (they need the cause, which only the host has), and real sounds (none exist yet; this change adds only the hook).
- Sábila's own gameplay (a bleeding drain, treating teammates, a sunburn source) and any item effect: a separate session owns them.
- Showing item descriptions (`description_es`) in play.
- Cues on the teammate list or name tags. The HUD restyle in review owns those panels; a later change can add them.
- Restyling the bars. This change only adds nodes inside `MeterBar` and one overlay in `MetersHud`.

## Decisions

### D1. Reference games (ideas only; nothing copied)

**Shattered Pixel Dungeon**
- `CharSprite.flash()` (`sprites/CharSprite.java`) paints a struck sprite white for an instant on every hit, then restores its colour. **Borrowed:** the one-frame white flash before our blink.
- `Hero.damage` (`actors/hero/Hero.java`) flashes the whole screen red through `GameScene.flash`. The strength grows with the share of current health lost and with how hurt the hero already is; tiny hits do not flash, and the strength is capped. Two warning sounds follow the strength.
  - **Borrowed:** the strength scales with the hit.
  - **Borrowed:** the split between hits and mild damage over time. The same method interrupts the hero for any damage except a `Hunger` tick.
  - **Rejected:** skipping small hits. A crab's 5 being unseen is the owner's complaint, so we keep a floor instead.
  - **Rejected:** tinting the whole screen. We flash only the edges, so the centre stays readable (ui-shell "HUD layout": the centre holds no panel).
  - We write our own curve; neither the formula nor its constants are ported.
- `FloatingText` (`effects/FloatingText.java`) floats numbers up about one tile over a second, stacked per character so they never overlap. Damage and healing each have their own colour and icon. `Healing` (`actors/buffs/Healing.java`) shows each heal tick as a positive float.
  - **Borrowed (Q7):** a rising, stacked float for jumps and cures, coloured per meter. Hits get no number (owner, Q3 A).
  - Our drains do not float, unlike SPD's heal ticks, so slow changes stay quiet.
- `StatusPane` (`ui/StatusPane.java`) pulses the hero's portrait red below a third of health, faster as it falls. **Already ours:** `MeterBar`'s pulse at 25 or less; unchanged.
- `SPDSettings.screenShake` with `PixelScene.shake` shakes on heavy events, set from 0 to 4. **Borrowed:** every shake and flash obeys one player setting.

**Brogue CE**
- `flashMonster` (`Combat.c`), called from `inflictDamage`, flashes the struck cell in the attack's colour. Its strength is a minimum plus a share that grows with damage as a part of max health. **Borrowed:** a floor plus scaling for the edge flash.
- `combatMessage` with `messageColorFromVictim` (`IO.c`) prints the player's own hurts in `badMessageColor`, a red. **Rejected:** we have no message log. A "¡Te mordió un tiburón!" notice would be its own change.
- The sidebar's health bar (`printProgressBar` in `IO.c`) blends from blue to red as health falls. **Not borrowed:** our fill keeps its colour, and the pulse covers low health.

**DCSS**
- `colour_bar` (`output.cc`, used as `HP_Bar`) draws the part just lost in a "change" colour (red for HP) until a later redraw shows the plain new value. **Borrowed:** the lost chunk in pale red that holds, then goes.
- `_print_stats_hp` (`output.cc`) colours the HP number by the `hp_colour` thresholds. **Not borrowed:** the pulse covers it.
- `player.cc`'s low-HP warning (`Options.hp_warning`) flashes the view red (`flash_view_delay`) and prints a danger line when health falls under a set share. **Follow-up idea:** a one-off flash on crossing 25.
- I found no "You are hit" line as such. DCSS's attack lines are part of its message log, rejected as for Brogue.

**Don't Starve Together** (dontstarve.wiki.gg; `docs/REFERENCE_DST.md` has no hurt notes)
- "Health" and "Health Meter": the heart badge empties as health drops. No arrow, flash or pulse on the health badge is confirmed [unverified].
- "Sanity": an arrow on the badge shows the meter rising or falling, larger when faster. **Borrowed, adapted:** the drain glow marks "draining now". It is a glow, not an arrow, so the bar keeps its row.
- "Freezing" and "Overheating": slow environmental damage shows as frost or heat creeping in from the screen edges, in stages and with sounds. "Hunger": the meter flashes while starving.
  - **Borrowed:** a drain is shown apart from a hit, and on the meter.
  - **Not borrowed by default:** edges for drains. We keep the edges for hits so the two never blur; Q4 B offers it.
- "Knockback" and "Stunning": heavy hits knock a character down and interrupt them, and light ones stagger briefly. **Rejected:** both move or stop a body the host simulates.
- "Sanity" (Trivia): the distortion overlay can be turned off in the options. Shake options come from forum reports only [unverified]. **Borrowed:** one switch that turns off every flash and shake, with no source left out.

**Use feedback (the coordinator's research, checked in `reference/` where it is code)**
- **SPD:**
  - `Food.java` satisfies hunger and logs a line on eating.
  - `StatusPane.java` and `Healing.java` are covered above.
  - **Borrowed:** the use answers right away, on the body and on the bar.
- **Brogue CE:**
  - `eat()` (`Items.c`) asks before eating when the player is not hungry enough to use the whole food. **Borrowed, stronger:** we refuse only when the use would do nothing at all (Q6 A). A partial waste goes ahead, since we have no confirm dialog.
  - `creatureHealthChangePercent` (`IO.c`) drives the sidebar's change display from the previous and current health. **Borrowed:** the change is computed from two values the peer already has, not from an event.
- **DCSS:**
  - `colour_bar::draw` (`output.cc`) draws a gained part in `m_change_pos` and a lost part in `m_change_neg`. **Borrowed:** both slices.
  - `PotionEffect::check_known_quaff` and the `can_quaff(reason)` overrides (`potion.cc`) refuse a known potion that would do nothing, with a reason. **Borrowed:** the refusal.
  - `_uselessness_desc` (`describe.cc`) adds a line explaining why an item is useless now. **Borrowed:** the reason names the meter or status.
- **DST:**
  - "Sanity": the badge's arrow shows the direction and speed of a change.
  - "Quotes": characters speak a line when using or examining things.
  - **Borrowed:** the direction, through slices on the bar and floats.
  - **Not borrowed:** spoken lines on every use. They would be a dialogue change, and our floats already say what happened.

**The coordinator's research pass (2026-11-15, `reference-feedback-hud.md` in the shared notes; ideas only)**

*Folded in, inside the owner's answers:*
- **Flash strength:** it is measured against the share of max Salud lost. A floor makes every real hit read, a cap keeps big hits from blinding, and a cluster of hits keeps only the strongest. This follows SPD `Hero.damage()` → `GameScene.flash()` and Brogue `flashMonster` with `MIN_FLASH_STRENGTH`.
  - Max Salud is the base, rather than current Salud, so a hit reads the same at any health.
  - Low health already pulses the bar.
  - This is D5's curve; max Salud is 100, so `hit / big_hit` is the share over a quarter of the bar.
- **A huge hit:** it gets the heavier sound (`hurt_big`) and the full-strength flash, following DCSS `ouch()` and SPD's two warning sounds.
- **The lost chunk:** it is measured from the value the peer saw on the frame before the hit (the watch's last value), not from the bar's display. It is drawn in the newly empty part of the bar, held, then drained. This follows DCSS `colour_bar::draw` and Brogue `creatureHealthChangePercent`. Health has no passive regen today, so there is nothing to leave out.
- **"Not now" and "never":** the wording tells them apart, following DCSS `can_quaff` and `_uselessness_desc`.
  - "No tienes sed." and the other wasted-use lines mean not now.
  - "Eso no se usa así." means never.
  - One check (`ItemUser.check`) drives the HUD's refusal and the host's.
- **Waste before use:** the effect line shows it from the meter's headroom, for example "Sed +15 (+6 útil)", following Brogue `itemDetails`' food check (D11).
- **After use:** the float shows the effective, clamped gain ("+6 Sed" when only 6 fit), following SPD `Dewdrop.consumeDew()`. The watch measures the real change, so this needs no extra work.
- **Stacking:** floats stack per body. A new float pushes the older ones up, as in SPD `FloatingText.push()` (D9).
- **No modal confirm and no text log** as the main channel: we refuse instead, as the brief advises.

*Adapted:*
- **"Drains told apart by source, not size"** (DCSS `ouch()` poison exemption, SPD `Hunger`). The source (`SurvivalMeters._last_harm`) lives only on the host, and syncing it would add a replicated property (D2). Our test is not size either: it is the loss against the body's recent steady trend (D3). That gives the same answer for every source we have, and on every peer.

*Optional follow-ups, not built here; each would add scope or reopen an owner answer:*
- a forecast segment for losses still to come (SPD `Char.incomingDOT()`); the remaining timed loss is host-only state;
- one-time low-Salud threshold cues and label colour steps (DCSS `hp_colour`, Brogue `handleHealthAlerts`);
- an orange heat-warning haze at the edges, kept apart from the red (DST "Overheating");
- dimming slots that can't be used right now (SPD `itemSelectable()`, DCSS `TILEI_FLAG_INVALID`), which belongs with the HUD restyle that owns the slots;
- meter icons on floats;
- folding repeated floats into one with a count (Brogue message folding);
- a float naming a status a hit applies ("Sangrando");
- sips that spend only what the meter needs (SPD `Waterskin`), a gameplay change.

**GBA conventions, matching our art direction C** (general knowledge, no assets)
- In *A Link to the Past*, a hurt Link flashes and blinks while briefly untouchable, is knocked back, and his hearts empty.
- In GBA-era Pokémon battles, the hurt monster blinks and the HP bar slides down rather than jumping.
- **Borrowed:** the blink and the sliding bar.
- **Rejected:** knockback and untouchable time, both simulation.

### D2. Derive the cues from replicated health on every peer

Each cue holds a `MeterWatch` (a pure `RefCounted`), one per watched meter, which reads that meter's value, `meters.dead` and `status_flags` once per drawn frame in its owner's `step(delta)`.
- On the host that is the simulated value. On a client it is the value `StateSync` last set.
- There is no signal handler, so nothing runs inside the simulation step. That keeps the global RNG order and the invariance run exact.

**Alternatives**
- A synced hit counter written by `harm()`. Rejected: it adds a replicated property (coop-networking owns that list) and an edit to the simulation, and drowning also calls `harm`.
- An RPC per hit. Rejected: it is a message on the wire for drawing, and it needs reliability and late-joiner rules.
- The value already carries everything a cue needs.

### D3. The classifier

`MeterWatch.observe(value, dead, delta) -> int` returns NONE, HIT (a loss at once), DRAIN (a slow loss) or JUMP (a gain at once). It keeps `last_change`, the signed size of the HIT or JUMP. The same test runs in both directions:
- a rise at least `hit_margin` above the steady trend is a JUMP;
- a slower rise only moves the baseline (slow regain).

For health, HIT and DRAIN feed the hurt cues. For the other meters a sudden loss is also reported, as HIT, and floats its signed change like a JUMP. Heat counts the same way, signed. Cures come from a separate `StatusWatch`: a bit cleared in `status_flags` since the last frame, with the same baseline rules.
- **Baseline:** the first observation, the first one after `reset()` (rebind, spectate switch) and any observation while dead set the baseline and return NONE. A rise also only moves the baseline.
- **Steady rate:** `rate` is the body's recent drain, learned from losses classed as drains: loss ÷ time since the previous loss. It drops to 0 once `drain_forget_s` (1 s) passes with no loss.
- **Hit test:** on a loss `L`, with `t` the time since the previous loss (capped at `drain_forget_s`):
  - `expected = rate × t`;
  - `L − expected ≥ hit_margin` (3) is a HIT of size `L − expected`, and the rate is kept;
  - anything else is a DRAIN and updates the rate.
- **Worked cases:**

  | Case | Expected | Loss | Result |
  |---|---|---|---|
  | Client drowning, 0.5 s of updates lost | 10 × 0.5 = 5 | 5 | drain |
  | Isolated crab pinch | 0 | 5 | hit |
  | Shark bite while drowning on the host | 10/60 | 25.17 | hit of about 25 |
  | Host thirst tick | — | 2/60 | drain, whatever the frame rate |

- **Known edge:** if a drain's first losses arrive as a single merged packet of 3 or more (drowning starts during more than 0.3 s of packet loss), that one update reads as a hit. It is rare and harmless, and it is recorded rather than fixed.

### D4. The body cue lives in `PlayerLook`, through shader uniforms

`PlayerLook.step` feeds its `MeterWatch`. On a HIT, a `HurtBlink` (a pure state) starts. It holds the time since the hit and turns it into three uniforms, set after the water-line cut:
- `hurt_white` is 1 for the first frame;
- `hurt_hidden` toggles at `blink_hz` (10 Hz, every 3 frames at 60) until `blink_s` (0.6 s);
- `hurt_tint` is the steady red used in its place while reduce flashes is on.

Time comes only from `delta`: no Tween, Timer, await, `_enter_tree` or RNG. `_draw_pose` still owns `sprite.visible`, and the blink goes through the shader's alpha.

**Alternative:** a separate child node toggling `modulate`. Rejected: `modulate` cannot make the sprite white, and a second node would race `_draw_pose`.

### D5. The screen cue lives in `MetersHud`

`MetersHud` gets a `HurtOverlay` (a `ColorRect`, full rect, mouse ignored, not a `HudPanel`, beside `Blur`) and a `MeterWatch` that follows `bind()`: a rebind calls `reset()`.
- The overlay's shader draws red only near the edges, in a band about 24 px deep, and leaves the centre clear.
- **Strength:** `lerp(flash_floor, 1, clamp(hit / big_hit, 0, 1)) × flash_alpha`, with `flash_floor` 0.5, `big_hit` 25 and `flash_alpha` 0.45. It fades linearly to 0 over `flash_s` (0.4 s).
- **Rate limit:** a hit within `flash_min_gap_s` (0.33 s) of the last flash does not restart it; it only raises the current strength to the higher of the two. So the edges never flash more than three times a second.
- With reduce flashes on, the overlay never shows.

**The bar chunk and shake**
- `MeterBar` gets a `Lost` `ColorRect` inside `Bar`, from the new fill's end to the old value's, in pale red. It is driven by `show_loss(old, new)` and a per-frame `step`.
- The chunk holds for `chunk_hold_s` (0.4 s), then shrinks over `chunk_drain_s` (0.5 s).
- A HIT also shakes: `Bar.position.x` is offset ±1 px every 2 frames for 0.2 s, then the row is re-sorted so the container puts the bar back. A drain or reduce flashes skips the shake.
- Only the health row gets `shows_loss = true`, an export set in `meters_hud.tscn`.

**The drain glow**
- A `Glow` `Panel` inside the health bar draws only a red border (`StyleBoxFlat`, `draw_center = false`). It shows while the watch saw a DRAIN within `glow_linger_s` (1 s).

**The watched body**
- The HUD's watch reads whatever `MetersHud` is bound to. A dead spectator watching Papo therefore sees Papo's hits on their screen, as dead-spectate intends.

### D6. Reduce flashes

- `GameSettings.reduce_flashes: bool` is saved as `display/reduce_flashes`. The settings screen gets a "Reducir destellos" `CheckBox` under the pixel filter.
- Settings already load in the shell (`GameShell`), and `PlayerLook` instances have no path to it. So the shell writes a static `HurtCues.reduce_flashes` when settings load or change, and every cue reads it.
- The setting is per install, so one static per process is right. Tests reset it in `after_each`.
- **Alternative:** a group call to every look. Rejected: it misses bodies spawned later.

### D7. The sound hook

- `AudioManager.play_sfx(id: StringName) -> void` is documented as a no-op until sounds exist. It is a method on the existing autoload; no autoload is added.
- `MetersHud` calls it for the shown body only:
  - `&"hurt_hit"` below `big_hit`;
  - `&"hurt_big"` at `big_hit` or more;
  - `&"hurt_drain"` when a drain starts, at most once per drain;
  - `&"use_done"` when a JUMP or cure lands on the shown body, at most once per frame.
- It also emits `hurt_cued(kind)`, so tests assert on the node. In-process host and client share the autoload, so assertions must not go through it.

### D8. Data

`HurtCueTuning` (a `Resource`) holds every number above. It loads from `game/resources/hurt_cue_tuning.tres`, so tuning needs no script edit.

### D9. Change floats are HUD marks anchored to the head

`RunHud` gets one `ChangeFloats` control beside `Marks`. It keeps a `MeterWatch` per meter and a `StatusWatch` for every body in the session, the way `_follow` gives each body a name tag.
- **When a float is made:** on a JUMP, a non-health HIT (a sudden loss of thirst, say) or a cure, it adds a `Label` in the pixel font. A health HIT never floats (owner, Q3 A).
- **What it says:**
  - `"%+d %s"` with the meter's word from `hud_text.tres`;
  - `"Sin %s"` with the status word.
- **Colour:** each meter's colour comes from `HurtCueTuning.meter_colors`, and a test keeps it equal to the `fill_color` set in `meters_hud.tscn`, so a restyle that changes one fails until both agree.
- **Placement:** each float starts at the body's head anchor (`BodyLook.head_anchor_y`), above the name tag when that shows, and rises 12 px over `float_s` (1 s) while fading.
- **Stacking:** a new float on a body pushes the ones still showing up by `float_stack_px` (9 px), so floats made together, or close together, never overlap. This follows SPD `FloatingText.push()`.
- They are world-anchored marks, so ui-shell "Inventory band and world marks" already allows them in the centre.
- They are drawn on the HUD layer, not in the world, so the pixel filter does not blur them, matching name tags.
- A body leaving the session frees its floats.

**Alternative:** a `Label` under `PlayerLook` (`art_view`). Rejected: world-space text goes through the pixel filter and the camera, and name tags already set the HUD-side precedent.

### D10. Bar slices for gains as well as losses

`MeterBar` gets `Lost` (pale red) and `Gain` (its fill colour lightened) `ColorRect`s, and every bar shows both.
- **A JUMP** spans the gain from the old value to the new one. It holds `gain_hold_s` (0.6 s), then blends into the fill over `gain_fade_s` (0.4 s), and the bar is brightened for 2 frames.
- **A loss** keeps D5's hold and drain. Only the health bar shakes, and only on a HIT.
- With reduce flashes on, there is no brightening and no shake.
- The drain glow stays on health only.

### D11. The effect line is built from the use's data

`EffectLine.text(action, actor, target, words, tuning, locale)` walks `action.effects` in order and keeps only the kinds `EffectApplier.apply_now` interprets:
- METER_ADD becomes "Sed +15", or "Salud -50 en 60 s" when `duration_s > 0`;
- a hunger gain at once also adds "Energía +N" from `SurvivalTuning`'s meal energy, as `eat()` does;
- CURE_STATUS gathers into "Cura a y b";
- REVIVE becomes "Levanta";
- GIVE_ITEM becomes "Da %s" and TAKE_ITEM "Gasta %s";
- START_ROUTE uses its route's verb;
- flags say nothing;
- a delay adds "a los %d s".

When a meter gain at once would not fit under the subject's cap, the part shows what is useful too, "Sed +15 (+6 útil)" (Brogue's food check). The part is worked out from the same dry run as D12, so the meal energy and the starving cap count. The parts join with " · " and are cut with "…" at the row's 50 characters.

**Guarding against drift:**
- A test lists `EffectApplier`'s interpreted kinds and asserts that `EffectLine` handles exactly those.
- A content test builds every item's line.

So a session that teaches the applier a new kind (sábila's fix may add APPLY_STATUS) gets a failing test until the line has words for it.

**Where the line sits:** it lives on the strip's notice row (`HudNotice`), shown while no notice is up. A refusal still takes the row for 2 s and then the line returns, so the band's layout does not change (Q5 A).

### D12. `NOTHING_TO_DO` is decided by a dry run

`ItemUser.check` gets a last reason, `NOTHING_TO_DO`, after CONDITION, so both the HUD and the host use it.
- **The "something" kinds:** if the use has any kind other than METER_ADD with a positive amount at once, or CURE_STATUS, it is never wasted. That covers a revive, items, routes, flags, a delay, a change over time, any loss, and kinds the host does not apply yet (so a horn or a raw crab is never refused with an odd reason). An item that leaves a remainder (a conch's horn) is never wasted either: it always gives something.
- **The dry run:** otherwise the check copies the subject's meter values and statuses into a scratch `SurvivalMeters` outside the tree, with the same tuning, and applies the METER_ADD and CURE_STATUS effects there through the same setters (`eat`, `add`, `set_status`). The use is wasted if the flags come out unchanged and no meter moves by 1 point or more: the HUD shows whole points, and a living player's meters drain all the time, so "full" is 99.9 as often as 100. Energy's starving cap and a meal's energy come along for free.
- **The reason line:**
  - `refusal_wasted_meter_<meter>` for the first meter it raises ("No tienes sed.", "No tienes hambre.", "No 'tás cansao.", "'Tás entero.", "'Tás de lo más bien.", "No tienes calor.");
  - `refusal_wasted_status_<status>` when it cures one status ("No 'tás sangrando.", "No 'tás quemao.");
  - `refusal_wasted_cures` for several ("No hay na' que curar.");
  - `refusal_wasted_other` with the teammate's name ("A %s no le hace falta.").

  All of them live in `hud_text.tres`.
- This is the change's one simulation edit. It is a rule the host enforces, not drawing, and the invariance run never uses an item.

**Alternative:** decide waste by reading the effect amounts against the meter values directly. Rejected: it would have to re-implement the meal rule and the energy cap, and drift.

### D13. Floats and slices for uses come from the same watches

No result message is sent for a use. `request_use`'s dropped bool stays dropped, and the HUD learns what happened from the meters and statuses the inventory sync already brings, like a teammate does. So a use, a lagoon drink and a revive all answer the same way on every peer.

**Alternative:** an RPC carrying the use's result. Rejected: a second channel for the same facts, with its own late-joiner and ordering rules.

## Risks / Trade-offs

- **[Late join spawn order]** If the spawn state lands after a look's first `step`, the first frame would read 100 and the next 60 as a hit. → The late-joiner net test is written first. If it fails, the baseline also waits for the body's first `StateSync.synchronized`. There is no wall-clock settle.
- **[Merged packets at a drain's start]** One false hit is possible (D3). → Accepted and documented; the cue is harmless.
- **[HUD restyle in review]** It may touch `meter_bar.tscn` and `meters_hud.tscn`. → Only child nodes and one overlay are added; nothing is moved or restyled, so the merge stays small.
- **[GUT time budget]** CI's GUT step times out at 300 s and the suite takes about 248 s. → Net tests await only the sync, then step the cue time by hand. No real-time waits for blinks.
- **[Static setting]** `HurtCues.reduce_flashes` leaks between tests. → Reset in `after_each` in every test that sets it.
- **[Shake versus container]** `HBoxContainer` can re-sort mid-shake. → The shake rewrites the offset every frame and re-sorts at the end.

- **[Tests that use items at full meters]** Meters start full, so a test that drinks or eats at defaults would now be refused. → Before writing D12, grep the tests for uses (`ItemUser.use`, `use_for`, `use_item`) and set a meter below full where the test means the use to happen. That is a test fix, not a behaviour change.
- **[Energy reconciliation on a client's own body]** `PlayerNet` writes predicted energy back to the host's value, which could look like a jump. → Corrections are far below 3 in the prediction tests. A net test walks a client and asserts no energy float, and the threshold moves to tuning if it fails.
- **[Float clutter in co-op]** Four bodies with drains and uses could crowd the screen. → Drains never float, and floats last 1 s and stack per body. The two-process run checks it by eye once.

## Migration Plan

None. The setting defaults to off, and an old `settings.cfg` without the key reads as off.

## Owner decisions

**Answered 2026-11-14:**
- **Q1 A:** a white frame, then a 0.6 s blink.
- **Q2 A:** the edge flash, the bar chunk and a 1 px bar shake.
- **Q3 A:** no damage numbers. This was asked before floats for uses existed, so hits stay without a number and only jumps and cures float.
- **Q4 A:** the chunk and a dim glow on the Salud bar.
- **Also approved:** the reduce-flashes checkbox, no knockback, and the AudioManager hook. The hook is a method on the existing autoload; no new autoload.

**Answered 2026-11-15:**
- **Q5 A:** the effect line goes in the refusal row above the item's line, and a refusal takes it for 2 s.
- **Q6 A:** a use is refused only when no effect would change anything.
- **Q7 A:** any meter jumping at once on any body, and cures, float on every peer; slow regains don't.
