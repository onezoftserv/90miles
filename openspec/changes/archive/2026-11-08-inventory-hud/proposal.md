# Proposal

## Why

Crouch (C) and interact (E) work (measured on 06e9f2c; the code they run is unchanged on main at 8d3c4ca), but nothing on screen shows them: the player is a placeholder sprite that never changes, no prompt says what E will do or how long a hold has left, and no inventory is drawn, so nobody can see what they carry. Item use and recipe choice exist only as host calls (`CoopSession.use_item`, `CoopSession.craft`) that no key or screen reaches, so a real solo run cannot drink, eat, light a fire or be survived. Quick chat (Q) stays off in solo, as ui-shell and the owner decided; this change does not touch it.

## What Changes

- An inventory strip in the HUD's bottom band at 640×360: one slot per inventory slot (12), numbered from 1 on screen (screen slot n is inventory slot n − 1), each with the item's icon or, until it has one, the first letters of its Spanish name, the count of a stack or the uses left of a tool, and its key while the keyboard is in use; the selected slot framed, empty slots drawn empty; above it the selected item's Spanish name and its use verb with the key ("Coco · [F] Beber"), cut with "…" when too long; the carried weight against the limit at its right ("Peso 4,5/30"). All of it sits on HUD panels. It redraws whenever the host's inventory reaches this peer, and follows a rejoined player's reclaimed body.
- Slot selection: the number row (1-9, 0, -, =) picks screen slots 1-12; the mouse wheel (anywhere, the strip included) and the gamepad D-pad left/right cycle through the slots that hold something; a click picks a slot. Selection is this peer's own, never sent, and does not change what a gull counts as held food.
- A new `use_item` action (F, gamepad X): holding it for the selected item's use time (instant at 0) asks the host to apply the item's first use through `CoopSession.use_item`. A solo player in a last stand gets the first use that revives; in co-op, a downed (not dead) teammate within reach gets the item's use that revives others. The HUD checks what it can see first, by the same two checks the host runs, and shows a Spanish reason when the slot is empty, the item has no use, the player is down, the player is on a crossing, the target is out of reach, or a condition fails ("Te falta con qué abrir el coco."); the host still decides.
- A crafting list at the workbench: E at the bench opens it at the left edge above the strip's lines; it lists the bench's workbench recipes and the build-site recipes whose output is a structure (today the fire and the rain catcher, since no workbench recipe exists yet), with each input as carried/needed, missing ones dimmed, required tools and the optional speed-up tool by name; arrows, D-pad up/down, the wheel or the mouse move the highlight; E, gamepad A or a click chooses; F does nothing while it is open; Esc, Start or walking out of reach closes it. Choosing goes through `CoopSession.craft`: a workbench recipe starts the Crafter, a build-site recipe has the host place its site at the player's feet; a refused choice keeps the list open with its reason.
- Build sites placed at the bench reach every peer and later joiners: they spawn through the session's entity spawner (its one spawn function gains a `kind` key beside creatures-ai's creatures), their tag deposits now sync with their item deposits, a joiner asks for the live state, and the finished structure exists once, its build effects applied once on the host.
- An interact prompt over the candidate InteractionPicker would pick for the local player now: "[E] Recoger Coco", "[E] Trepar Mata de coco", "[E] Espantar Gaviota", "[E] Construir Balsa" with what the site still needs ("Falta: Madera de la costa x4") or its shared progress, and a 10 px ring that fills while a timed hold counts down. From a press until release the prompt and ring stay on the target the press started on, as the host's hold does. The prompt sits above its target (above the name tag for a player), at most 240 px wide, and is kept clear of every HUD panel. Verbs and labels come from a HUD text data file and from content names; nothing names what a concealed thing holds.
- A crouch cue: the body is drawn at 10 of its 16 px while crouching, and a small closed-eye mark, drawn by the HUD so night and the Suave filter leave it alone, shows over a player's head while their stealth state is hidden. Both follow the movement and stealth states the host already replicates, so teammates see them too.
- Input rules: the new actions share no key or button with an existing one; HUD slots and rows never take focus; while the crafting list is open, E acts on the list, F does nothing and the player's intent carries no interact press; Esc closes the list before it can pause (and in co-op, where nothing pauses, it only closes the list); the pause menu, the run summary and the host-lost screen take all input. Key labels follow the last device, which only a button press or a stick past its deadzone switches to gamepad.
- A HUD text file (`game/resources/hud_text.tres`, Spanish first, English beside it) holds every HUD verb, label and refusal line, so a writer rewords them with no script change.
- **Out:** a full inventory window, dropping, splitting or moving items between slots, giving items to teammates, equipment, a build mode that places sites away from the bench, crafting at a fire, quick chat in solo, PlayStation button glyphs, rebinding keys, art for items and characters.

## Capabilities

### New Capabilities
- `inventory-hud`: what the local player sees and presses to manage what they carry during a run: the inventory strip and its selection, using the selected item, the workbench crafting list, the interact prompt with its hold ring and placement, the crouch and hidden cues, and how these inputs share the keyboard, mouse and gamepad.

### Modified Capabilities
- `player-movement`: "Named input actions" gains the use, slot and list actions with their keyboard or mouse defaults and, where one exists, their gamepad defaults.
- `crafting-inventory`: "Workbench" (MODIFIED) becomes an interactable that also places the sites of build-site recipes whose output is a structure; "Placing a build site" (ADDED) says where the host puts the site and that the station must be a workbench in reach; "Placed sites on every peer" (ADDED) says sites, their item and tag deposits, progress and structures reach every peer and later joiners, and that a structure and its build effects happen once.
- `coop-networking`: "Pause" (MODIFIED): in co-op the pause button still pauses nothing, and now closes an open HUD panel.
- `ui-shell`: "HUD layout" (MODIFIED) gives the bottom band to the inventory and keeps panels out of the centre; "Inventory band and world marks" (ADDED) says what the band holds and which world-anchored marks may sit in the centre. ui-shell is still an active change, so this delta can only be archived after it (see Ordering).

## Impact

- HUD: `game/scenes/ui/run_hud.gd/.tscn` gains an inventory strip, a crafting list, the refusal line, the interact prompt and the hidden marks (new scenes in `game/scenes/ui/`), bound to the local player in one place called from `_follow` and `_on_player_rebound`; a `HudCount` Label variation in `game_theme.tres`; `GameShell` tells the HUD when the summary or host-lost screen shows.
- Player: `game/scenes/player/player.gd/.tscn` (crouch cue), `game/scripts/player/player_input.gd` (no interact press while a HUD panel holds the input).
- Interaction and structures: `Interactable` gains a prompt id, `hides_contents` and `prompt_target` (asked of its owner); `world_item`, `palm`, `build_site`, `fire`, `rain_catcher`, `raft` and `creature` scenes, `DragHandle` and `RescuePoint` set theirs; `Workbench` adds its own Interactable in code, so every `Workbench.new()` keeps working; `BuildSite` joins a new `build_sites` group.
- Crafting and net: `ItemUser.check` (the checks of `ItemUser.use`) and `UsePlan.actor_reason` (the checks of `use_for`), each shared by the host and the HUD; `CoopSession.craft_for` places build-site recipes through `_spawn_entity`, dispatched by a payload `kind`; `BuildSite.receive_state` gains tag deposits, a client's synced site asks for the live state, and a spawned site's completion spawns its structure once from the host. Names and peers of other players go through `session.peer_of`.
- Data and config: `game/project.godot` input map (`use_item`, `slot_1`-`slot_12`, `slot_next`, `slot_prev`, `list_up`, `list_down`); new `game/resources/hud_text.tres` with its class.
- No new autoload, no backend change, no change to any `.tres` item, recipe, creature or island number.

## Solo

Everything here works with exactly one offline player: the strip shows the solo player's own inventory, F drinks a coconut with the knife from the hut, the bench places a fire site at the player's feet, E deposits and works it and the raft, and the hold ring times every hold. The change adds a 1-player test that finishes the sandbar, creatures on, from default inputs alone (knife, palm, coconut, fire, raft, launch). Nothing needs a teammate; reviving a downed teammate with F is the co-op extra, and a solo player in a last stand drinks their own reviving cup.

## Owner decisions (2026-11-08)

1. One change, `inventory-hud`: the strip in the bottom band (12 slots, Spanish names, counts), number keys and the mouse wheel to pick a slot, F to eat, drink or use the selected item, a crafting list at the workbench, an [E] prompt with a hold ring over the nearest interactable, the player drawn lower when crouching and with a mark when hidden. It must make a full solo run playable.
2. Quick chat stays off in solo.

3. Confirmed by the owner on 2026-11-08, each with the recommended option:
   - The workbench list also offers the fire and rain-catcher build sites, placed at the player's feet.
   - In co-op, F on a downed teammate within reach uses the selected item on them. In a solo last stand, F uses its reviving effect on yourself.
   - At sea, F is refused with "En plena travesía no se puede." and the [F] hint is hidden, matching the host today.
   - The key defaults below: F; 1–9, 0, - and = for the slots; wheel and D-pad left/right; the arrows and D-pad up/down in the list; gamepad X to use and A to choose.

## Choices made in this proposal (the first four confirmed by the owner, the rest stand unless revisited)

- **Items on a crossing (confirmed: refuse at sea).** Today the host refuses every use from a rider for the whole 60-120 s crossing, and GAME_DESIGN.md §8 is silent. Provisional default, matching the host as it is: the HUD refuses too, drops "[F]" from the item line and says "En plena travesía no se puede." The alternative lets riders use items at sea and needs a crafting-inventory or crossing delta for the host's check (design D11).
- The workbench list also offers build-site recipes whose output is a structure, and places their site at the player's feet, because the content has no workbench recipe yet and nothing else can start a fire or a rain catcher in a real run (crafting-inventory "Shared builds" says a site is placed by the first player who starts its recipe, but no screen does it).
- Gamepad: X uses, D-pad left/right cycle slots, D-pad up/down move the list highlight, A chooses in the list.
- F on a downed teammate within reach uses the selected item's reviving use on them (co-op only).
- Slots are 26×26 px; an item without an icon shows the first three letters of its Spanish name; the slot key shows top-left on the keyboard; the weight readout sits right of the strip.
- The HUD pre-checks a use on the state this peer sees and says why it would fail; the host refuses silently when its state differs (no new host-to-client message).
- The fixed Spanish lines ("Fabricar en el banco", "Zarpar en la balsa", "Espantar Gaviota", "Eso ya está en obra.", "Falta: Madera de la costa x4", "En plena travesía no se puede.") are first drafts in `hud_text.tres` for a writer to reword.

## Ordering

Active changes on main (8d3c4ca): `ui-shell`, `coop-reconnect`, `secret-cay` and `balsero-lore`.

- `ui-shell` adds the `ui-shell` capability, whose "HUD layout" says the bottom band and the centre stay clear. This change's `specs/ui-shell/spec.md` modifies that requirement and adds "Inventory band and world marks"; `openspec validate` accepts it, and archive refuses it until `openspec/specs/ui-shell/` exists. So `ui-shell` is archived before this change (tasks "Workflow").
- `coop-reconnect` modifies coop-networking "Disconnect handling" and adds "Player identity", "Reclaiming a player" and "Join request"; this change modifies coop-networking "Pause", which no active change touches. Its code is on main and this change builds on it (`player_rebound`, `peer_of`).
- `secret-cay` modifies crafting-inventory "Item resource" and "Pick-up" and coop-networking "Difficulty scaling"; this change modifies crafting-inventory "Workbench" and adds two requirements, so no header overlaps. Its needle and note label sit at the top centre and the prompt keeps clear of them.
- `balsero-lore` touches creatures-ai, crossing, endings-progression, escape-routes and npcs-dialogue, none of which this change modifies.
- `player-movement`, `crafting-inventory` and `coop-networking` are archived capabilities, so their blocks are MODIFIED here from `openspec/specs/`.
