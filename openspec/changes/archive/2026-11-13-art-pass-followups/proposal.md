# Proposal: art-pass follow-ups

## Why

The scripted playthrough of `art-pass` (2026-11-13) left three of its tasks unticked and found two small faults. At a nest palm a player cannot shoo the perched gull: the palm's `[E] Trepar` and the gull's shoo sit on the same point, the palm wins the tie, and the gull swoops before the 2 s climb ends. The coast cay's signs show `[E]` with no verb. A night foam check fails on one shore cell although the foam is drawn there. And on a client the structures and the route on to the coast cay were never played, only looked at.

## What Changes

- An interactable may carry an interact priority. Within reach, the highest priority wins, then the nearest. A creature that can be shooed has a higher priority than things, so a perched gull's shoo beats the palm's climb, on the prompt and on the press. Solo the same.
- An island sign shows a verb in its prompt: `[E] Mirar` ("Look"), because the signs are a dead radio, wall slogans and crossed sticks, not only writing.
- The playthrough harness (`game/tests/manual/art_pass_run.gd`, a test tool) gets:
  - a foam check that allows for the night tint, which warms the foam (blue below red);
  - a gull check that needs the shoo shown: E at the palm, the gull flees, the climb gives a coconut;
  - a client run that plays the structures (climb, lean-to, fire built and put out, rain catcher in a squall, raft stages and launch) and travels with the host to the coast cay and reads a sign there, while the host sets the host-owned state (squall, materials, crossing plan) when it sees the client reach each step.
- `art-pass` tasks 6.5, 8.5 and 10.3 are ticked from those runs, or stay unticked with the finding written down. A client looking stale for palms, fires and catchers is expected (art-pass design D18) and is noted, not fixed.

Out of scope: structure-state sync to late joiners, the ENet throttle on `submit_intent`, lifting the shoo prompt by the creature look's lift (art-pass K9), and the sign bubble's readability at 1× over sand. They stay listed as follow-ups.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `player-movement`: "Interaction" chooses by priority, then distance; a creature that can be shooed outranks things.
- `inventory-hud`: "Interact prompt" follows the same choice.
- `island-generation`: "Flavour signs" names the prompt's verb.

## Impact

- `game/scripts/interaction/interactable.gd` (a priority field), `interaction_picker.gd` (the choice), `game/scenes/creatures/creature.tscn` (the gull's interactable), `game/scenes/levels/island_sign.gd` (its prompt id), `game/resources/hud_text.tres` (the verb), and their unit tests.
- `game/tests/manual/art_pass_run.gd` (host and client modes, foam and gull checks).
- `openspec/changes/art-pass/tasks.md` (ticks and notes) and `TASKS.md`.
- Networking: none. The client already computes its own prompt and the host its own press with the same picker; both read the same priority from the scenes.
