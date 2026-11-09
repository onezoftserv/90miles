# crafting-inventory

## Purpose
Items, inventory, recipes, identification, durability and stashes. Study: Shattered Pixel Dungeon `items/` and alchemy; DCSS item data files.

## Requirements

### Requirement: Item resource
Each item SHALL be a `.tres` with: id, name (es/en), sprite, stack size, weight, tags (food, water, tool, material, shiny, keepsake, text), use effect, durability, identify group.

#### Scenario: Item loaded from data
- GIVEN an item `.tres` with id, name (es/en), sprite, stack size, weight, tags, use effect, durability and identify group
- WHEN the game loads it
- THEN the item exists in game with exactly those values

### Requirement: Inventory
Players SHALL have 12 slots and a weight limit (30); swimming with weight > 15 drains energy ×2 and drops a random heavy item at energy 0. A slot holds one item id and a count up to that item's stack size; items with more than 1 durability do not stack and each keeps its own uses. Each player's inventory lives on the host and is synced to every peer; clients never change it themselves. Inventories are per player, so a solo player carries everything they use.

#### Scenario: Swimming overloaded
- GIVEN a player carrying weight 20
- WHEN they swim until energy reaches 0
- THEN energy drained at ×2 the whole way and a random heavy item is dropped at energy 0

#### Scenario: Pick up a coconut into an empty inventory
- GIVEN a solo player with an empty inventory standing within 1 tile of a coconut on the ground
- WHEN they press interact
- THEN slot 0 holds 1 coco, the coconut is gone from the ground and the carried weight is the coconut's weight (0.5)

#### Scenario: Stacking and the weight limit
- GIVEN a player whose slots hold coconuts up to the stack size (5) in one slot
- WHEN they pick up one more coconut
- THEN it goes into the next empty slot; and when the pick-up would take carried weight above 30 or no slot can take it, the item stays on the ground

#### Scenario: Another peer's inventory is shown, not owned
- GIVEN a client whose player holds 2 driftwood on the host
- WHEN the client reads its inventory
- THEN it shows the host's 2 driftwood and has no way to change it

### Requirement: Recipes
Recipes SHALL be `.tres` with inputs, output, station (none, workbench, fire), time, and skill multiplier. Core recipes per `docs/GAME_DESIGN.md` §6. A craft needs every input in the crafter's own inventory and every tool capability carried by the crafter; it consumes the inputs (and one use of each required tool per tool wear) only when it completes. A fast tool, when carried, replaces the time with that item's tool time. No recipe needs a second player: a solo player can craft every recipe alone.

#### Scenario: Workbench recipe
- GIVEN a recipe `.tres` with station workbench
- WHEN a player holding its inputs crafts it at a workbench
- THEN after the recipe's time the inputs are consumed and the output is added

#### Scenario: Missing inputs
- GIVEN a player at a workbench missing one input of a workbench recipe
- WHEN they try to craft it
- THEN nothing starts and nothing is consumed

#### Scenario: A solo player crafts every recipe
- GIVEN one offline player holding the inputs and tools of every recipe in `game/resources/recipes/`
- WHEN they craft each one at its station or build site
- THEN every recipe completes with that one player

### Requirement: Identification
Unknown fruit SHALL appear as a generic name per identify group until eaten or named by an NPC/Médico; identification is party-wide and run-scoped.

#### Scenario: Manchineel
- GIVEN an unidentified "fruta verde" that is manchineel
- WHEN a non-Médico eats it
- THEN the item is identified for the party and the eater takes 50 damage over 60 s

### Requirement: Durability
Tools SHALL lose durability per use; at 0 they break. Rafts lose 25% integrity per crossing. Repair recipes restore.

#### Scenario: Raft after two crossings
- GIVEN a raft at full integrity
- WHEN it completes two crossings with no other damage
- THEN its integrity is 50%

### Requirement: Stashes
Items on the ground or in open containers SHALL be subject to crab and gull theft; sealed containers (lidded jug, cooler, buried bag) are safe.

#### Scenario: Sealed jug
- GIVEN food on the ground and food in a lidded jug
- WHEN crabs and gulls come to steal
- THEN they can take the food on the ground but not the food in the jug

### Requirement: Shared builds
Build sites (raft, still, rain catcher, fire) SHALL accept deposits from any player and show progress to all. A build site is placed by the first player who starts a build-site recipe; deposits move matching inputs from the depositor's inventory; work advances only while at least one player works it and its inputs are complete. One player can deposit everything and do all the work.

#### Scenario: Two players feed a still
- GIVEN a still build site
- WHEN two different players each deposit materials into it
- THEN both deposits count toward the build and every player sees the same progress

#### Scenario: One player builds a fire
- GIVEN a solo player holding 3 driftwood and 1 dry grass
- WHEN they place a fire build site, deposit everything and work it for the recipe's time (30 s)
- THEN the fire is built and lit, and 3 driftwood and 1 dry grass have left their inventory

### Requirement: Pick-up
Items on the ground SHALL be picked up through the player-movement interaction (nearest interactable within 1 tile, instant unless the item sets a hold time). The host applies the pick-up; if the inventory cannot take the item it stays on the ground. Items with pick-up disabled cannot be picked up. Pick-up effects of the item apply to the player who took it.

#### Scenario: Solo pick-up
- GIVEN one offline player next to driftwood on the ground
- WHEN they press interact
- THEN the driftwood is in their inventory

### Requirement: Using items
An item's use SHALL check every condition of that `ItemUseData`, apply its effects in order and, if it spends a use, take one use (removing the item at 0 uses and adding its remainder item). A failed condition stops the use without spending anything. A coconut gives thirst +15, hunger +5 and, as a meal, energy +10; a rain cup gives thirst +25. The use's `time_s` belongs to the caller (the UI holds the button); effects apply when the host receives the use.

#### Scenario: Opening a coconut needs a blade
- GIVEN a solo player holding a coconut and no item with the open-coconut capability
- WHEN they try to drink it
- THEN nothing happens and they still hold the coconut; with a knife they drink it, gain thirst +15 and hunger +5 and energy +10, the coconut is gone and the knife has one use less

#### Scenario: Drinking a rain cup
- GIVEN a player with thirst 50 holding a rain cup
- WHEN they drink it
- THEN thirst is 75 and the cup is gone

### Requirement: Fresh-water revives
Only fresh-water cups SHALL revive: coconut, rain cup, still cup and well cup. Seawater and rum never revive. A reviving cup used on a downed teammate within 1 tile, or by a solo player on themselves during a last stand, stands them up at the survival-meters revive health (30) and then applies its drink effects; used on someone who is standing it does nothing and spends nothing.

#### Scenario: Seawater does not revive
- GIVEN a downed teammate and a player holding a seawater cup and a rain cup
- WHEN the player tries the seawater cup on the teammate
- THEN the teammate stays downed; the rain cup revives them

#### Scenario: Solo last stand
- GIVEN a solo player in a last stand holding a rain cup
- WHEN they use it on themselves
- THEN they stand at 30 health

### Requirement: Workbench
A workbench (a flat rock or a wreck table placed by the level) SHALL be a station and an interactable: a player within 1 tile can craft any known workbench recipe whose inputs and tools they carry, or place the site of any known build-site recipe whose output is a structure. Crafting sets the crafting state for the hunger drain while it runs, and stops if the player leaves the bench's reach.

#### Scenario: Solo workbench craft
- GIVEN one offline player at a workbench holding a workbench recipe's inputs
- WHEN they craft it and stay for its time
- THEN the output is in their inventory

#### Scenario: Solo places a fire site at the bench
- **GIVEN** one offline player within 1 tile of a workbench, carrying nothing, standing on a free land cell that is not the bench's
- **WHEN** they choose the fire recipe there
- **THEN** an empty fire site lies on the land cell under them, ready for deposits

#### Scenario: A station that is not a workbench
- **GIVEN** a client within 1 tile of the raft site
- **WHEN** it asks to place a fire site naming the raft site as the station
- **THEN** nothing is placed and nothing changes

### Requirement: Fire
A fire SHALL be a structure built from its recipe (3 driftwood + 1 tinder; 30 s by friction, less with a carried fire-lighting tool). When built it lights: players within 5 tiles get the fire-lit morale bonus (+5), and while lit it counts as company for the night morale drain within 5 tiles. It burns 360 s (12 in-game hours), then goes out as embers that are no company; any player can put it out with a 2 s interaction.

#### Scenario: A lit fire keeps a solo player company
- GIVEN one offline player with morale 50 at night, 3 tiles from a fire they built
- WHEN 60 s pass
- THEN morale is still 50; after the fire is put out, 60 more seconds take morale to 45

#### Scenario: A fire burns out
- GIVEN a fire lit 360 s ago
- WHEN the next second passes
- THEN it is out and no longer counts as company

### Requirement: Water structures
A rain catcher SHALL yield rain cups while it rains (squall): 1 rain cup into the catcher after 30 s of continuous rain, at most once per squall, held there until a player takes it. A solar still SHALL yield 1 still cup per 12 in-game hours (360 s), which changes `docs/ITEMS.md` ("1 per 2 in-game hours"); the still itself is built by a later change. Rain is the weather named by the recipe's `produce_on_weather_id` (`squall`), read from the climate the sky writes.

#### Scenario: A rain cup fills during a squall
- GIVEN a built rain catcher and a solo player
- WHEN a squall has been falling on it for 30 s
- THEN the catcher holds 1 rain cup and the player can take it

### Requirement: Host-authoritative crafting
Pick-ups, item uses, deposits, crafts and putting out fires SHALL be requests a player sends to the host; the host checks the sender's own inventory, reach and the recipe, applies the result and syncs it. A client never changes an inventory, a build site or a fire itself. A solo player is their own host and nothing is sent over a network.

#### Scenario: A client's craft is applied by the host
- GIVEN a host and one client at a workbench holding a recipe's inputs
- WHEN the client asks to craft it
- THEN the host consumes the client's inputs and adds the output, and the client sees the same inventory

#### Scenario: A forged request does nothing
- GIVEN a client that asks to craft without the inputs, or to use a slot it has nothing in, on another player
- WHEN the host receives it
- THEN nothing changes

#### Scenario: A downed player cannot craft, deposit or use items
- GIVEN a downed co-op player holding a recipe's inputs and a rain cup, next to a workbench and a build site
- WHEN the host receives their request to craft, deposit or use an item
- THEN the host refuses it and nothing is consumed, while a teammate within reach can still revive them with a rain cup or a coconut and a knife
- AND a solo player in a last stand, who has no teammate, may drink a reviving cup they carry to stand up, but cannot craft, deposit or use any other item

### Requirement: Coast cay items as data
Nails (*clavos*), the mirror (*espejo*), aloe (*sábila*) and the lighter (*fosforera*) SHALL be item data files following `docs/ITEMS.md`: nails a material; the mirror a shiny tool with no use yet; aloe a medicine whose 1 s use cures sunburn and bleeding (on the user or an adjacent teammate); the lighter a tool with the fire-lighting capability and 20 uses that lights a fire in 1 s instead of 30 s and spends 1 use. All four pass the content check. Exactly 1 player can pick up and use them alone.

#### Scenario: A solo player lights a fire with the lighter
- GIVEN one offline player holding the lighter, 3 driftwood and dry grass beside a fire build site
- WHEN they work the site
- THEN there is no fire at 0.9 s, the fire burns after 1 s and the lighter has 19 uses left

#### Scenario: A solo player uses aloe
- GIVEN one offline player with sunburn and bleeding and an aloe leaf
- WHEN they use it
- THEN both statuses are gone and the leaf is used up

### Requirement: Delayed effects
An effect with a delay SHALL apply on the host that many seconds after its source fires, to the same player, counted in that player's own time: the clock stops while their meters do not tick (a rider waiting out of play), and a player who is gone from the session never takes it. A cure effect (a status removed) is interpreted like a meter change. Exactly 1 player takes delayed effects the same way.

#### Scenario: A delayed thirst loss
- GIVEN one offline player and an effect that lowers thirst by 5 after 30 s
- WHEN the effect fires
- THEN thirst is unchanged at 29.9 s and 5 lower at 30 s, once

#### Scenario: The delay waits while out of play
- GIVEN a player with such an effect pending who becomes a waiting rider for 25 s
- WHEN they are back in play
- THEN the effect lands after the rest of its 30 s, not before

### Requirement: Placing a build site
When a player places a build-site recipe at a workbench in their reach, the host SHALL put an empty site of that recipe on the free cell nearest the player within 1 tile whose terrain the recipe allows (any land when it lists none): not the bench's cell and not one holding a structure or a site. An island holds at most one unfinished site per recipe; a second request, or one with no free cell, changes nothing. A solo player places and builds sites alone.

#### Scenario: One unfinished fire
- **GIVEN** one offline player who placed a fire site and has not built it
- **WHEN** they ask the bench for a fire site again
- **THEN** no second site appears, and once the first fire is built they may place another

#### Scenario: A client's request names only the recipe and the bench
- **GIVEN** a client within 1 tile of the workbench
- **WHEN** it asks for a rain catcher site
- **THEN** the host places the site by the client's own player, at a cell the host picks; the request carries no position

### Requirement: Placed sites on every peer
A site placed at a workbench, its deposits of items and of tags, its progress and the structure it becomes SHALL reach every player in the session, and players who join later get the current state. The structure exists once on every peer and its build effects apply once, on the host. Solo the same.

#### Scenario: One fire, once
- **GIVEN** one offline player who deposits 3 driftwood and 1 dry grass into a fire site placed at the bench, with morale 50
- **WHEN** they work it for 30 s
- **THEN** exactly one fire stands where the site was, it is the only lit fire there, and morale rose by 5 once

#### Scenario: Tag deposits reach a client
- **GIVEN** a host and a client next to a fire site placed at the bench
- **WHEN** the host's player deposits 3 driftwood and 1 dry grass
- **THEN** the client's copy of the site has every input in

#### Scenario: A joiner sees a built fire
- **GIVEN** a host who placed and built a fire at the workbench
- **WHEN** a client joins the run
- **THEN** the client sees the fire where the host built it

#### Scenario: A joiner mid-build
- **GIVEN** a host who filled a fire site and worked it to 50 %
- **WHEN** a client joins the run
- **THEN** the client's copy of the site has every input in and progress 50 %
