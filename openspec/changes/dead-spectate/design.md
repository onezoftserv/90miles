# Design

## Context

**The view today**
- Every `PlayerBody` carries its own `Camera2D` (`$Camera`). `PlayerBody.refresh_local()` turns it on only on its own peer (`camera.enabled = is_local`). `refresh_local()` runs in `_ready` and again in `rebind()` when a player takes back a body.
- Camera limits are set per body on every peer:
  - `IslandArrival.fit_camera` from `GameShell._on_player_spawned`, and `IslandTravel._land` for every body.
  - `Crossing._bind_body` for each rider.
- So any body's camera already frames whatever that body is on.

**Death and the end of the run**
- `SurvivalMeters.dead` is synced to every peer through `StateSync`, with `spawn = true`. So are every meter, `downed`, `net_dropped` (from `dropped-teammate-state`) and `net_inventory`.
- `left_island` is set on every peer by `IslandArrival.hold` / `land`.
- `GameShell._check_run_over` asks `IslandTravel.check()`, which returns `OVER` once no body is still playing: not dead, not waiting and not dropped on the island. The summary then replaces the HUD on every peer.
- A dead co-op player keeps their camera on their own body until then. A solo death is `OVER` at once.

**The HUD**
- `RunHud` lives in a `CanvasLayer` beside the shell, outside the world `SubViewport`. A camera it owned would move nothing in the world.
- It binds the local body in `_bind_local` and listens to `player_rebound`. Its `refresh()` runs every frame.
- Its bottom band belongs to `InventoryStrip`, which already hides itself for a waiting rider (`body.left_island`).

**Coordination**
- Sibling sessions edit `coop_session.gd` (`join_state_sent`, `run_record`, `submit_intent`) and `game_shell.gd` (`net-platform-seam`). This change touches neither.

## Goals / Non-Goals

**Goals:**
- A pure presentation change: nothing new on the wire, no host state, nothing in the simulation. Art and views never change the simulation (CLAUDE.md).
- The same behaviour on the host, a client, a late joiner and a rejoiner, because it is computed from replicated state alone.
- Solo is untouched and tested.

**Non-Goals:**
- A free ghost camera, haunting, an *ánima* nudge, a morale drain on the living per dead teammate, or showing the living who watches them. These are the Don't Starve Together ideas recorded in `REFERENCE_DST.md` §"Ghost form and haunting"; each would be its own change.
- Showing the watched teammate's inventory. It is synced, but the strip is an input surface and the dead cannot act.
- Key remapping in settings. The two actions are ordinary input-map actions, so a later remapping screen picks them up.

## Decisions

### D1. Reference games: a locked follow of a chosen living player, chat kept, the full view of the one watched

None of the four games has a built-in "follow a living teammate" camera. The pieces we take, read in `reference/` (ideas only, no code, data or text copied):

**Borrowed**
- **Shattered Pixel Dungeon, `ui/DangerIndicator.java` `onClick()`.** Each press asks `Hero.visibleEnemy(++enemyIndex)` for the next visible enemy, wrapping round, and points the camera at it. Our "spectate next" and "spectate previous" work the same way: the next index in a fixed list, wrapping (D5).
- **Shattered Pixel Dungeon, `scenes/GameScene.java` `gameOver()`, and Brogue CE, `RogueMain.c` `gameOver()`.**
  - When the only hero dies, the game-over banner shows over the level with nothing left to watch.
  - We keep this for solo: the summary comes straight away, as today.
- **Brogue CE, `IO.c` `refreshSideBar()`.**
  - In playback mode the sidebar opens with a fixed "-- PLAYBACK --" header.
  - The watched character's full stats stay underneath.
  - This is our bottom-band "Mirando a:" line, with the watched teammate's meters in the meters panel (D6).
- **Brogue CE, `Recordings.c` `pausePlayback()` / `playbackPanic()`.** When playback cannot go on, the viewer is told and stays in control; nothing crashes. We do the same when the watched body goes away: move on, or go back to the player's own body (D5), never leave a camera pointing at a freed node.
- **DCSS WebTiles, `tileweb.cc` (the `spectator_joined` message → `TilesFramework::_send_everything()`).**
  - A watcher gets the full state once, then the normal updates.
  - We need nothing new for that: a joiner or a rejoiner already gets every body with `spawn = true` state, so a dead rejoiner can watch on the first frame (D4).
- **DCSS WebTiles, `webserver/static/scripts/client.js` (input while watching) and `webserver/webtiles/ws_handler.py`.** A watcher can chat but sends no game input. Our dead keep quick chat; their movement intents already do nothing on the host.
- **Don't Starve Together, the coop-networking section of `REFERENCE_DST.md` ("Ghost form and haunting", "A view for the dead") and [Ghost Characters](https://dontstarve.wiki.gg/wiki/Ghost_Characters).**
  - A dead player stays in the game and keeps talking.
  - The project notes already asked for "a spectate camera that follows a living teammate and keeps quick chat", and we take that.

**Rejected**
- **Don't Starve Together's free-flying ghost** ([Ghost Characters](https://dontstarve.wiki.gg/wiki/Ghost_Characters)) and **Brogue's playback omniscience** (Tab in `Recordings.c` `executePlaybackInput()`).
  - A free camera would let the dead scout for the living and could be relayed through quick chat. An all-seeing view would do the same.
  - The dead see only what the watched teammate's camera frames.
- **Don't Starve Together's 120 s world-reset countdown when everyone is dead** ([Death/DST](https://dontstarve.wiki.gg/wiki/Death/DST)). It exists because ghosts can revive themselves. Ours cannot, so the summary stays immediate.
- **DCSS's way of choosing whom to watch** (`ws_handler.py` `watch(username)` from the lobby list), with no cycle control: to switch you leave and pick again. A couch co-op player needs one key.
- **DCSS's `process_handler.py` `update_watcher_description()`.** Every player sees who watches them. That is useful online, noise at a 4-player table: rejected for now.
- **Shattered Pixel Dungeon's smooth pan to the chosen target.** It moves one camera. We switch between the bodies' own cameras (D3), which is a cut. A cut keeps the pixel view crisp and never drags the view across the whole sea during a crossing. Revisit if playtests find it jarring.

### D2. Client-side only

- `dead`, the meters, `net_dropped`, positions and `left_island` already reach every peer, joiners included. So whom to watch can be worked out locally, and no peer needs to know who watches whom.
- No RPC, no synced property, no `coop_session.gd` edit.
- A dead player's intents still reach the host and still do nothing there (`_acting_body` and the downed step), so reusing A and D for switching (D7) changes nothing on the host.

### D3. Use the watched body's own camera

- **What `SpectateView` does.** It disables the local body's camera, then enables the watched body's camera and calls `make_current()`. When watching stops, it disables that camera and calls `own.refresh_local()`, then `make_current()` on the player's own camera.
- **Why the bodies' own cameras.** They already carry the right limits for the island, the next island and the crossing's sea (Context). A new `Camera2D` that copies the target would need a home inside the world viewport and would have to copy those limits every frame. The shell is out of bounds, and island travel frees the session's non-core children.
- **The catch.** `rebind()` → `refresh_local()` turns the camera off on a watched teammate who rejoins. The view re-asserts the camera on `player_rebound` and whenever it finds the watched camera disabled.

### D4. State-driven every frame, holding the body

- `RunHud.refresh()` (every frame) calls `SpectateView.update()`. It reads:
  - The local body's `meters.dead` and `left_island`.
  - The candidates, in the teammate list's order.
- It reads no `died` signal: a rejoiner who takes back a body that died while away gets `dead` as spawn state, with no signal. A late joiner gets names after the bodies.
- It holds the watched `PlayerBody`, not a peer id:
  - Removal frees the body, and `is_instance_valid` catches that.
  - A rejoin changes the peer, and the name comes from `session.peer_of(body)`.
- It keeps the last position it watched, so "nearest" (D5) has a reference when the watched body is gone.

### D5. Whom, in what order, and losing them

- **Watchable:** a teammate (not the local body) whose meters are not dead and who is not `left_island`. A rider in a crossing is not `left_island`, so they are watchable at sea.
- **Disconnected teammates:** a disconnected teammate (`session.is_dropped`) is watchable only while no connected teammate is. The line then uses `watching_dropped`, "Mirando a: Papo (desconectado)", the same mark as the waiting line.
  - A dropped body on the island keeps the run open for up to 90 s (escape-routes "Split parties"). Leaving the dead staring at their own body for that long would be worse than showing who holds the run open.
- **First pick:** the watchable teammate nearest the local body. After a loss: the one nearest the last watched position. Ties go to list order.
- **Order:** peer id, as the teammate list sorts it (`session.peer_ids()`). "Next" and "previous" wrap.
- **Nobody watchable:** the view goes back to the local body and the line hides. This happens:
  - for a moment between a death and the summary;
  - while a dead player's last teammates all wait on the shore before travel.

### D6. The HUD while watching

- **The line.** A `Watching` label in a `HudPanel` sits in the bottom band, centred where the strip sits (y 330–356 in 640×360).
  - It is a HUD panel, so the interact prompt's `panel_rects()` keeps clear of it.
  - Its text is `HudText.line(&"watching")` with the name, then `watch_keys` with the two action labels for the current device: "Mirando a: Papo  [A] [D] Cambiar". The labels come from `InputLabels.label_for`, so a gamepad shows "Cruz ←" and "Cruz →".
- **The meters panel.** `MetersHud.bind(watched.meters)` while watching, and `bind(own.meters)` after. The sunstroke blur follows the watched teammate too: it is their view.
- **The strip and the prompt.**
  - `InventoryStrip` gains a `watching` flag set by the HUD, which hides it as `left_island` already does. It drops a held use the same way.
  - The prompt already hides for a downed body. A dead body is downed, and a waiting rider is `left_island`.
- **What stays.** The teammate list, the name tags, the quick-chat wheel and the day phase are unchanged.

### D7. Input

- Two new actions in `project.godot`, so a later remap screen and `InputLabels` see them:
  - `spectate_prev`: A, ←, D-pad ← (joy button 13), mouse wheel up.
  - `spectate_next`: D, →, D-pad → (joy button 14), mouse wheel down.
- `RunHud._input` handles them while `SpectateView.active()` and `input_open()`, with no echo.
- A and D are `move_left` and `move_right` too, and the D-pad and the wheel are `slot_prev` and `slot_next`. Each overlap is harmless:
  - Movement is read by `PlayerInput` for a body that cannot move.
  - The strip is hidden while watching (D6), so `strip.accepts_input()` is false and the wheel reaches nothing else.
- The left stick is not bound: an analogue axis repeats while held, and the D-pad already covers the gamepad.

### D8. Waiting riders watch too

- `SpectateView.wants_to_watch(own)` is `meters.dead or left_island`, never in solo.
- The waiting line ("En la orilla. Esperando a: …", from `GameShell`) stays at the top. The watch line sits at the bottom.
- When the party lands, `left_island` goes false, so watching stops and the strip comes back.

### D9. Tests

- **`test_spectate_view.gd`: offline, an offline session with extra bodies** (the `test_run_hud.gd` pattern):
  - the solo case;
  - the nearest first;
  - stepping and wrapping;
  - waiting and dead teammates skipped;
  - a disconnected teammate only when alone;
  - losing the watched body (death, `left_island`, freed);
  - the camera re-asserted after a rebind;
  - the meters swap;
  - the strip hidden;
  - the line's text;
  - the input actions' events.
- **`test_game_shell.gd`: 1 player.** A solo death reaches `Flow.SUMMARY` and never engages watching.
- **`test_dead_spectate_net.gd`: NetHarness, host plus clients:**
  - a client watches the host;
  - the host watches a client;
  - a dead rejoiner watches at once;
  - a late joiner who dies watches with the right name;
  - a dropped-only teammate is marked.

  NetHarness puts every session in one viewport, so the tests assert the watched body, `camera.enabled` and the line, never `is_current()`.
- **`tests/manual/dead_spectate_run.gd`: two processes on UDP 7787.** It runs the real `GameShell`, because the coop playground builds no `RunHud`:
  - The host kills the client's player through the meters hook the GUT tests use.
  - The client prints which body its current camera belongs to and its line.
  - Then the host dies and both reach the summary.

## Risks / Trade-offs

- [Two HUD sessions in one test viewport fight over `make_current()`.] → Tests never assert viewport currency. `make_current()` is called only when the watched body changes or its camera was found off, never every frame.
- [A dead player switching with A/D also sends movement intents.] → The host already ignores a dead body's movement (downed step). A test checks the dead body's position does not change.
- [A rider waiting during a crossing could watch that crossing's sea from a body framed by the old island bounds.] → Each body's limits are set where that body is (Context), so the view always frames the watched body's own ground.
- [The cut between cameras can jar.] → It is deliberate (D1). One `Camera2D.reset_smoothing()` keeps a cut clean if smoothing is ever turned on.

## Owner decisions (pending, 2026-11-14)

The specs above state the recommended option for each. They will be updated if the owner picks another.

- **Q1. Switch keys.** (A, recommended) A/D, ←/→, D-pad ←/→ and the mouse wheel, like walking left and right. (B) Tab and gamepad Y step forward only. (C) The interact key (E or gamepad A) steps forward only.
- **Q2. Meters while watching.** (A, recommended) The watched teammate's meters. (B) The meters panel is hidden. (C) The dead player's own meters, at 0, stay.
- **Q3. The line.** (A, recommended) "Mirando a: Papo" plus "[A] [D] Cambiar". (B) "Viendo a Papo". (C) The narrator's Cuban voice: "'Tás muerto. Mirando a: Papo".
- **Q4. Waiting riders.** (A, recommended) Riders waiting on the shore watch too, which closes the coast-cay follow-up. (B) Only the dead watch for now, and waiting riders stay a follow-up.
