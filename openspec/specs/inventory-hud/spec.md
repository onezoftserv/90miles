# inventory-hud Specification

## Purpose
What the local player sees and presses to manage what they carry during a run: the inventory strip and its selection, using the selected item, the workbench crafting list, the interact prompt with its hold ring, and the crouch and hidden cues, on keyboard, mouse and gamepad, solo and co-op.

## Requirements

### Requirement: Inventory strip
During a run the HUD SHALL show the local player's inventory as one row of 26×26 px slots, one per inventory slot (12, or 13 with the Experiencia slot), 2 px apart, centred in the bottom band of the 640×360 view with a 4 px bottom margin. Slots are numbered from 1 on screen: screen slot n is inventory slot n − 1. The selected item's line and the refusal line sit above the row and the weight to its right, all on HUD panels, clear of the meters, the day phase, the teammate list and the centre.

#### Scenario: Solo strip at 640×360
- **GIVEN** a solo run on the sandbar
- **WHEN** the HUD is drawn
- **THEN** 12 slots of 26×26 px sit in one row from x 153 to 487 and y 330 to 356, inside the view and overlapping neither the meters panel nor the day phase

#### Scenario: Co-op strip beside the teammates
- **GIVEN** a host with one client
- **WHEN** each peer draws its HUD
- **THEN** each shows its own player's strip in the bottom band and its teammate list top-right, and the two do not overlap

#### Scenario: Screen slot 1 is inventory slot 0
- **GIVEN** a solo player with an empty inventory next to a coconut
- **WHEN** they pick it up
- **THEN** inventory slot 0 holds it and the strip draws it in screen slot 1, the slot key 1 selects

### Requirement: Slot contents
Each slot SHALL show its item's 16×16 icon or, while it has none, the first three letters of its Spanish name; bottom-right, a stack's count above 1 or the uses left of an item with more than 1 use, outlined; top-left, the slot's key while the last device used is the keyboard. An empty slot keeps its frame and key. The selected slot has the theme's sun-yellow frame. The weight reads "Peso <carried>/<limit>" with a decimal comma. Solo the same.

#### Scenario: A stack, a tool and an empty slot
- **GIVEN** a solo player on the keyboard holding 3 coco in screen slot 1 and a knife with 39 uses left in screen slot 2, with screen slot 3 empty
- **WHEN** the strip is drawn
- **THEN** slot 1 reads "Coc" with 3 bottom-right and "1" top-left, slot 2 reads "Cuc" with 39, slot 3 shows only its frame and "3", and the weight reads "Peso 2,5/30"

#### Scenario: No slot keys on a gamepad
- **GIVEN** the same player after pressing a gamepad button
- **WHEN** the strip is drawn
- **THEN** no slot shows a key

### Requirement: The selected item's line
The line above the strip SHALL read the selected item's Spanish name and, when it has a use, the use key and verb, with the teammate's name when the use goes to one. A line longer than its 334 px (41 characters) is shortened by cutting the teammate's name first, then the item's name, each cut ending in "…", and never wraps onto the strip. Solo the same.

#### Scenario: Name, key and verb
- **GIVEN** a solo player on the keyboard with screen slot 1 selected and holding coco
- **WHEN** the strip is drawn
- **THEN** the line reads "Coco · [F] Beber"; with driftwood selected it reads "Madera de la costa" alone

#### Scenario: The longest line
- **GIVEN** a co-op player with a rain cup selected, 0.5 tiles from a downed teammate whose name has 16 characters
- **WHEN** the strip is drawn
- **THEN** the line fits in 41 characters on one line, keeps "Vaso de agua de lluvia · [F] Beber:" whole and ends the teammate's cut name with "…"

### Requirement: Strip follows the host
The strip SHALL show the inventory the host holds for the local player and redraw each time it reaches this peer; it never changes the inventory itself. A solo player's strip changes on the frame their inventory does. A player who rejoins and takes back their body gets that body's strip, prompt and use button. While the local player has left the island and is out of play, the strip, its lines and the prompt are hidden; in solo the run then ends.

#### Scenario: A client's strip after a pick-up
- **GIVEN** a host and a client whose player stands next to driftwood
- **WHEN** the client presses interact and the host's inventory state for that player arrives
- **THEN** the client's strip shows 1 driftwood in screen slot 1, and before it arrives the client's strip is unchanged

#### Scenario: Solo pick-up shows at once
- **GIVEN** a solo player with an empty inventory next to a coconut on the ground
- **WHEN** they press interact
- **THEN** screen slot 1 shows the coconut on the same frame

#### Scenario: A gull takes the coconut
- **GIVEN** a solo player holding one coconut and nothing else that is food, within a gull's reach
- **WHEN** the gull steals it
- **THEN** that slot is empty on the same frame and stays selected if it was

#### Scenario: A rejoined client
- **GIVEN** a client holding driftwood that drops and joins again within 90 s with the same identity
- **WHEN** it takes back its body
- **THEN** its strip shows the driftwood, its prompt follows that body and its use button acts for it

#### Scenario: Gone by raft
- **GIVEN** a co-op player whose raft has arrived while a teammate stays on the island
- **WHEN** their HUD is drawn
- **THEN** it shows no strip and no prompt

### Requirement: Selecting a slot with the keyboard and mouse
The number row SHALL select screen slots by key position: 1 to 9 pick slots 1 to 9, 0 slot 10, - slot 11 and = slot 12. The mouse wheel, wherever the pointer is, moves the selection to the next (down) or previous (up) slot that holds an item, wrapping round; with every slot empty it stays. A left click on a slot selects it. The selection belongs to this peer, is never sent to the host, and stays on its slot when that slot empties. Solo the same.

#### Scenario: Number keys
- **GIVEN** a solo player with screen slot 1 selected
- **WHEN** they press 0
- **THEN** screen slot 10 is selected, even if it is empty

#### Scenario: Wheel skips empty slots
- **GIVEN** a solo player holding items in screen slots 1 and 4 only, with slot 1 selected
- **WHEN** they roll the wheel down once, then once more
- **THEN** slot 4 is selected, then slot 1 again

#### Scenario: Wheel over the strip
- **GIVEN** the same player with the pointer resting over the strip
- **WHEN** they roll the wheel down
- **THEN** the selection moves exactly as it does with the pointer over the world

#### Scenario: The last coconut
- **GIVEN** a solo player with screen slot 2 selected holding their only coconut and a knife
- **WHEN** they drink the coconut
- **THEN** slot 2 is empty and still selected

### Requirement: Selecting a slot with a gamepad
On a gamepad, D-pad right and left SHALL move the selection to the next and previous slot that holds an item, wrapping round, as the mouse wheel does, so every slot that holds an item is reachable without a keyboard. Solo the same.

#### Scenario: D-pad cycling
- **GIVEN** a solo player on a gamepad holding items in screen slots 2, 5 and 9, with slot 9 selected
- **WHEN** they press D-pad right
- **THEN** slot 2 is selected

### Requirement: Selection is not holding
The selection SHALL never change what the host or a creature counts as the item a player holds: held food stays the first food slot (creatures-ai), whichever slot is selected. Solo the same.

#### Scenario: A gull and a selected knife
- **GIVEN** a solo player holding a coconut in screen slot 3 and a knife in screen slot 1, with slot 1 selected
- **WHEN** a gull swoops on held food
- **THEN** it takes the coconut, exactly as it would with slot 3 selected

### Requirement: Using the selected item
The use button (F, gamepad X) SHALL use the selected slot's item: holding it for that use's time (`time_s`; at 0 the press is enough) asks the host to apply the use. Letting go earlier, changing the selection, the slot's item changing or the player going down cancels it, and nothing is sent. A ring on the selected slot shows the hold. The host applies the use and the strip shows the result when the inventory arrives. In solo the player is their own host.

#### Scenario: Solo drinks a coconut
- **GIVEN** a solo player with thirst 50 holding a knife and a coconut, the coconut selected
- **WHEN** they hold F for 2 s
- **THEN** thirst is 65, hunger is 5 higher, the coconut is gone and the knife has one use less

#### Scenario: Letting go early
- **GIVEN** a solo player holding a knife and a coconut, the coconut selected
- **WHEN** they hold F for 1.5 s and let go
- **THEN** nothing is used, and holding again starts from 0 s

#### Scenario: A client drinks through the host
- **GIVEN** a host and a client whose player holds a rain cup, selected, with thirst 50
- **WHEN** the client holds F for 1 s
- **THEN** the host sets that player's thirst to 75 and removes the cup, and the client's strip then shows the slot empty

### Requirement: Which use the button picks
The use button SHALL send the item's first use, on the player themself, with two exceptions read from the item's data: during a solo last stand it sends the item's first use that revives; in co-op, when a teammate who is downed and not dead is within 1 tile and the item has a use that revives others, it sends that use on the nearest such teammate, and the selected item's line adds their name ("[F] Beber: Papo"). When the use it needs does not exist the item counts as having no use.

#### Scenario: Solo last stand
- **GIVEN** a solo player in a last stand holding a rain cup, selected
- **WHEN** they hold F for 1 s
- **THEN** they stand at 30 health and the cup is gone

#### Scenario: Reviving a teammate
- **GIVEN** a co-op player holding a rain cup, selected, 0.5 tiles from a downed teammate
- **WHEN** they hold F for 1 s
- **THEN** the teammate stands at 30 health with thirst 25 higher and the cup is gone; with no downed teammate in reach the player drinks it instead

#### Scenario: A dead teammate is skipped
- **GIVEN** a co-op player holding a rain cup, selected, 0.5 tiles from a dead teammate and 3 tiles from anyone downed
- **WHEN** they hold F for 1 s
- **THEN** they drink it themself

### Requirement: Refused uses
Before sending, the HUD SHALL check the use against the state this peer sees, by the rules the host applies, and on failure show a Spanish reason for 2 s above the selected item's line and send nothing. Reasons: an empty slot, no use, down outside a last stand, on a crossing, a target out of reach or not usable, and a failed condition (naming the missing tool). The host still decides and, where its state differs, refuses and changes nothing. Solo the same.

#### Scenario: No blade for the coconut
- **GIVEN** a solo player holding a coconut and no item that opens coconuts, the coconut selected
- **WHEN** they press F
- **THEN** "Te falta con qué abrir el coco." shows, nothing is sent and the coconut stays

#### Scenario: Empty slot
- **GIVEN** a solo player with an empty slot selected
- **WHEN** they press F
- **THEN** "No tienes nada ahí." shows and nothing is sent

#### Scenario: On the crossing
- **GIVEN** a solo player on the raft crossing holding a rain cup, selected
- **WHEN** the strip is drawn and they press F
- **THEN** the selected item's line shows no "[F]", "En plena travesía no se puede." shows, nothing is sent and the cup stays

#### Scenario: Forged use
- **GIVEN** a client that sends a use for a slot it has nothing in
- **WHEN** the host receives it
- **THEN** nothing changes

### Requirement: Workbench crafting list
Pressing interact when this peer's candidate is a workbench SHALL open the crafting list at the left edge, above the strip's lines (4,162 to 244,302), clear of the meters and the centre; it does not pause and sends no craft request. The opening press reaches the host as an ordinary interact on the bench and changes nothing there. The list closes when the player leaves the bench's reach (1 tile and the slack), presses pause, has a choice sent, goes down, or a screen opens. Solo the same.

#### Scenario: Open and walk away
- **GIVEN** a solo player within 1 tile of the hut's workbench
- **WHEN** they press E and then walk 2 tiles away
- **THEN** the list opens on the press and closes when they leave reach, and the clock kept running

### Requirement: Crafting list contents
The list SHALL show, sorted by Spanish name, every known workbench recipe and every known build-site recipe whose output is a structure. The highlighted row lists each input and tag as carried/needed by name, each required tool as "Con qué <tool phrase>" and an optional speed-up tool as "Más rápido: <tool phrase>". Anything carried fewer times than needed is dimmed; the speed-up tool never is. A workbench recipe missing anything is dimmed; a build-site row never is. Solo the same.

#### Scenario: The sandbar's list
- **GIVEN** a solo player at the hut's workbench carrying 3 driftwood and no tinder
- **WHEN** the list opens
- **THEN** it reads "Fogata" then "Recogedor de lluvia", and with "Fogata" highlighted it shows "3/3 Madera de la costa", a dimmed "0/1 Yesca" and "Más rápido: prender candela", and the "Fogata" row itself is not dimmed

#### Scenario: Partly carried
- **GIVEN** the same player carrying 2 driftwood instead
- **WHEN** "Fogata" is highlighted
- **THEN** "2/3 Madera de la costa" is dimmed

#### Scenario: Long rows
- **GIVEN** a row longer than the panel's 29 characters
- **WHEN** the list draws it
- **THEN** it ends in "…" and stays on one line

#### Scenario: A new recipe file
- **WHEN** a writer adds a workbench recipe `.tres`
- **THEN** the list shows it with no script change

### Requirement: Choosing a recipe
The list's highlight SHALL move with the up and down arrows, D-pad up and down, the mouse wheel and the pointer; interact (E, gamepad A) or a click chooses the highlighted row. Choosing sends the craft request for that recipe and bench to the host, which starts the craft or places the site, and closes the list. A dimmed row, or a build-site recipe whose site is still unfinished on the island, is refused on this peer with a Spanish reason: nothing is sent and the list stays open. Solo the same.

#### Scenario: Missing materials
- **GIVEN** a solo player at a workbench missing one input of a workbench recipe
- **WHEN** they choose that recipe
- **THEN** "Te faltan materiales." shows, nothing is sent, nothing is consumed and the list stays open

#### Scenario: Solo places a fire site
- **GIVEN** a solo player at the hut's workbench with nothing in hand, standing on the centre of a free land cell that is not the bench's
- **WHEN** they open the list, highlight "Fogata" and press E
- **THEN** the list closes, an empty fire site lies on their cell and the prompt reads "[E] Construir Fogata"

#### Scenario: A client places a site
- **GIVEN** a host and a client at the workbench
- **WHEN** the client chooses "Recogedor de lluvia"
- **THEN** the host places the site, and both peers show it at the same place

#### Scenario: A second fire site
- **GIVEN** a solo player who placed a fire site and has not finished it
- **WHEN** they choose "Fogata" again
- **THEN** "Eso ya está en obra." shows, no craft request is sent, no second site appears and the list stays open

### Requirement: Interact prompt
While the local player can act and holds no interact press, the HUD SHALL show one prompt over the interactable that the interaction picker would choose for them now (among the enabled ones within 1 tile that they may use, the highest interact priority, then the nearest; player-movement "Interaction"), as the interact key, a verb and a target: "[E] Recoger Coco". It shows nothing with no candidate in reach, while the player is down or out of play, while the crafting list is open or while a screen is shown. This peer computes it; the host still decides. Solo the same.

#### Scenario: Nearest one wins
- **GIVEN** a solo player 0.5 tiles from a coconut and 0.9 tiles from a palm
- **WHEN** the HUD is drawn
- **THEN** one prompt shows, over the coconut: "[E] Recoger Coco"

#### Scenario: Out of reach
- **GIVEN** a solo player 2 tiles from every interactable
- **WHEN** the HUD is drawn
- **THEN** no prompt shows

#### Scenario: A client's prompt
- **GIVEN** a client whose player stands within 1 tile of the raft site
- **WHEN** the client draws its HUD
- **THEN** it shows "[E] Construir Balsa" over the site without waiting for the host

#### Scenario: The perched gull's shoo shows over its palm
- **GIVEN** a solo player at the foot of a nest palm whose gull is perched there
- **WHEN** the HUD is drawn
- **THEN** one prompt shows, the gull's shoo ("[E] Espantar …"), and not "[E] Trepar Mata de coco"

### Requirement: Prompt placement
The prompt SHALL sit centred over its target at whole pixels, its bottom edge just above the target, or above the name tag when the target is a player. It is at most 240 px wide, a longer line ending in "…", and it stays inside x 4 to 636 and y 22 to 302 without covering the meters, the day phase, the teammate list, the secret-cay needle and note, or the strip and its lines. Solo the same.

#### Scenario: Over a downed teammate
- **GIVEN** a co-op player within 1 tile of a downed teammate whose name tag shows
- **WHEN** the prompt "[E] Arrastrar a Papo" is drawn
- **THEN** it sits above the tag and overlaps it nowhere

#### Scenario: At the edge of the view
- **GIVEN** a solo player at the island's west edge, where the camera stops, within 1 tile of driftwood near the view's left edge
- **WHEN** the prompt is drawn
- **THEN** its rect lies inside x 4 to 636 and y 22 to 302 and over no HUD panel

### Requirement: Prompt verbs and targets
A prompt's verb, and its target where no content name applies, SHALL come from the HUD text file under the prompt id the interactable sets; the target is the content name where one exists: the item lying there, the site's recipe, the item a structure yields, the creature, the player to drag or pull. An interactable that hides what it holds names only itself; one with no prompt id shows the key alone. Solo the same.

#### Scenario: The sandbar's prompts
- **GIVEN** a solo player on the sandbar
- **WHEN** they stand within reach of each kind of interactable in turn
- **THEN** the prompts read "Recoger <item name>", "Trepar Mata de coco", "Fabricar en el banco", "Construir Balsa", "Apagar Fogata", "Tomar Vaso de agua de lluvia", "Zarpar en la balsa" and "Espantar Gaviota"

#### Scenario: A bare palm
- **GIVEN** a solo player within 1 tile of a palm with no coconuts left
- **WHEN** the HUD is drawn and they hold E for the climb
- **THEN** the prompt still reads "[E] Trepar Mata de coco", and the climb gives nothing and costs nothing

#### Scenario: A concealed thing
- **GIVEN** an interactable whose scene marks it as hiding what it holds, with an item inside
- **WHEN** a solo player stands within reach
- **THEN** the prompt shows its own verb and label and never the item's name

### Requirement: Hold ring
For a candidate with a hold time above 0, a 10 px ring left of the prompt's key SHALL fill from the moment this peer's interact press starts on it until the hold time has passed. Until release the prompt and ring stay on that target even when another comes nearer, and empty once it is beyond reach and the slack, as the host's hold does. Instant interactions show no ring. On a client the ring is timed by its own press and may fill first. In solo the ring and the hold run on the same frames.

#### Scenario: Climbing a palm
- **GIVEN** a solo player within 1 tile of a palm with a 2 s climb
- **WHEN** they hold E for 1 s
- **THEN** the ring is half full; at 2 s it is full and a coconut is in their inventory

#### Scenario: Letting go
- **GIVEN** a solo player whose ring over a palm is half full
- **WHEN** they let go
- **THEN** the ring is empty and no coconut was taken

#### Scenario: Something nearer mid-climb
- **GIVEN** a solo player holding E on a palm, the ring half full
- **WHEN** a pick-up lands nearer to them than the palm
- **THEN** the prompt stays on the palm, the ring keeps filling and the coconut arrives at 2 s

### Requirement: Build site prompt
A build site's prompt SHALL add lines from the site's state as this peer has it: while inputs are missing, one line per missing input or tag as "<Spanish name> x<count>", the first headed "Falta:"; once every input is in, the shared build progress as a bar with a percentage. Deposited items, deposited tags and progress reach every peer, later joiners included, so every peer reads the same state. Solo the same.

#### Scenario: The raft site
- **GIVEN** a solo player next to the raft site holding 2 driftwood, with nothing deposited
- **WHEN** they press E
- **THEN** the lines under the prompt read "Falta: Madera de la costa x4", "Cámara x2" and "Soga x3"

#### Scenario: A fire site on a client
- **GIVEN** a host and a client next to a fire site placed at the bench, with nothing deposited
- **WHEN** the host's player deposits 3 driftwood, then 1 dry grass, then works the site
- **THEN** the client's prompt reads "Falta: Madera de la costa x3" and "Yesca x1", then "Falta: Yesca x1" alone, then shows the bar rising

#### Scenario: Progress seen by a client
- **GIVEN** a host working a raft site with every input in and half the work done, and a client next to it
- **WHEN** the client draws the prompt
- **THEN** its second line shows the bar at 50 %

#### Scenario: A joiner mid-build
- **GIVEN** a host who deposited everything into a fire site and worked it to 50 %
- **WHEN** a client joins and stands next to it
- **THEN** the client's prompt shows the bar at 50 % and no "Falta:" line

### Requirement: Crouch cue
While a player's movement state is crouch, their body SHALL be drawn in the crouch pose of art-pass's "Crouch pose" requirement, its full 32×32 frames with the feet line where it was and the head lower, and otherwise in the pose art-pass's "Player poses" requirement gives its state (crawling also uses the crouch pose); while they are also hidden, the hidden mark shows over the crouch pose's head anchor. Every peer draws it from the state the host replicates, so teammates see it too. A solo player sees their own body lowered.

#### Scenario: Solo crouch
- **GIVEN** a solo player walking on sand
- **WHEN** they hold C
- **THEN** their body is drawn in the crouch pose at its full 32×32 frame size with its feet line unchanged, and in the walk pose again when they let go

#### Scenario: A teammate crouches
- **GIVEN** a host and a client
- **WHEN** the client's player crouches
- **THEN** the host draws that player in the crouch pose

#### Scenario: Solo crouch in brush
- **GIVEN** a solo player standing on a brush tile
- **WHEN** they hold C until hidden
- **THEN** their body is drawn in the crouch pose and the hidden mark shows over the crouch pose's head anchor, lower than it would sit over the standing pose

### Requirement: Hidden mark
While a player's stealth state is hidden, a small closed-eye mark SHALL show over their head on every peer, drawn by the HUD so the night tint and the Suave filter do not touch it, and it goes when they are no longer hidden. A submerged (diving) player does not get it. A solo player sees it over their own body.

#### Scenario: Solo in the brush
- **GIVEN** a solo player on a brush tile
- **WHEN** they hold C
- **THEN** the mark shows over them, and it goes when they step onto sand

#### Scenario: At night
- **GIVEN** a solo player hidden in brush at Noche with the Suave filter on
- **WHEN** the HUD is drawn
- **THEN** the mark has the same colours as by day

#### Scenario: The client sees the host hide
- **GIVEN** a host and a client
- **WHEN** the host's player crouches in brush
- **THEN** the client shows the mark over the host's player

### Requirement: Inputs do not collide
The actions this capability adds SHALL share no key, mouse button or gamepad button with any other action the project defines (the engine's built-in `ui_*` focus actions aside): use F and gamepad X; slots 1-9, 0, - and =; next and previous slot the mouse wheel and D-pad right and left; list up and down the arrow keys and D-pad up and down. No HUD slot or row takes keyboard or gamepad focus. Typing in a text field selects no slot and uses nothing. Solo the same.

#### Scenario: The input map
- **WHEN** the actions defined in the project's input map are read
- **THEN** no key, mouse button or gamepad button is bound to two of them

#### Scenario: D-pad with the list open
- **GIVEN** a solo player on a gamepad with the list open
- **WHEN** they press D-pad down and then A
- **THEN** the highlight moves one row and the highlighted recipe is chosen, and no slot or row button took focus

### Requirement: Screens take input first
While the pause menu, the run summary or the host-lost screen is shown, the strip, the use button, the prompt, the crafting list and the sign note SHALL ignore input, and they hide once the local body is gone. While the crafting list or a sign note is open, interact acts on it only, the player's intent carries no interact press, and the use button does nothing. The pause button first closes an open list or note; in solo it pauses only on the next press, and in co-op it does nothing else.

#### Scenario: Paused
- **GIVEN** a solo player with the pause menu open
- **WHEN** they press 3 and F
- **THEN** the selection does not change and nothing is used

#### Scenario: Run summary
- **GIVEN** a solo player whose crossing ended and whose run summary shows
- **WHEN** they press 3, F and E
- **THEN** nothing changes and no request is sent

#### Scenario: Host lost
- **GIVEN** a client whose host went away
- **WHEN** the host-lost screen shows
- **THEN** no strip or prompt shows and the HUD reads no freed body

#### Scenario: Interact goes to the list
- **GIVEN** a solo player with the list open and driftwood on the ground within reach
- **WHEN** they press E
- **THEN** the highlighted recipe is chosen and the driftwood stays on the ground

#### Scenario: Use while the list is open
- **GIVEN** a solo player with the list open and a rain cup selected
- **WHEN** they hold F for 1 s
- **THEN** nothing is used and the list stays open

#### Scenario: Esc closes before it pauses
- **GIVEN** a solo player with the crafting list open
- **WHEN** they press Esc once, then again
- **THEN** the first press closes the list and does not pause, and the second opens the pause menu

#### Scenario: Esc in co-op
- **GIVEN** a host and a client, the client with the crafting list open
- **WHEN** the client presses Esc
- **THEN** the list closes, nothing pauses and no pause menu shows

#### Scenario: Esc closes the note before it pauses
- **GIVEN** a solo player with a sign note open
- **WHEN** they press Esc once, then again
- **THEN** the first press closes the note and does not pause, and the second opens the pause menu

#### Scenario: Use while the note is open
- **GIVEN** a solo player with a sign note open and a rain cup selected
- **WHEN** they hold F for 1 s
- **THEN** nothing is used and the note stays open

### Requirement: Key labels follow the device
Every key the HUD shows SHALL be read from the input map for the device the local player used last: keyboard and mouse ("[E]", "[F]") or gamepad ("[A]", "[X]"). A gamepad counts as used on a button press or a stick or trigger pushed past its action's deadzone; a key press or a mouse button switches back. Keys read as the player's keyboard layout prints them. Solo the same.

#### Scenario: Picking up a gamepad
- **GIVEN** a solo player whose prompt reads "[E] Recoger Coco"
- **WHEN** they press a gamepad button
- **THEN** the prompt reads "[A] Recoger Coco" and the selected item's line shows "[X]"

#### Scenario: A drifting stick
- **GIVEN** a solo player on the keyboard with a gamepad plugged in whose left stick rests at 0.1
- **WHEN** the HUD is drawn
- **THEN** the labels stay "[E]" and "[F]"

### Requirement: HUD text is data
Every player-facing word the HUD adds (use verbs per use action, prompt verbs and labels, tag and tool names, refusal lines, the weight label) SHALL come from one HUD text file, Spanish first with English beside it, shown in the session's language; item, recipe and creature names come from their content files. No HUD script holds player-facing text. Solo the same.

#### Scenario: Rewording a refusal
- **WHEN** a writer changes "No tienes nada ahí." in the HUD text file
- **THEN** the HUD shows the new line with no script change

#### Scenario: English
- **GIVEN** a solo player whose session language is English, next to driftwood
- **WHEN** the prompt shows
- **THEN** it reads "[E] Pick up Driftwood"

### Requirement: A solo run is playable from the HUD
With exactly one offline player, the default keys and nothing but this HUD, the sandbar with its creatures SHALL be finishable: pick up the knife, climb a palm, drink its coconut, place and build a fire from the workbench, gather and deposit the raft's inputs, work the raft and launch it. Nothing on that path needs a second player, a network port or a debug command.

#### Scenario: The sandbar from inputs alone
- **GIVEN** a solo run on the sandbar, creatures on, driven only by the named input actions
- **WHEN** the player takes that path
- **THEN** the raft launches with that player aboard and their thirst never reached 0

### Requirement: Sign note
Pressing interact at a flavour sign SHALL open a sign note on this peer's HUD only; it does not pause, and the press reaches the host as an ordinary interact that changes nothing. The note is a light card with dark text (contrast 7:1 or more), 240 px wide, centred under the day phase, fitted to its text: the sign's line in the game's language, word-wrapped to at most 8 lines, then "[E] Cerrar" with the device's key. Solo the same.

#### Scenario: A solo player reads the radio and walks away
- GIVEN one offline player within 1 tile of the coast cay's dead radio, language Spanish
- WHEN they press E, then walk 2 tiles away
- THEN a note opens on the press showing the radio's Spanish line wrapped to the card and "[E] Cerrar", it closes when they leave reach, and the clock kept running

### Requirement: Closing the sign note
An open sign note SHALL close when the player presses interact or pause, leaves the sign's reach (1 tile and the slack), goes down or leaves, or a screen opens. A press while it is open only closes it; it never acts on another sign or thing in reach. Solo the same.

#### Scenario: E closes the note
- GIVEN a solo player with a sign note open
- WHEN they press E
- THEN the note closes and nothing is picked up or climbed

#### Scenario: English and the gamepad
- GIVEN a solo player in English who last used a gamepad, beside the crossed sticks
- WHEN they press A
- THEN the note shows the sticks' English line and "[A] Close"

#### Scenario: Every line fits
- GIVEN every sign in every island layout, in Spanish and in English
- WHEN each line is wrapped to the card
- THEN it takes at most 8 lines and no line is wider than the card's inner width

#### Scenario: Only the reader sees it
- GIVEN a host and a client, the host beside a wall slogan
- WHEN the host presses E
- THEN the host's HUD shows the note and the client's HUD shows no note
