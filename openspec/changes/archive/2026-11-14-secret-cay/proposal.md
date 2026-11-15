# Proposal

## Why

The owner wants a rare, funny secret that rewards players who search off the beaten path: a map and a broken compass hidden on two mid-run islands that, together, lead to a tiny hidden cay whose chest holds nothing but a joke note, next to a yarey hat with a red band that someone left behind. It costs a detour and pays out in laughs, never in power. The owner settled the design on 2026-11-06 (frequency, the hat, the cay's place in the run); the build waited for `escape-routes`, which edits the same island files and was merged (PR #13) and archived (PR #14) on 2026-11-08.

## What Changes

- Four new items, all marked **secret**: *Brújula rota* (`brujula_rota`, the broken compass: "la única brújula que nunca te manda pa'l Norte"), *Mapa sin norte* (`mapa_sin_norte`), *Sombrero de yarey con cinta roja* (`sombrero_cinta_roja`) and the note *Llegaste tarde* (`nota_llegaste_tarde`, 5 handwritten entries, Spanish first).
- A new handmade island, *El cayo sin norte* (`cayo_sin_norte.tres`), marked secret and off-graph: it never counts as one of the run's 6–8 islands, grants no Experiencia point, takes no per-island bonus, and is never enumerated by island generation. It reads as "he left minutes ago" (warm embers, a smoking cigar stub, a fresh raft-drag mark, a cut mooring line, the hat hanging on the lean-to), and one player with nothing in hand can survive there and leave by raft.
- One tuning file, `game/resources/secret_tuning.tres`, for every number of the feature and for which items are the two pieces: the map's and the compass's item ids, 1 run in 3 (`run_chance` 0.33), pieces on run indices 2–5, a 0.75 s shimmer every 6 s, the 1.5 s pick-up hold, the needle's distance bands (40, 20, 11 and 6 tiles), the 1 s chest hold, the note's display time, the hiding-spot bounds, fallback band and feature kinds, and the map's hint phrases. The reveal radius (3 tiles) is the items' own concealment field.
- Concealment: a concealed item draws nothing distinct until any player is within its reveal radius, apart from a short shimmer that can be seen from across the screen. Each peer works it out from positions it already receives. Pick-ups stay with the host.
- The broken compass's needle on the HUD (top-centre under the day phase, 24×24 px), shown only to the player who carries it. It points at the nearest concealed item on the island or at the cay's unopened chest, and steadies in distance bands. It never steers and never counts as a compass.
- An empty chest built on every peer. The host opens it once, picks the note entry once and tells every peer, including players who join later. Until the reading panel exists, the note shows on a HUD label for 6 s + 50 ms per character.
- The rule for hiding spots (a land cell, never shallows or deep water, between the 50th and 85th percentile of land walking distance from the layout's solo spawn, 4–10 tiles from the nearest palm, non-secret pick-up, tide pool, workbench or raft site, with a fixed fallback order so a crowded island still gets its piece) and the map's hint, which fills the map's text with the kind of spot where this run's compass hides.
- A player who is removed from the run while holding secret items drops them where they were last seen, unless they had already left the island by a route.
- The cay and a dev hunt layout reuse the island scene through coast-cay's "Any handmade layout builds the island" rule (the owner decided on 2026-11-08 that coast-cay owns it, since it builds the code first).
- Two playable dev scenes, the hunt and the cay (solo offline and host plus client), with 1-player tests for each.
- **Not in this change** (later, see design.md): placing the pieces in real runs, the crossing to the cay and back, the *Seguir la aguja* departure choice, wearing the hat, the cross-run cosmetic unlock, and reading panels.

## Capabilities

### New Capabilities
- `secret-cay`: the secret map, broken compass, concealment and hiding spots, the needle, the hidden cay with its empty chest, note and hat, its tuning data, the secrecy rules and the dev scenes.

### Modified Capabilities
- `endings-progression`: the cay does not count in Run structure, Experiencia levels (no per-island bonus), Experiencia points, Experiencia carry-over (no map knowledge or routes from secret things) or Run summary; the patrols-everywhere challenge places no patrols on it.
- `island-generation`: off-graph handmade layouts are never generated, enumerated or counted, expose only the routes their layout lists (the cay: the raft) and place exactly their listed pick-ups, which never respawn. The rule that any handmade layout builds the island scene now comes from coast-cay.
- `crafting-inventory`: the item resource gains the `secret` tag (spawn weight 0, never picked by item-tag spawns or found-text placement) and a concealment radius; picking up a concealed item takes the tuning's hold.
- `crossing`: the broken compass and the map never count as the compass or the charts that cancel drift.
- `npcs-dialogue`: AI context never carries secret items or the cay.
- `coop-networking`: party-size scaling never changes the cay's fixed contents.
- `guardacostas-stealth`: the cay is never the "previous island" a captured party restarts, and a regenerated island never places a piece the run already spawned.

## Impact

- Data: `data_enums.gd` (appended `ItemTag.SECRET`, `Capability.POINT_TO_SECRET`), `item_data.gd` (`conceal_radius_tiles`), `island_layout_data.gd` (`off_graph`, `secret`, `chest_glyph`, `chest_item_id`, `decor_glyphs`, `decor_colors`), 4 items, 1 island, `secret_tuning.tres` with `SecretTuning` in `game/scripts/components/` (the data-model class and folder counts do not change).
- Code: `island_layout.gd` (walking distances, hiding spots, chest cell, decor), `sandbar_island.gd` (built from its layout when the layout is set, the chest, no workbench when the layout has none), `world_item.gd` (concealment, shimmer, hold), new `chest`, `compass_needle` and note label scenes, `run_hud.gd`, `coop_session.gd` hooks for leavers and late joiners, new `secret_rules.gd`, `secret_plan.gd` and `secret_hunt.gd` in `game/scripts/secret/`, `island_layouts.gd` (the numbered-island listing) in `game/scripts/levels/`, a content-validator rule for secret items' spawn weight, two dev scenes.
- Sequencing: build only after `escape-routes` is merged and archived (it edits `island_layout_data.gd`, `island_layout.gd`, `sandbar_island.gd`, `sandbar.tres`, `coop_session.gd`, `game_shell.gd`). `ui-shell` is not a gate: its `run_hud` code is on `main`, and task 0.2 re-reads it. `balsero-lore` appends to a different enum; re-run the data-class and content checks after rebasing. The runner's `sandbar-size` change (the 3x sandbar, a C round a lagoon) rewrites `sandbar.tres` rows and four sandbar requirements of `island-generation`; it modifies none of the requirements this change modifies, but rebase on it and re-run the sandbar tests if it lands first.
- Docs: `docs/GAME_DESIGN.md` (one-line cay exceptions in §2, §8, §9, §10, §14 and §16), `docs/ITEMS.md`, `docs/ISLANDS.md`, `docs/CONTENT_MANIFEST.md`, `TASKS.md`.
- IP and tone: the hat is only "sombrero de yarey con cinta roja"; no name, emblem or line from any franchise appears anywhere; the wink lives only in one note. Nothing about the cay jokes about the dead or the missing (`docs/LORE.md`). Secret items and the cay never reach the AI backend.
