# Design: art-pass follow-ups

## Context

See proposal.md for why. What the code does today:

- `InteractionPicker.pick` (`game/scripts/interaction/interaction_picker.gd`) takes the nearest enabled interactable within 16 px that the player may use, keeping the first on a tie. The HUD prompt (`interact_prompt.gd` `_pick`) and the player's press (`player.gd` `_update_interaction`) both call it, each on its own peer, over the `interactables` group.
- A nest palm is placed at `IslandLayout.cell_center(palm cell)` (`sandbar_island.gd:64`) and its gulls spawn and nest at the same point (`creature_spawner.gd:131-142`). The palm's interactable and a perched gull's interactable are at exactly the same distance from any player, so the tie goes to whichever entered the group first: the palm.
- The gull's interactable is instant (`creature.gd` `_ready`: `hold_time_s = 0`) and enabled only for a creature with an INTERACT counter. Of the shipped creatures only `seagull.tres` has one; the crab and the shark do not.
- `IslandSign` (`game/scenes/levels/island_sign.gd`) never sets `prompt_id`, so `InteractPrompt.head_parts` shows the key alone. "Leer" in `hud_text.tres` is an item use verb (`use_verbs[4]`), not a prompt verb.
- The night foam check in `art_pass_run.gd` `_foam` calls a pixel foam when blue ≥ red and it is brighter than the land's mean. A capture of shore cell (47, 19) at night (`.sdk-runner/runs/art-pass-final/scratch/solo5/shore_night_0.png`, enlarged and read pixel by pixel) shows the foam drawn there as (205, 165, 155) over sand (192, 126, 94) and sea (77, 133, 139): the night tint is warm, so the foam's blue falls below its red and the check misses it. The art is right; the check is wrong.

## Goals / Non-Goals

**Goals:**
- A perched gull can be shooed at its palm, in the prompt and on the press, solo and on a client, and the palm can be climbed once the gull is gone.
- Signs show a verb.
- The playthrough's checks measure what tasks 4.6, 6.5, 8.5 and 10.3 ask, on a client too.

**Non-Goals:**
- Syncing palm, fire, catcher or raft state to clients or late joiners (art-pass D18 risk note, K89).
- Moving the shoo prompt up by the creature look's lift (art-pass K9).
- Any art change.

## Decisions

### D1. An interact priority on the interactable, read by the picker
`Interactable` gets `@export var priority: int = 0`. `InteractionPicker.pick` keeps, among candidates in reach, the highest priority, then the nearest; the existing tie rule (first wins) stays for equal priority and distance. `creature.tscn`'s Interactable sets `priority = 1`. The value is data in the scene, so a later creature or thing can opt in without a script edit.

Alternatives:
- Moving the gull's interactable (or the palm's) a few pixels so distance decides. Rejected: it depends on where the player stands. From the far side of the trunk the palm would win again.
- A rule in the picker that says "creatures first" by type. Rejected: the picker would need to know creature classes, and a thing that should outrank others (a burning fire, later) could not opt in.
- Disabling the palm while a gull is perched on it. Rejected: it couples two unrelated scripts, and the palm's climb would vanish from the prompt with no reason shown.

Consequence, solo and in co-op: a gull within 1 tile beats a nearer pick-up. A gull within 1 tile is either perched on a palm (shoo it first) or swooping on the player's food (shooing it is what the player wants), so this is the wanted order.

### D2. Reference games
- Shattered Pixel Dungeon, `Hero.handle(int cell)` (`actors/hero/Hero.java`): when the tapped cell holds a character (`Actor.findChar`) it interacts with or attacks it before looking at the heap or the terrain on that cell. **Borrowed**: a creature sharing a spot with a thing wins the one action.
- Brogue CE, `playerMoves` (`src/brogue/Movement.c`): moving into a cell attacks or frees the monster there; the cell's step promotions (`promoteTile`) run only when no visible enemy stands there. **Borrowed**, same idea: the creature first, the place second.
- DCSS: separate commands for pick-up (`CMD_PICKUP`, listed in `command.cc`), attacking by moving, and examining, so no one-button tie exists to resolve. **Rejected** as a model: 90 Millas has one interact button by spec (player-movement "Interaction").

### D3. Signs say "Mirar"
New prompt id `&"look_sign"` with verb ("Mirar", "Look") in `hud_text.tres` `prompt_verbs`, set by `IslandSign._ready`. No label: the bubble says what it is. "Leer" was considered but the coast cay's signs include a dead radio and two crossed sticks, which are looked at, not read. Menus and prompts stay standard Spanish.

### D4. A foam check that allows for the tint
In `_foam`, a pixel is foam when it is brighter than the land's mean and its blue-to-red ratio is clearly above the land's mean blue-to-red ratio (land and foam pass through the same tint, so the ratio between them survives it). A neighbour counts as land by the same ratio, now relative to the land mean, not a fixed "blue < red + 12". The day results must stay the same; if the corrected check finds a truly bare cell, it is reported, not tuned away. As built (2026-11-13): foam is brighter than the land mean and at least 1.5 times as blue (blue over red) as the land mean; a pixel more than 2.5 times as blue is water; a land neighbour is any pixel that is neither. Two tighter first versions failed cell (50, 11) by day and night alike, because pale foam (143, 224, 240) is nearly as blue as the sea and a dark rim pixel was counted as land; brightness tells pale foam from the sea, and no threshold was loosened to pass a cell.

### D5. The client plays, the host sets what only the host may set
Host-owned state (the squall, materials in the client's inventory, the raft's build, the crossing plan) cannot be set from the client process. The host harness watches the client's state (its body's position, inventory and the structures in the session) and sets each step's state when it sees the client reach it, as it already does when waiting for the client to leave. The client harness plays every step by input: climb a nest palm (after shooing its gull), stand in the lean-to, build and put out a fire, see the rain catcher fill in the squall, build the raft through its stages, board, cross with the host and read a coast cay sign. One client rides the crossing through; the other leaves and rejoins mid-crossing (the existing rejoin checks stay). Checks assert the host's truth; looks that follow a client's own stale state (palm coconuts, fire, catcher) are noted, not failed (art-pass D18).

## Risks / Trade-offs

- [The host and client harnesses drift out of step and time out] → each wait has a deadline, prints what it waited for, and the run stops with a FAIL rather than hanging.
- [A late-joiner sync gap (the raft) shows up again] → recorded as a finding in art-pass tasks.md and 10.3 stays unticked for that clause; structure sync stays out of this change.
- [A priority makes a creature passing by steal a pick-up press] → only creatures that can be shooed get it, and only within 1 tile.
