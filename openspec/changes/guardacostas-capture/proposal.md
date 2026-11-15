# Proposal

## Why

`guardacostas-stealth` (PR #50, merged; its build is running) teaches the patrol to see. It also ends every alert with the boat giving up, so being spotted costs nothing yet. This change is the response, the second slice the stealth proposal named: chase, the shore squad, capture, freeing a captive, Rodríguez's `la_captura`, and the restart on the previous island. `TASKS.md` §6 lists it as "Shore squad, capture, free-a-captive, `la_captura` scene". It takes the six main-spec requirements the stealth change left: Chase and shore squad, Free a captive, Capture outcome, Previous island after capture, Capture on the final crossing, and Fade with distance.

## What Changes

- **The boat chases swimmers.** When a boat spots a swimmer, it leaves its lap and chases at 2× swim speed (6 tiles/s), through deep water only. After a 2 s touch within 1 tile, it hauls the swimmer aboard. Shallows, land, a dive or a 10-tile gap break the chase. A swimmer who reaches land brings the squad (owner decision 4).
- **The shore squad.** An alert whose cause is on land lands three soldiers (owner decision 3): a sight spot, smoke or noise. The causes are listed in `guardacostas-stealth` "Triggers".
  - The boat stops where it is, and a dinghy rows the squad to the nearest beach.
  - The squad searches for 180 s. Its points are every lit fire first, then the last known position, then a random walk over the island.
  - One squad is ashore at a time. The boat waits, and at night its light keeps sweeping.
  - The squad leaves when the search ends, but never sooner than 60 s after the latest capture. It leaves at once when no free player is left on the island, or when a squall comes (owner decision 7).
- **Soldiers.** Soldiers do not fight. They see in a cone ahead of them (owner decision 5):
  - by day, 6 tiles and 120°;
  - at night, a 5-tile, 60° flashlight.

  Their sight fills the same spot meter as the searchlight. A hidden player is never seen. A soldier who searches a point for 3 s finds any hidden player within 2 tiles of it.

  Soldiers walk at 3 tiles/s and chase at 5 (players walk at 4 and run at 6). A 2 s touch within 1 tile captures a player, and the count resets when contact breaks.
- **Captives.** A captive cannot move or act.
  - The soldier walks them to the dinghy on the landing beach, where they sit.
  - A free player who holds interact for 1 s on a captive, with no soldier within 3 tiles, frees them. This works on the walk or in the dinghy (owner decision 6).
  - When the squad leaves while some player is still free, it takes its captives along. Each one is out of play until the party next lands, and arrives with no items except keepsakes (owner decision 8).
- **Whole-party capture.** When no free player is left in the run and at least one player is a captive, `la_captura` plays at once.
  - Only standing, connected players count as free. Downed and dropped bodies on the island go with the party (owner decision 9).
  - A solo player's first capture is always a whole-party capture, so nobody ever has to free a solo player.
- **`la_captura`.** It is Rodríguez's handwritten scene, shown in a scene panel on every peer and paced by the host (owner decision 11).
  - He reads the interception act in formal Spanish and speaks Baracoa Spanish in person.
  - The lines address one player in the singular and a party in the plural.
  - A second capture in the run opens with "¿otra vez?".
  - A party that used the almendrón gets the car variant and the `almendron_hundido` flag (balsero-lore "Almendrón capture").
- **The persuasion check** is decided on the host (owner decision 2). It passes when one captured, standing player is a Maestro or Médico with morale 60 or more, and that player pleads for everyone. Players have no background until the backgrounds change ships, so until then every capture sends the party back.
- **Release** (the check passes). The party lands on the next island its current island names, keeping everything. The coast cay names no next island today, so a release there ends the run, as leaving it does (owner decision 10).
- **Restart** (the check fails).
  - The previous island is rebuilt from the run seed and the party lands on its beach. Island 1 restarts island 1, and the secret cay is skipped.
  - Each player keeps their items except fire sources (items that light fire). Keepsakes are always kept.
  - Meters and the clock carry on.
  - The host keeps the run's island history. Reaching an island again never counts it twice.
- **Fade with distance, as data.**
  - A mid-chain island (mangrove, reef, rocky key, lighthouse) gets its patrol 30% of the time, rolled from the run seed and the island. When it does, the count is the coast rule's.
  - Far chains get none.
  - The final crossing's one patrol, and capture there (`devuelto`), wait for the final crossing and the endings. A router branch in this change sends a final-crossing capture to `devuelto` instead of `la_captura` (owner decision 1).
- **Every peer sees it.** The host decides every touch, every rescue, the check and the outcome. Soldiers are creatures and sync like creatures. The dinghy, the captive state and the scene's line sync to every peer, a late joiner included.
- **Cues.**
  - a rope mark over each captive;
  - an "[E] Soltar" prompt with a 1 s ring;
  - the stealth change's open eye, which fills under a soldier's sight too;
  - squad lines in speech bubbles: landing, a spot, giving up.

## Solo

Solo is first class. One offline player is the host and runs everything on their own machine.

A solo player's first capture is a whole-party capture, so `la_captura` plays at once and nobody has to free them. This is the main spec's "Solo player is never held on the dock".

A solo player has a way through every rule:
- outswim the boat to the shallows, or dive under it;
- run (6 tiles/s beats a soldier's 5);
- move off the spot where they were last seen (where they hid, or where they left sight) and away from their fire before settling, because soldiers search those points. Crouch-walking through a scrub patch, or out of the light's 10 tiles, does it;
- hide in the scrub, the mangrove or the hut until the squad's 180 s run out.

A failed check sends a solo player to the previous island with their kit minus the lighter, which is a setback and not a death. The tests run one offline player through a landing, an escape, a capture, both outcomes, and the restart on islands 1 and 2. Each co-op rule also has a host-plus-client test.

## Owner decisions (recommended option first)

Not yet answered. Every artifact follows the recommended option (a). The coordinating session relays the questions as option dialogs, and any other answer is folded into every artifact before building (tasks.md 0.1). The numbers are provisional data.

1. **The slice: what waits.**
   a. *Recommended: islands now, the final crossing later.* Build the chase, the squad, capture, freeing, `la_captura`, the persuasion check, the release and the restart. Fade with distance becomes data: 30% on mid chains and none on far chains, tested on fixture islands, because no mid-chain island exists yet. Capture on the final crossing (`devuelto`) waits for the final crossing and the endings, behind one tested router branch.
   b. *No scene yet.* As (a), but a whole-party capture always restarts the previous island after one loudhailer line. `la_captura` and the persuasion check wait for Milestone E's dialogue UI and backgrounds.
   c. *Fade waits too.* As (a), but mid-chain and far-chain patrols wait until those chains exist.
2. **The persuasion check, when no player has a background.**
   a. *Recommended: one speaker, behind a seam.* The check passes when one captured, standing player is a Maestro or Médico with morale 60 or more, and that player pleads for everyone. Players have no background until the backgrounds change, so until then every capture sends the party back. The tests set a fixture background. Two stub background files (`maestro`, `medico`) let the scene's data name them.
   b. *Morale only, for now.* As (a), but until backgrounds exist, morale 60 alone passes. The backgrounds change adds the Maestro-or-Médico part.
   c. *Party average.* The captured players' average morale is 60 or more, with a Maestro or Médico among them. The seam is as in (a).
3. **What lands a squad.**
   a. *Recommended: any alert on land.* A sight spot of a player on land, a smoke alert or a noise alert lands the squad when none is ashore. A spotted swimmer starts a chase instead. This follows GAME_DESIGN §9 ("Smoke or fire draws a shore squad") and the search order, which starts at the fire. By day, a fire within 6 tiles of the sea is always seen, so a day fire while a boat is in sight brings soldiers.
   b. *Sight spots only.* Smoke and noise keep the stealth slice's plain 20 s alert.
   c. *Night only.* By day, every alert stays the plain 20 s alert.
4. **The chase at sea.**
   a. *Recommended: deep water only.* The boat chases at 6 tiles/s (2× swim) through deep water. It hauls a swimmer aboard after 2 s within 1 tile. Shallows, land, a dive or a 10-tile gap break the chase, and a swimmer who reaches land brings the squad. A swimmer spotted 6 tiles out has about 4 s to reach the shallows or dive.
   b. *Instant haul.* As (a), but reaching 1 tile hauls the swimmer aboard at once.
   c. *Into the shallows.* As (a), but the boat also enters shallow water, so only land or a dive breaks the chase.
5. **Soldiers' senses and speed.** The figures come from a simulation of 150 s of search by three soldiers on each island (design.md "The search, simulated").
   a. *Recommended: sight cones and point searches.*
      - Sight: by day 6 tiles and 120°; at night a 5-tile, 60° flashlight. It fills the same spot meter as the searchlight.
      - Hidden players are never seen. A soldier who searches a point (a fire or a last-known position) for 3 s finds any hidden player within 2 tiles of it.
      - The last known position is where a player was last seen: where they hid, or where they left sight. So hiding on the spot fails, and moving off it first works.
      - Speed: walk 3, chase 5 tiles/s (players walk 4 and run 6).
      - Measured:
        - From any last-known position, cover more than 2 tiles away is a median of 3 steps (90th percentile 6–7).
        - Crouching away while still hidden works from 62 of the sandbar's 96 hiding cells, but only from the coast cay's observation post (15 of 44 cells), because the coast cay's scrub is single cells.
        - A still player in the open is caught in 66% of simulated runs on the sandbar and 54% on the coast cay.
   b. *Plus stumbling.* As (a), and any soldier who passes within 1 tile of a hidden player finds them. Simulated: 72% of the sandbar's 96 hiding cells and 73% of the coast cay's 44 are found within 150 s, so hiding rarely saves you.
   c. *The Bush Hat rule.* As (a), but hiding never shakes a soldier who is already chasing you. Only getting out of its sight range does.
6. **Where captives are held.**
   a. *Recommended: the beached dinghy.* Captives are walked to the squad's dinghy on the landing beach. A free player who holds interact for 1 s on a captive, with no soldier within 3 tiles, frees them. This works on the walk (once the escorting soldier has been drawn away) or in the dinghy. A swimmer hauled aboard the boat cannot be freed.
   b. *Aboard the boat.* Captives are rowed to the boat offshore. A teammate frees them by swimming out and climbing aboard (3 s). The boat's water trigger is off while the squad is ashore.
   c. *No holding.* Captives are rowed out as soon as they reach the beach, so they can only be freed on the walk.
7. **When the squad leaves.**
   a. *Recommended: 180 s, with a grace.* The squad leaves when its 180 s search ends, but never sooner than 60 s after the latest capture. It leaves at once when no free player is left on the island, and a squall recalls it.
   b. *180 s flat.* The squad leaves when the search ends, or when no free player is left.
   c. *A 3-minute hold per captive* (BESTIARY). Each captive is held 180 s from their capture, and the squad stays until the last hold ends.
8. **A captive taken while another player is free.** A session runs one live island ("Split parties"), so the main spec's "respawns on the previous island" cannot happen while the party plays on.
   a. *Recommended: out of play, then lands with the party.* The captive waits out of play like a rider on the next shore: hidden, unhurt, with meters frozen. They lose every item except keepsakes, and their secret items stay on the landing beach. They land with the party on the next island the party reaches, and they join a later whole-party capture.
   b. *Back on this beach.* Once the boat has gone, the captive is put back on this island's landing beach with no items except keepsakes.
   c. *Lost for the run.* The captive counts as dead.
9. **Downed and dropped players at a capture.**
   a. *Recommended: not free, taken along.* Only standing, connected players count as free. Soldiers ignore downed and dropped bodies. At a whole-party capture those bodies go with the party: a downed player stands at 30 health after the scene, and a dropped player keeps its hold.
   b. *A downed player counts as free.* There is no whole-party capture while a teammate is downed. The captives wait until that player is revived or dies.
   c. *Captured like anyone.* Soldiers capture downed bodies with the 2 s touch. Those players stay downed, and their timers keep running.
10. **After the scene.**
    a. *Recommended: carry on.*
       - Meters and the day clock carry on.
       - A release keeps every item.
       - A release from an island that names no next island (the coast cay today) ends the run, as leaving it does.
       - Reaching an island again never counts it twice.
    b. *Restart at dawn.* As (a), but a restart lands the party at the next dawn ("at first light").
    c. *A release also takes fire.* As (a), but a release also takes fire sources.
11. **How the scene is shown.**
    a. *Recommended: a minimal scene panel.* Every peer shows a panel with the speaker's name and text revealed at 40 chars/s, paced by the host, with no portraits or choices. It is the first piece of the npcs-dialogue Dialogue UI.
    b. *Speech bubbles.* Rodríguez stands on the beach, and his lines show as speech bubbles, like the loudhailer's.
    c. *The full dialogue UI.* Build npcs-dialogue's Dialogue UI now: portraits, choices and voice clips.

## Provisional numbers

All of these are data: the boat's `PatrolData` and `shore_soldier.tres`.
- **Chase:** 2× swim speed (6 tiles/s), deep water only; a 2 s haul within 1 tile; the chase breaks at 10 tiles.
- **Squad:**
  - 3 soldiers, landed by a dinghy at 2 tiles/s;
  - a 180 s search, with each point searched for 3 s within 2 tiles;
  - a 60 s grace after the latest capture.
- **Soldier:**
  - walk 3 and chase 5 tiles/s;
  - sight by day 6 tiles and 120°, at night 5 tiles and 60°;
  - a 2 s touch within 1 tile to capture.
- **Freeing:** hold 1 s, with no soldier within 3 tiles.
- **Persuasion:** morale 60, Maestro or Médico.
- **Fade with distance:** a 30% chance on mid chains, 0 on far chains.

All lines are drafts for the owner's voice pass: Rodríguez's scene (design.md §10) and the squad's shouts (§11).

## Not in this change

- **The final crossing's patrol and `devuelto`:** with the final crossing and the endings (`TASKS.md` §6, §7). The router branch is built here.
- **The cutter on the first crossing:** with the cutter boss. Its "Caught = *La captura*" will call this change's whole-party capture.
- **More persuasion paths:**
  - Marisol's first-capture release, with the companions;
  - *El trato del capitán* (Caridad's letter), with Rodríguez's quests;
  - Rodríguez's trust carry-over.

  Each is a higher-priority state in the scene's data.
- **The backgrounds** themselves and a way to pick one (`TASKS.md` §7).
- **Patrol set pieces:** the patrol dinghy as an escape route, the logbook, and "the patrol that stops".
- **`balsero-lore` 9b.1**, the `almendron_hundido` gate on chain route rows: with the chain rows. This change sets the flag.
- **Two hand-offs from the stealth slice:** `EffectData` `ALERT_PATROL` and `RouteData.patrol_alert_chance` (the almendrón's 50% "somebody reports you" alert at its start, and the wall's 40%). Both come with the set pieces and routes that use them, and both will call this change's land-alert entry. The noise those starts make already reaches the boats through the stealth bus.
- **Chain-specific patrols:** the mangrove's spit, the lighthouse's dawn pass and Caridad's house.
- **A struggle to escape a soldier's touch.** Running breaks contact.
- **The soldiers' and the dinghy's sprites:** placeholders until the art pass.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `guardacostas-stealth`:
  - MODIFIED: Chase and shore squad, Free a captive, Capture outcome and Fade with distance from the main spec, and Alert from the `guardacostas-stealth` change, which must be archived first.
  - ADDED: Boat chase at sea, Soldier sight, Squad search, Last known position, The squad leaves, Captives, Whole-party capture, Taken captives, The capture scene, Persuasion check, Release at the next island, Island history, Capture on every peer, Capture cues and Shore squad data.
  - Unchanged and built as written: "Previous island after capture". "Capture on the final crossing" is also unchanged: this change only routes to it.

## Impact

- **Data classes:**
  - `PatrolData` gains the chase, squad, soldier and freeing fields listed above, plus the squad's lines in Spanish and English.
  - `CreatureData.Behavior.SEARCH_CAPTURE` gets its brain.
  - `EffectData` kinds `TAKE_ITEMS_WITH_CAPABILITY`, `TRAVEL_NEXT_ISLAND` and `TRAVEL_PREVIOUS_ISLAND` are interpreted.
  - `ConditionData` `BACKGROUND_PRESENT` and the `ANY_PLAYER` scope get built.
  - No new data class.
- **Content:**
  - `game/resources/creatures/shore_soldier.tres`;
  - `game/resources/npcs/rodriguez.tres`;
  - `game/resources/dialogue/beat_la_captura.tres`;
  - stub `game/resources/backgrounds/maestro.tres` and `medico.tres`;
  - the patrol boat's mid-chain rule.

  Fixtures:
  - a chain of three tiny islands;
  - a mid-family island;
  - a fixture background;
  - a test soldier.
- **Code:**
  - New:
    - `game/scripts/ai/search_capture.gd`, the soldier's brain;
    - `game/scripts/stealth/`: `boat_chase.gd`, `squad_plan.gd` (landing, points, leaving), `capture_rules.gd` (touch, free, the whole-party test) and `capture_outcome.gd` (the router, the check and the item rule);
    - `game/scripts/run/island_history.gd`;
    - a scene panel under `game/scenes/ui/`.
  - Changed:
    - `patrol_route.gd` (the stealth change's brain): it hands a chase or a landing off;
    - `player.gd` and `player_net.gd`: the captive state;
    - `coop_session.gd`: the scene's line RPC, the out-of-play captives and the dinghy. Freeing uses the existing interact intent, so no new client intent is added;
    - `island_travel.gd`: the history, previous and next, and the index counting;
    - `condition_check.gd`, `effect_applier.gd` and `inventory.gd`: removing items by capability;
    - `content_validator.gd`;
    - `body_marks.gd`: the rope mark;
    - `hud_text.tres`.
- **Specs:** `guardacostas-stealth` only (see Capabilities). The rule that a taken captive has left the island is stated there, and escape-routes "Split parties" reads it.
- **Sequencing:**
  - Build after the `guardacostas-stealth` build merges. This change extends its brain, its `patrol_alerted` hook, its spot meter and its cues, and it touches the same `creature.gd`, `player_net.gd`, `coop_session.gd` and `patrol_data.gd`.
  - Archive after `guardacostas-stealth`, because this change's Alert delta modifies the requirement that change adds.
  - `balsero-lore` adds the "Almendrón capture" requirement, which this change's scene data honours. Neither change modifies the other's requirements.
  - `dead-spectate` (PR #52) adds the watching view that out-of-play captives can use.
- **Docs** come with the build (tasks.md group 12):
  - `docs/GAME_DESIGN.md` §9;
  - `docs/BESTIARY.md` "Shore squad";
  - `docs/ISLANDS.md` "Chains and distance";
  - `docs/CHARACTERS.md` Rodríguez;
  - `docs/CONTENT_MANIFEST.md`;
  - `TASKS.md`.
