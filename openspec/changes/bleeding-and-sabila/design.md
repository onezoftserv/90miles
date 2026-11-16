# Design

## Context

See proposal.md, Why. The current state, on main 8edc5ab:

- **Statuses.** They are one synced int of bit flags (`SurvivalMeters.status_flags`, from `status-sync`). Only the host sets them (`set_status`), and they have no time attached. `SurvivalMeters.tick` has no status logic.
- **Where bleeding starts.**
  - `CreatureWorld.strike`, a reef shark's strike on an island.
  - `Crossing.bite_swimmer`, a shark's bite in a crossing.
  - Nothing else. The oysters' cut (pick-up), the broken bottle's 10 s (a hit effect) and the crocodile's death roll are data or spec only, and wait for `item-effects-runtime`, `player-weapons` and the crocodile.
- **What reads bleeding.**
  - Sharks pick a bleeder (`PatrolCircleStrike`, `ScriptedThreats`).
  - Binoculars-and-swim refuses a bleeding swimmer.
  - The "Sangrando" tag on the HUD.
- **Sábila.** `aloe.tres` has one use (APPLY, 1 s, `can_target_others`) with two `CURE_STATUS` effects on the use target: SUNBURN and BLEEDING.
  - There is aloe only on the coast cay (×4). The sandbar has none.
  - The Médico's starting sábila waits for the starting kits (content batch 9).
- **Teammates.** The host already lets a use go to a teammate within reach. `CoopSession.use_for` checks reach with `UsePlan.actor_reason`, using `HOLD_REACH_PX`. But `UsePlan.choose` aims at others only for revives, so the button never sends sábila to a teammate.
- **PR #65 (`damage-feedback`, open and green).** It adds `UseOutcome.changes_nothing` and the `NOTHING_TO_DO` refusal:
  - a use is refused when its cures and instant positive meter gains would change nothing for its subject;
  - any other kind of effect counts as "does something";
  - it sorts a steady health loss as a drain and glows the Salud bar for it;
  - it does not touch `use_plan.gd`, `survival_meters.gd` or `aloe.tres`.
- **Meters during a crossing.** Meters tick during a crossing: only `left_island`, set while a rider waits out of play on arrival, stops `PlayerBody._tick_meters`. Every use is refused at sea (`AT_SEA`), so a wound taken in a crossing can't be treated until landfall.
- **Solo run 1.** `solo_last_stand_s` is 0, so on run 1 a solo player at 0 health dies at once.

## Goals / Non-Goals

**Goals:**
- Bleeding becomes a real but bounded cost that one player can always outlast without a cure.
- Sábila is worth carrying: it is the bleeding cure and a small heal.
- Its existing "or a teammate" use works from the button.

**Non-Goals:**
- `APPLY_STATUS` in `EffectApplier`, and the magnitudes of poison, burning and hallucinating (`item-effects-runtime`). Interpreting `APPLY_STATUS` now would also fire raw-food poison every time, because `chance` is not rolled yet.
- Any HUD file: the time-left bar, a sunburn tag, a lethal warning. `damage-feedback` and `hud-window-kit` own the HUD.
- A bandage item (CHARACTERS.md, BESTIARY.md "Bandage cuts"). No item list has one yet.
- Changing creature or crossing numbers.

## References

Ideas only. No code, data tables or text were copied.

**Shattered Pixel Dungeon**, `actors/buffs/Bleeding.java`:
- **Borrowed:** a second wound is not a second bleed. `Bleeding.set()` keeps the larger level and never adds two, so our new wound restarts the time and does not stack a second drain.
- **Borrowed:** bleeding ends without a cure. `act()` deals damage and then shrinks the level until `detach()`.
- **Rejected:** the random shrink (`Random.NormalFloat(level/2, level)`). A constant rate for a fixed time reads better on a bar and is easy to test.
- **Rejected:** bleeding that kills (`Dungeon.fail`); see D3.
- **Borrowed:** the cure also heals. `PotionOfHealing.cure()` detaches `Bleeding` along with the other debuffs, and the potion heals; our sábila heals a little.
- **HUD follow-up:** `Bleeding.totalIncomingDMG()` feeds `Char.incomingDOT()`, which `ui/HealthBar.java` and `ui/StatusPane.java` draw as the health still to be lost. That needs the time left on clients.

**Brogue CE:**
- **Borrowed:** constant damage over a counted duration. In `Time.c` `playerTurnEnded`, poison decrements `status[STATUS_POISONED]` and deals `poisonAmount` each turn, then clears the amount when it reaches 0.
- **Noted, not needed:** Brogue's natural regeneration, also in `playerTurnEnded`, skips a poisoned player (its branch checks `!player.status[STATUS_POISONED]`). We have no health regeneration yet, so this waits for a "rest heals" change (REFERENCE_DST "Health, healing and sleep").
- **HUD follow-up:** `IO.c` `printMonsterInfo` draws each status as a `printProgressBar` of time left, and says "Fatal Poison" when status × amount ≥ current HP. The floor (D3) means bleeding is never fatal, so no "fatal" wording is ever needed.

**DCSS:**
- **Shape noted for `item-effects-runtime`:** `duration-data.h` `duration_def` gives every timed status one table row (light text, flags such as `D_NEGATIVE`, decrement rules, an expiring threshold). A `StatusData` resource per status is the same idea in our data-first style. It is rejected for now, because one timed status does not justify a new resource class. The bleeding numbers go in `SurvivalTuning` (D2), and `item-effects-runtime` can lift them out.
- **HUD follow-up:** `player.cc` `poison_survival()` and `poison_is_lethal()` predict the lowest health the poison will reach. `output.cc` draws that segment of the HP bar, and `poison_player` warns once ("lethally poisoned") when poison becomes fatal. With the floor, bleeding's worst case is "down to 1", never lethal.

**Don't Starve Together** (dontstarve.wiki.gg, read 2026-11-15, and `docs/REFERENCE_DST.md`):
- **Health page:**
  - **Borrowed:** damage over time that stops once its cause is dealt with. The page lists burning, starvation, freezing and overheating among the health drains.
  - **Kept:** our rule that only thirst, attacks and poison take health (REFERENCE_DST "One meter kills; the others shape it"). Bleeding counts as an attack's tail, and it is floored.
- **Healing Salve/DST, Honey Poultice/DST and Spider Gland pages:**
  - **Borrowed:** a medicine heals a flat small amount at once.
  - The Honey Poultice page says it can heal other creatures. The pages we read do not say a player can use it on a teammate, so that is **[unverified]**.
  - Our teammate use was already in the spec ("on the user or an adjacent teammate"); DST is not its source.
- **Poison page (Shipwrecked):**
  - **Borrowed:** the floor idea. A drain that wears off on its own, and the harsh venom-gland cure never leaves a character below a few health points. Ours: bleeding never takes the last point.
  - **Rejected:** the escalating rate, which is hard to read.
- **Overheating page:**
  - Heat in DST hurts only above a threshold, after a warning, and insulation slows it.
  - We already keep heat from costing health (GAME_DESIGN §4: "Heat never costs health"). So if sunburn is ever built, it shapes the heat meter, not health. This is why Q3's build option makes sunburn speed up heat instead of draining.

## Decisions

### D1. The time left lives on the host, beside the bit

`SurvivalMeters` keeps the seconds left of each timed status, on the host only.

- `set_status(BLEEDING, true)` starts or restarts the count from the tuning's duration, and `set_status(BLEEDING, false)` clears it.
- `tick` counts it down and ends the status at 0.
- A status whose tuning duration is 0 lasts until cured, as every status does today.
- Nothing new is synced: clients and late joiners read the bit as before, so `status-sync` is unchanged.
- The two callers that start bleeding stay untouched. A later wound source (`item-effects-runtime`'s `APPLY_STATUS`, with or without its own `duration_s`) calls the same method, given an optional duration.

**Alternatives:**
- Sync the time left as a second property. Rejected: no HUD reads it yet, and it can be added with the time-left bar.
- A per-status node or component. Rejected: one timer does not need a node.

### D2. The numbers live in `survival_tuning.tres`

A new `Statuses` group in `SurvivalTuning` holds:
- `bleeding_health_per_s = 0.1`;
- `bleeding_s = 120`;
- `bleeding_floor = 1`.

The script keeps no defaults, as the rest of the tuning does. The values match the recommended option of Q1.

### D3. Bleeding drains a little, steadily, and never takes the last point

- Each host tick takes `rate × delta` from health, but never below the floor.
- The drain does not go through `harm()`, which records a cause and reads as a hit. It sets health directly, the way the thirst drain does.
- It never changes `_last_harm`. If thirst then empties the last point, thirst is the cause.
- Because it is continuous, `damage-feedback`'s sorter calls it a drain and glows the Salud bar. That gives a cue with no HUD edit.
- Order in `tick`: the drain for the tick comes first, then the count. So 120 s of bleeding takes exactly 12.
- A downed player or one in a last stand is at 0, already at or below the floor, so the drain takes nothing.
- A revive leaves bleeding as it is.

### D4. Sábila's data

`aloe.tres` keeps both cures and gains a `METER_ADD` health +5 on the use target, after the cures. `UseOutcome` dry-runs a cure and an instant positive gain, so sábila is refused only when the subject neither bleeds nor is hurt.

A heat cooling (a negative amount) would count as "does something", and sábila would never be refused. That is why Q2 does not recommend it.

The descriptions change (ES first, Cuban speech, English keeps the slang). They are drafts for the owner's voice pass:
- ES: "La conoce cualquier cubano de más de cuarenta. Corta el sangrado y cierra la herida. Y si te quemaste, también."
- EN: "Any Cuban over forty knows it. Stops the bleeding and closes the wound. And if you got burnt, that too."

### D5. Who a cure goes to (`UsePlan.choose`)

The revive branches come first, unchanged. Then, when the item's first use has `can_target_others` and a `CURE_STATUS` effect on its use target:
1. If the player has one of the statuses it cures, the use goes on themself.
2. Otherwise it goes on the nearest teammate within `InteractionPicker.REACH_PX` (1 tile) who is standing, alive and in play, and has one of those statuses.
3. Otherwise it goes on the player themself, where `NOTHING_TO_DO` may refuse it.

Cups and coconuts have no cure, so they never reach step 2. The plan stays pure, and the HUD and the host reach it from the same state. The host still checks only the reach and `ItemUser.check`, so a client cannot aim beyond reach.

The selected item's line already names `plan.target` ("Sábila · [F] Untar: Papo"), so no HUD file changes.

**Alternative:** a separate "treat teammate" input. Rejected: the one use button already aims revives this way.

### D6. Sunburn stays dormant (Q3, recommended)

The aloe's SUNBURN cure stays as data. It does nothing until a source exists, and `UseOutcome` treats a cure of an absent status as changing nothing. `TASKS.md` gets a line for a heat change that gives sunburn a source, an effect on heat and its own HUD tag.

### D7. Specs that name health right after a wound are kept

Two scenarios read exact health at the moment of a shark's hit: `creatures-ai` "Solo bleeding swimmer" ("health is 75") and `crossing` "Shark prefers a weak swimmer". They stay true, because the drain starts after the wound. Only the GUT tests that read health a little later change: they use a tolerance (`assert_almost_eq`, 0.5) or subtract the drain since. Those tests are `test_patrol_circle_strike`, `test_crossing_shark` and `test_crossing_creature_shark`.

## Solo worst case

- **Bleeding alone never kills.** With exactly 1 player, offline, one wound costs at most 12 health over 120 s, and never the last point. So a lone player always outlasts it, with or without sábila.
- **What changes is the margin.** A swimmer at 30 health bitten by a shark is left at 5, as today. Bleeding then drains 4 more and stops at 1, and the next strike kills, as it already would.
- **The shark loop is unchanged.** A shark strikes a bleeder about every 10–14 s (retreat 4 s, circle 6–10 s) while they stay in deep water. The escape is the shallows (≤1 tile), as today.
- **It's now better than today on the sandbar.** There is no aloe there. Today a shark's wound bleeds forever: it keeps the player a shark target and blocks binoculars-and-swim for the whole run. Now it ends after 120 s.
- **In a crossing.** Uses are refused at sea. A 60–90 s crossing lets bleeding take at most 9 before landfall, and the coast cay's aloe is 7–13 s from the landing.
- **Run-1 death rule.** Death at 0 is unaffected, because bleeding never reaches 0.

## Owner decisions (asked 2026-11-15, pending)

The specs above follow the recommended option of each. Any other answer changes the named spec and tasks before building.

- **Q1. Bleeding.**
  - **(A, recommended)** 0.1 health/s, ends 120 s after the latest wound, never below 1.
  - (B) The same, but it can down and kill, naming the wound's creature as the cause, as SPD's `source` does.
  - (C) No drain, ends after 120 s.
  - (D) As today: no drain, ends only with sábila.
- **Q2. Sábila besides the cures.**
  - **(A, recommended)** +5 health at once.
  - (B) +10 health, like noni.
  - (C) Cures only.
  - (D) +5 health and heat −20. This needs `damage-feedback`'s dry run to learn about heat losses, otherwise sábila is never refused.
- **Q3. Sunburn.**
  - **(A, recommended)** Defer: the cure stays dormant, plus a `TASKS.md` line.
  - (B) Build now: reaching sunstroke in the sun gives sunburn; heat then rises ×1.5 in direct sun for 360 s or until sábila. It needs a HUD tag from the HUD owner.
  - (C) Drop the cure from sábila and its text. The enum value stays (append-only).
- **Q4. Who a cure goes to.**
  - **(A, recommended)** You first if you need it, else the nearest bleeding teammate within 1 tile, else you.
  - (B) A bleeding teammate first, even when you bleed too.
  - (C) Only yourself from the button, as today.

Refusing a wasted use is not a question here: `damage-feedback` (PR #65) decided and built it.

## Risks / Trade-offs

- **PR #65 not merged when building starts** → Build on main after it merges. If it hasn't merged yet, stack this branch on `claude/damage-feedback-1cc261` and retarget to main once it lands. This change touches none of #65's files except possibly `TASKS.md` and `docs/GAME_DESIGN.md`, where both edit different rows.
- **Tests that read exact health while a player bleeds** → The three shark tests (D7) and `test_death_cause`'s strike test, where the strike kills at once, so no drain is involved. Run the whole GUT suite, not only the new tests.
- **A player held at 1 health looks stuck** → It is the floor by design. The Salud bar's drain glow (from #65) stops when the drain stops, and the "Sangrando" tag hides at 120 s.
- **The host's timer is lost if the host leaves** → Only the host simulates, so a run without its host has ended. A rejoining client gets the bit through the synchronizer as before.
- **A forged use aimed at a far teammate** → Refused by `UsePlan.actor_reason` (`OUT_OF_REACH`) on the host. That is covered by a scenario.
