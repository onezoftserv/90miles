# Proposal

## Why

Sábila (`aloe.tres`) barely does anything. It cures SUNBURN, which nothing ever gives, and BLEEDING, which never takes health and never ends, so its only job is to stop sharks picking the bleeder first. It is spent even when there is nothing to cure. A bleeding teammate can't be treated, though `crafting-inventory` "Coast cay items as data" says it works "on the user or an adjacent teammate". The owner chose on 2026-11-14 ("Both (Recommended)") that the refusal and HUD cues go to `damage-feedback`, and that sábila gets its own fix here. This change also answers data-model-questions 22 for bleeding: what it does per second.

## What Changes

- **Bleeding takes health and ends on its own** (provisional, owner to confirm):
  - it drains 0.1 health/s, the same pace as resting thirst (6/min);
  - it ends 120 s (4 in-game hours) after the latest wound, and a new wound restarts the count;
  - it never takes a player's last point of health, so bleeding alone never downs or kills, and no new cause of death is needed;
  - the timer lives on the host beside the synced status bit; nothing new is synced;
  - the two places that start bleeding today (a shark's strike on an island and a shark's bite in a crossing) stay as they are, and a later wound source (the crocodile's death roll, urchins, oysters) gets the same rule for free.
- **Sábila heals a little**: 5 health at once, besides stopping bleeding (`docs/GAME_DESIGN.md` §4 already lists aloe under health's "Restored by").
- **Sunburn is deferred**, not built. The aloe keeps its dormant SUNBURN cure as data, and `TASKS.md` gets a line for a later heat change with its own HUD tag. The `SUNBURN` enum value stays (append-only).
- **The use button aims a cure at a teammate who needs it:**
  - you get the use if you have a status it cures;
  - otherwise the nearest teammate within 1 tile who has one gets it;
  - otherwise you do (the heal, or the refusal from `damage-feedback`);
  - revives keep their priority;
  - cups and coconuts, which cure nothing, are never aimed at a standing teammate;
  - the selected item's line already names the teammate.
- **Refusing a wasted use** comes from `damage-feedback` (PR #65, "A use that changes nothing is refused"). This change builds on it and adds no refusal rule or line of its own. With the heal, sábila is refused only at full health with no bleeding.
- **Not here:**
  - `APPLY_STATUS` and the other statuses (poison, burning, hallucinating), which stay with `item-effects-runtime`;
  - any HUD file;
  - a status time-left bar, which is a HUD follow-up.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: an ADDED requirement for what bleeding does each second and when it ends.
- `crafting-inventory`: "Coast cay items as data" is modified so aloe cures bleeding and heals 5 (sunburn dormant). A new requirement covers sábila on a teammate and at full health.
- `inventory-hud`: "Which use the button picks" is modified so a curing use goes to a teammate who needs it.

## Impact

- **Code:**
  - `survival_meters.gd`: a host-only status timer and the bleeding drain in `tick`;
  - `survival_tuning.gd` and `survival_tuning.tres`: the numbers;
  - `use_plan.gd`: the cure-aiming rule.
- **Data:** `aloe.tres` gains a `METER_ADD` health +5 on the use target, and its descriptions change.
- **Tests:**
  - new 1-player tests and host-plus-client tests;
  - shark tests that read exact health after a strike get a tolerance for the drain since (`test_patrol_circle_strike`, `test_crossing_shark`, `test_crossing_creature_shark`);
  - `test_coast_cay_solo` keeps its aloe test.
- **Docs:**
  - `docs/ITEMS.md` (the sábila row);
  - `docs/GAME_DESIGN.md` §4 (bleeding under health's "Drains from");
  - `docs/BESTIARY.md` (the reef shark's "bleeding" defined once);
  - `TASKS.md` (the sunburn follow-up, and Q22 answered for bleeding on the `item-effects-runtime` line).
- **Depends on:** PR #65 (`damage-feedback`). Its `UseOutcome` dry run refuses a cure or an instant gain that changes nothing, and its drain glow shows bleeding's steady loss. This change is built on top of it.
