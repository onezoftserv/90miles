# art-pass Specification

## Purpose
How 90 Millas is drawn in art direction C ("GBA tropic"): tracked, licensed and credited art on one master palette, terrain tile layers over a scrolling sea, player, creature, item and structure art driven by data and by state the host already replicates, readable at 640×360, and never able to change the simulation.

## Requirements

### Requirement: Tracked art with its licence
Every image the game draws SHALL come from a tracked folder under `game/assets/art/` holding a `License.txt` with one block per source, each with a licence line and a source line: a pack's block also names the pack and its author, and its source is the pack's page (not a licence deed); an own-work block's source is 90 Millas. Only files the game uses are copied there: each is referred to by a scene, a resource or the credits. Solo, offline, the game draws the same art.

#### Scenario: Licence beside every copy
- **GIVEN** the tracked art folders
- **WHEN** the art check walks `game/assets/art/`
- **THEN** every folder holding a PNG has a `License.txt` whose every block has a licence line and a source line (a pack page, or 90 Millas for own work), and every PNG is referred to by at least one scene or resource

#### Scenario: A copy without its licence
- **GIVEN** a PNG copied into a tracked art folder that has no `License.txt`
- **WHEN** the art check runs
- **THEN** it fails and names the folder

#### Scenario: A licence deed is not a source
- **GIVEN** a `License.txt` block whose only address is the CC0 deed `http://creativecommons.org/publicdomain/zero/1.0/`
- **WHEN** the art check runs
- **THEN** it fails and names the folder and the block's pack

### Requirement: Credits list every pack used
`game/assets/CREDITS.md` and the game's credits data SHALL list every pack whose files are tracked, with pack, author, licence, source and whether the files were modified. Each CC-BY pack SHALL carry its required wording: "DawnLike" by DragonDePlatino with the palette by DawnBringer; "Tiny, Tiny Heroes - Animals" by Kacper Woźniak (thkaspar); "Kyrise's Free 16x16 RPG Icon Pack" © 2018 by Kyrise.

#### Scenario: Every CC-BY pack credited
- **GIVEN** tracked files from DawnLike, Tiny, Tiny Heroes - Animals and Kyrise's icons
- **WHEN** the credits check compares the `License.txt` files with the credits data and `CREDITS.md`
- **THEN** each of the three has an entry in both with its author, "CC BY 4.0" and its source page, and the check passes

#### Scenario: A CC-BY pack without its credit
- **GIVEN** a tracked folder whose `License.txt` says CC BY and no credits entry for that pack
- **WHEN** the credits check runs
- **THEN** it fails and names the pack

### Requirement: Credits screen
The title screen SHALL offer *Créditos*, a screen that shows every credits entry in Spanish, the CC-BY entries first, then the CC0 packs and the OFL fonts, each CC-BY entry with its author, "CC BY 4.0", the licence's address (`https://creativecommons.org/licenses/by/4.0/`) and its source page, readable at 640×360 in the project font, scrollable when longer than the screen, and returning to the title on back or Esc. It needs no network: a solo player, offline, reaches it from the title.

#### Scenario: A solo player reads the credits
- **GIVEN** the title screen, offline, with no session
- **WHEN** the player presses *Créditos*
- **THEN** the screen lists DawnLike (DragonDePlatino, paleta de DawnBringer), Tiny, Tiny Heroes - Animals (Kacper Woźniak) and Kyrise's icons, each with "CC BY 4.0", the licence's address and its source page, above the CC0 packs, no network port is opened, and Esc returns to the title

### Requirement: Re-fetchable packs
`tools/fetch_assets.py` SHALL know every downloaded art pack (the nine in `docs/ASSETS.md`, tracked or not): its page, licence wording, folder under `game/assets/` and archive type. On a fresh checkout it fetches each pack it can download without a login, writes the pack's `License.txt` with the source and the date read, and for a pack it cannot fetch (a click-through page, or a RAR without 7-Zip) prints the page and the folder to unpack into.

#### Scenario: Fresh checkout
- **GIVEN** a checkout with none of the downloaded packs
- **WHEN** the fetch script runs
- **THEN** each pack it can download lands in its folder with a `License.txt`, each other pack prints its page and target folder, and the script exits non-zero while any manual step remains

#### Scenario: Listing the packs
- **WHEN** the fetch script runs with `--list`
- **THEN** it prints all nine downloaded packs, each with its folder and licence, and downloads nothing

### Requirement: Master palette
Every tracked world image (all of `game/assets/art/` but the UI 9-slices in `art/ui/`, which keep their colours until a UI pass) SHALL use only master palette colours (at most 64: DawnBringer's 32-colour palette plus the tropical, sea and skin ramps the packs need), each pixel fully opaque or fully transparent. Only drop shadows and shade decals, kept in `shadows/` and `decals/`, may use the darkest colour at partial alpha; pack art loses its baked half-transparent shadows.

#### Scenario: Off-palette pixel
- **GIVEN** a tracked creature frame with one pixel not in the master palette
- **WHEN** the palette check runs
- **THEN** it fails and names the file and the pixel

#### Scenario: Partial alpha outside shadows
- **GIVEN** a tracked item icon with a half-transparent pixel
- **WHEN** the palette check runs
- **THEN** it fails, while the same alpha in a file under `shadows/` or `decals/` passes

### Requirement: Outlines
Every character, creature, item and structure frame SHALL have a closed 1 px outline: each opaque pixel that touches a transparent pixel on one of its four sides is one of the palette's outline colours. A piece gets it from the pipeline's rim step, not by hand: the step recolours the piece's own edge pixels to outline colours, and grows a 1 px ring only round a piece with no edge ring of its own. Terrain tiles, water, foam, shadows and decals have no outline.

#### Scenario: A hand-made icon without its rim
- **GIVEN** a new item icon whose edge pixels are its fill colour
- **WHEN** the outline check runs
- **THEN** it fails and names the file, and after the rim step it passes

#### Scenario: A piece with its own edge keeps its size
- **GIVEN** a MetroCity frame whose edge ring is a light skin colour
- **WHEN** the rim step runs
- **THEN** the edge pixels become outline colours and the figure's bounding box does not grow

#### Scenario: A layered look is outlined as composed
- **GIVEN** a solo player's look whose hair part, alone, has open edges where the body covers it
- **WHEN** the outline check runs on the composed frames of that look
- **THEN** every composed frame has a closed outline and the check passes

### Requirement: Pixel-exact import
Every tracked image SHALL import lossless and without mipmaps and be drawn with nearest filtering at a whole-number scale, so each art pixel covers a whole number of screen pixels at 640×360 with the *Nítido* pixel filter.

#### Scenario: A lossy import
- **GIVEN** a tracked PNG whose import uses lossy compression or mipmaps
- **WHEN** the import check runs
- **THEN** it fails and names the file

### Requirement: Terrain tile layers
The island SHALL draw its terrain as tile layers built from its terrain grid, for every layout (the sandbar, the coast cay), giving each cell the same tile, variant and foam phase offset on every peer. Every land terrain kind SHALL have a tile, and every water kind (deep, shallows, brackish) a step of the sea's depth mask, so no cell shows a fallback colour. Drawing reads the grid, never writes it and blocks nothing. Solo, offline, the island looks as it does for a host.

#### Scenario: Host and client draw the same island
- **GIVEN** a host and one client on the sandbar
- **WHEN** both build the island's tile layers
- **THEN** every cell has the same source, tile, variant and foam phase offset on both

#### Scenario: Every terrain kind has a tile
- **GIVEN** a grid holding one cell of each of the 15 terrain kinds
- **WHEN** its tile layers and its sea mask are built
- **THEN** each of the 12 land cells gets a tile from the terrain art data, each of the 3 water cells its own step of the depth mask, and none is drawn in a fallback colour

#### Scenario: Tiles never block
- **GIVEN** the sandbar and the coast cay built for a solo player
- **WHEN** their tile layers are inspected
- **THEN** every tile set has no physics, navigation or occlusion layer, and the player walks across land tile edges exactly as before

### Requirement: Land edges
A land layer's tile SHALL be picked from the state of its cell's four corners, a corner counting as land when all four cells that share it are land, so straight shores, outer and inner corners, diagonal touches and a lone land cell all join without gaps. A land tile's water side is transparent over the sea, with no water or foam of its own. Each layer counts its own kinds and those of the layers on it as land: sand every land kind, dune both dune and scrub, brush scrub only.

#### Scenario: Inner corner
- **GIVEN** a land cell whose only water neighbour is to its north-west
- **WHEN** its tile is picked
- **THEN** it gets the inner-corner tile with water at its north-west corner

#### Scenario: Lone land cell
- **GIVEN** a land cell with water on all eight sides
- **WHEN** its tile is picked
- **THEN** it gets the islet tile, land inside the cell and water at all four corners

#### Scenario: Scrub inside a dune
- **GIVEN** a scrub cell whose eight neighbours are all dune
- **WHEN** its dune and brush tiles are picked
- **THEN** the dune layer gives it the full tile and the brush layer the islet tile

#### Scenario: No water in land tiles
- **GIVEN** every tile of the sand, dune and brush corner sets
- **WHEN** the art check reads their pixels
- **THEN** none holds an opaque colour of the sea or foam ramps

### Requirement: Scrolling sea
Water cells SHALL show one moving sea under the land layers: a seamless water texture drifting at a constant speed, with shallows drawn a palette step lighter than deep water and brackish water in a step of its own, cell by cell, every colour on the master palette. The sea's motion comes from its own clock and never from simulation state.

#### Scenario: Shallows read lighter than deep water
- **GIVEN** a shallows cell beside a deep cell
- **WHEN** the sea is drawn
- **THEN** the shallows cell's colours are the lighter step and the deep cell's the darker one, both from the master palette

#### Scenario: The sea moves on its own
- **GIVEN** a solo game on the sandbar with the player standing still
- **WHEN** two frames are drawn a second apart
- **THEN** the water texture has moved and no cell has changed its terrain

### Requirement: Shoreline overlay
Every shore cell, a land cell whose sand tile has at least one water corner, SHALL get an animated foam overlay picked by the same corner state and drawn on the line where its sand tile meets the sea, so each shore has exactly one foam line and it touches the sand. Water cells get no foam. The foam cycles through 8 frames, each cell starting at its own frame, so the shore never pulses all at once.

#### Scenario: Edges and corners
- **GIVEN** three land cells: one with water only on its three southern neighbours, one with water only at its south-east diagonal, and one with land only to its north, north-west and west
- **WHEN** the shoreline overlay is built
- **THEN** the first gets a straight foam edge on its south side, the second a concave foam corner at its south-east, the third a convex foam corner facing south-east, and no water cell gets foam

#### Scenario: Foam meets the sand
- **GIVEN** the straight sand edge tile and the straight foam edge on the same cell
- **WHEN** they are drawn
- **THEN** the foam starts on the row where the sand ends, with no gap and no second foam line

### Requirement: Tide pools and contact shade
Tide pools SHALL be drawn as rock-pool tiles on their cells, which the sand layer and the shoreline count as land, so a pool gets no foam ring; and the ground at the foot of each palm, the workbench, the raft site and a layout's shaded cells (under the sandbar's lean-to, round the coast cay's watch post) SHALL get a soft shade decal, so tall things sit on the ground. Decals never block or change movement. A solo player sees the same pools and shade.

#### Scenario: Pools and shade on the sandbar
- **GIVEN** the sandbar's three tide pools and six palms
- **WHEN** the island is drawn
- **THEN** each pool cell shows a rock-pool tile and each palm base has a shade decal under it

### Requirement: Seeded cosmetic variants
Decorative variants (sand speckles, shell tufts, foam starting frames) SHALL be chosen from a hash of the island layout's id and the cell, never from a random generator the simulation uses, so every peer and every rebuild of the same layout shows the same variants and drawing never shifts a simulation roll.

#### Scenario: Same layout, same variants
- **GIVEN** the sandbar built twice in one process and once on a client
- **WHEN** the variants are compared
- **THEN** every cell has the same variant all three times, and the creature spawner's next roll is the same as with no art built

### Requirement: Player frames and anchor
A player SHALL be drawn from 32×32 frames holding a figure about 16 px wide and 28 px tall, centred on the body's position, with every frame placed on one feet line (the bottom edge of the standing frame's lowest opaque row) 4 px below it, so the walk keeps its bob and the head rises about one tile into the row above. The body's collision shape and position rules do not change. Every peer draws every player this way, and a solo player is drawn the same.

#### Scenario: A solo player standing
- **GIVEN** a solo player standing still at (100, 100)
- **WHEN** their body is drawn
- **THEN** the frame is centred on x 100, its lowest opaque row ends at y 104, every other frame of the sheet is placed at the same offset, and the collision shape is still the 6 px circle at (100, 100)

### Requirement: Player facing
A player SHALL face down, up or sideways (the side frames mirrored for left), chosen on each peer, the host included, from the change of the drawn position over a short window: the larger of the horizontal and vertical motion wins, a tie faces sideways, and a body slower than a small dead zone keeps its last facing. Facing is never sent over the network. A solo player faces where they move.

#### Scenario: Mostly up
- **GIVEN** a solo player moving 1 tile/s right and 3 tiles/s up
- **WHEN** their body is drawn
- **THEN** they face up

#### Scenario: A teammate stops
- **GIVEN** a client drawing a teammate who walked left and then stopped
- **WHEN** the teammate stands still
- **THEN** the client keeps drawing them facing left, with the side frames mirrored

#### Scenario: A client's intents arrive in bursts
- **GIVEN** a host drawing a client's player whose intents arrive in bursts with gaps of up to 100 ms
- **WHEN** the player walks steadily right
- **THEN** the host draws them facing right throughout, without turning during the gaps

### Requirement: Player poses
A player SHALL be drawn in the pose for the state every peer already receives: idle, walk (6 frames), run (the walk frames faster), crouch (also used while crawling), swim and float, dive, downed, dragged (the downed frames, facing the drag) and dead. Every peer picks the same pose from the host's movement, stealth and downed states, and the owning client from its predicted state. A solo player sees their own poses.

#### Scenario: Poses follow the replicated state
- **GIVEN** a host and one client, the client's player swimming
- **WHEN** the client's player dives, surfaces, crouches on the beach and is then downed
- **THEN** both peers draw it in the dive, swim, crouch and downed poses in that order

#### Scenario: Dead is not downed
- **GIVEN** a solo player whose last stand ends in death
- **WHEN** their body is drawn
- **THEN** it shows the dead pose, which has no breathing frame, not the downed pose

### Requirement: Crouch pose
While crouching, a player SHALL be drawn in the crouch pose at full width with the feet where they were, and the hidden mark sits just above the crouch pose's head anchor, or above the name tag while it shows ("Head anchor"). Teammates see the same pose. A solo player sees their own crouch pose.

#### Scenario: A solo player crouches in brush
- **GIVEN** a solo player standing in brush
- **WHEN** they crouch until hidden
- **THEN** the crouch frames are drawn at their full 32×32 size with the feet line unchanged, and the hidden mark sits just above the crouch head anchor

### Requirement: Swimmers at the water line
A swimming or floating player SHALL be drawn sunk so the water line lies on the feet line, with the rows above it at full opacity, the rows below fading into the sea, a 1 px light ripple along the line and no drop shadow; a diving player SHALL show only a small ripple ring where they are. A solo swimmer looks the same.

#### Scenario: Swim and dive
- **GIVEN** a solo player swimming in deep water
- **WHEN** they swim, then dive
- **THEN** while swimming only their upper body is opaque, a ripple marks the line and no shadow is drawn; while diving only a ripple ring is drawn

### Requirement: Layered player look
The player SHALL be drawn from layers on one frame grid, back to front: body (its skin-tone row), outfit, hair and one signature item, all from a `PlayerLookData` resource of part ids, so a new hair, outfit or item is data and never a script edit. A part SHALL have a frame for every pose it shows in, or it is not offered. This pass ships four looks, one per look slot, picked by the slot alone on every peer; a solo player draws slot 0's look.

#### Scenario: A look built from parts
- **GIVEN** a solo offline game whose look is skin row 2, hair 0, the default outfit and no item
- **WHEN** the player walks, crouches, swims and is downed
- **THEN** every drawn frame stacks those layers with matching poses, and changing the look's hair id in data changes only the hair layer

#### Scenario: Four slots, four looks
- **GIVEN** a host and three clients in look slots 0 to 3
- **WHEN** each peer draws the four players
- **THEN** slots 0 and 2 show the man's body and slots 1 and 3 the woman's, the four hairs differ, every peer draws a given slot with the same parts, and no look data beyond the slot is sent

### Requirement: Player look slots
When a player body spawns, the host SHALL give it the lowest look slot (0–3) that no other body holds and send it with the spawn, so every peer and every late joiner draws the same slot; if all four are held (a dropped body still waiting out its 90 s), it takes the lowest slot a dropped body holds. A rejoiner who reclaims their body keeps its slot; a removed player's slot becomes free. A solo player is slot 0. The slot changes only drawing.

#### Scenario: Join, removal and a new joiner
- **GIVEN** a host in slot 0 and two clients who joined in that order and got slots 1 and 2
- **WHEN** the first client is removed and a third client joins
- **THEN** the third client gets the freed slot 1, and the second client keeps slot 2

#### Scenario: A joiner while a dropped body waits
- **GIVEN** four players in slots 0 to 3
- **WHEN** the client in slot 2 drops and a new client joins within 90 s
- **THEN** the new client gets slot 2 while the dropped body is still drawn in slot 2, and no other body changes slot

#### Scenario: A rejoin keeps the slot
- **GIVEN** a client in slot 1 who drops and rejoins within the downed window
- **WHEN** they reclaim their body
- **THEN** it is still drawn in slot 1 on every peer

#### Scenario: Solo
- **WHEN** a solo player starts a run offline
- **THEN** their body is slot 0

### Requirement: Clothing colours
Each look slot SHALL recolour only the clothing ramp of the player frames to its own ramp of the master palette; skin, hair and outlines keep their colours. The four slots' mid tones SHALL differ in hue and in brightness (a contrast ratio of at least 1.3:1 between any two) so teammates read apart with red-green colour blindness. The recolour keeps the day and night tint and holds while swimming. A solo player wears slot 0's colours (azul).

#### Scenario: Night tint still applies
- **GIVEN** a solo player in slot 0 at night
- **WHEN** their body is drawn
- **THEN** its clothing shows slot 0's ramp darkened by the same night tint as the sand around them

#### Scenario: A swimmer keeps its colours
- **GIVEN** a solo player in slot 0 swimming
- **WHEN** their body is drawn
- **THEN** the clothing above the water line shows slot 0's ramp, never the key ramp

#### Scenario: Four slots read apart
- **WHEN** the four slot ramps are compared
- **THEN** every pair of mid tones differs in hue and has a contrast ratio of at least 1.3:1

### Requirement: Head anchor
Each player pose SHALL have a head anchor, the point just above the top of the head. The teammate name tag SHALL sit on it, and the hidden mark, the interact prompt and the quick-chat speech bubble over a player stack upward from just above it, or from above the name tag while it shows, in that order, so none overlaps another and all follow the head as it crouches, swims, dives or lies downed. A solo player has no name tag and no quick chat; their own marks use the same anchor.

#### Scenario: The tag follows a crouch into brush
- **GIVEN** a client drawing a hurt teammate standing on brush, so the name tag shows on the standing anchor
- **WHEN** the teammate crouches until hidden
- **THEN** the name tag moves down to the crouch anchor and the hidden mark stays just above the tag

#### Scenario: A solo player's mark
- **GIVEN** a solo player crouching in brush until hidden
- **WHEN** the HUD draws their mark
- **THEN** it sits just above the crouch anchor and no name tag is drawn

#### Scenario: The prompt over a downed teammate
- **GIVEN** a co-op player within reach of a downed teammate whose name tag shows
- **WHEN** the interact prompt is drawn
- **THEN** the tag sits on the teammate's downed head anchor and the prompt just above the tag, overlapping it nowhere

### Requirement: Creature frames from data
A creature SHALL be drawn from its data's sprite frames, playing the animation named after its current behaviour state in lower case (such as `circle`, `swoop` or `pinch`), else `move` while it moves, else `idle`; side-on frames are mirrored while it faces left. A one-shot in the art data may show a state left within a tick. A new creature whose frames are named after its states is drawn with no script edited. Clients draw from the synced state and facing.

#### Scenario: State names pick the animation
- **GIVEN** a reef shark whose frames have `patrol`, `circle`, `strike` and `move` and no `retreat`, and whose art data plays `strike` once on entering `retreat`
- **WHEN** it circles, strikes and then retreats while moving
- **THEN** it plays `circle`, then `strike` once as it turns away, then `move`

#### Scenario: A new creature needs no script
- **GIVEN** a valid creature file `tiburon_prueba` with behaviour `patrol_circle_strike` and frames named `patrol` and `circle`
- **WHEN** it is spawned on the host and drawn on a client
- **THEN** both peers play `patrol` and then `circle` with no script added or edited

### Requirement: Creature motion on every peer
A creature SHALL count as moving while its drawn position changed within the last 0.15 s, longer than the 0.1 s between the creature positions a client receives, so a moving creature plays one steady animation on the host and on clients alike. A solo player sees the same.

#### Scenario: A client's crab scuttles steadily
- **GIVEN** a client receiving a walking crab's position 10 times a second
- **WHEN** it draws 60 frames a second for 1 s
- **THEN** the crab plays `move` on every frame, and `idle` once 0.15 s pass with no new position

### Requirement: Facing variants for creatures
When a creature's frames have facing variants of an animation (`<name>_down`, `<name>_up`, `<name>_side`), the variant for its synced facing SHALL play, the larger of the horizontal and vertical facing winning; side variants are mirrored while it faces left. Frames without variants play as they are.

#### Scenario: A gull flying north
- **GIVEN** a test creature with the seagull's behaviour whose frames have `swoop_down`, `swoop_up` and `swoop_side`
- **WHEN** it swoops facing mostly up
- **THEN** it plays `swoop_up`, while the shipped seagull, which has only `idle_*` and `move_*`, plays `move_up`

### Requirement: The sandbar's creatures
The reef shark SHALL be drawn as a dorsal fin above the surface over a dark body cut at the water line, the crossing's passing shark too; the land crab as a side-on crab that scuttles and raises its claws when it steals or pinches; the seagull standing in its nest palm's crown while perched, and flying, with its shadow on the ground below it, while it swoops, flees or returns. The same holds with exactly 1 player.

#### Scenario: A solo player meets all three
- **GIVEN** a solo sandbar run with a swimmer near the shark, a crab at night and a gull by day
- **WHEN** the shark circles, the crab pinches and the gull swoops
- **THEN** the shark shows only its fin and a dark shape under the water, the crab raises its claws, and the gull flies with its shadow below it on the ground

#### Scenario: A perched gull sits in the crown
- **GIVEN** a host and a client, a gull perched on its nest palm
- **WHEN** both draw it
- **THEN** on both peers it stands on the crown's nest point, drawn over the crown, with no shadow of its own on the sand

#### Scenario: The crossing's shark
- **GIVEN** a solo raft crossing whose shark pass comes
- **WHEN** the shark passes beside the raft
- **THEN** it is drawn as its fin over the crossing sea, playing the same animation on the host and on any client

### Requirement: Item icons
Every item SHALL have a 16×16 icon with the item inside the 14×14 box one pixel in from each edge, and no two items' icons SHALL share a silhouette. The same icon is drawn on the ground, raised 3 px above its position (5 px for an item under 8 px tall) with a small shadow, and in the inventory strip. A pick-up that another capability conceals (secret-cay) draws no icon while concealed. A solo player sees the same icons.

#### Scenario: A coconut on the beach
- **GIVEN** a solo player near a coconut pick-up
- **WHEN** they look at it and then pick it up
- **THEN** the coconut icon is drawn raised above the pick-up's position (3 px, or 5 px if it is under 8 px tall) with a shadow, and then in the player's inventory strip slot

#### Scenario: Two items with one silhouette
- **GIVEN** two item icons whose opaque pixels are the same shape
- **WHEN** the icon check runs
- **THEN** it fails and names both items

#### Scenario: A concealed pick-up
- **GIVEN** a pick-up whose look is marked concealed
- **WHEN** it is drawn
- **THEN** neither its icon nor its shadow is drawn, and both return once the mark is cleared

### Requirement: Art coverage
Every item in the content folders SHALL have an icon, and every creature that is not a weather or crossing boss proxy SHALL have sprite frames with an `idle` animation or a full set of `idle_down`, `idle_up` and `idle_side`; content without its art fails the art check, named by file. Adding the art is part of adding the content and never needs a script edit.

#### Scenario: An item without an icon
- **GIVEN** a new valid item file with no icon
- **WHEN** the art check runs
- **THEN** it fails and names the file

#### Scenario: A boss proxy needs no frames
- **GIVEN** a weather boss proxy creature with no sprite frames
- **WHEN** the art check runs
- **THEN** it passes for that file

#### Scenario: Facing variants count as idle
- **GIVEN** the seagull, whose frames have `idle_down`, `idle_up` and `idle_side` and no plain `idle`
- **WHEN** the art check runs
- **THEN** it passes for that file, while a creature with only `idle_side` fails

### Requirement: Palms
A palm SHALL be drawn with its trunk base at its position and its crown rising over the rows above it, showing as many coconuts as it holds up to three, and with a gull nest in its crown when the island layout lists it as a nest palm. The coconuts shown on a peer follow the count that peer holds. A solo player sees each climb take a coconut off the palm.

#### Scenario: A solo climb
- **GIVEN** a solo player under a nest palm holding 2 coconuts
- **WHEN** they climb it once
- **THEN** the palm shows its nest and 1 coconut

### Requirement: Lean-to over the hut
The sandbar's hut SHALL be drawn as a palm-frond lean-to standing on the hut's back edge, its posts and roof rising over the row north of it, so everything on the hut's cells, its pick-ups and whoever stands there, draws in front of it and only what is north of the hut goes behind the roof. Which layouts get a lean-to is art data; the coast cay's watch post keeps only its shade. A solo player in the hut stays visible.

#### Scenario: Standing in the hut
- **GIVEN** a solo player standing on the hut's back row beside its tarp and driftwood
- **WHEN** the hut is drawn
- **THEN** the player, the tarp and both driftwood are drawn in front of the lean-to, on the shade decal

#### Scenario: Behind the roof
- **GIVEN** a solo player one tile north of the hut
- **WHEN** the hut is drawn
- **THEN** the lean-to's roof is drawn over them

### Requirement: Camp structures
The workbench, the fire, the rain catcher and the island signs SHALL each be drawn from their own sprites, their look following the state that peer holds: the fire a flickering flame while lit and embers once out; the rain catcher with water showing while it holds at least one cup. The lagoon's drink spots draw nothing of their own: the brackish water shows where to drink. A solo player sees the fire they built light up.

#### Scenario: A solo fire
- **GIVEN** a solo player who finishes building a fire
- **WHEN** it lights and later burns out
- **THEN** it shows the flickering flame and then the embers

### Requirement: Raft site and raft
The raft build site SHALL show its stage: a staked outline while empty, the deposited materials once any are in, and a half-built frame from half its work; once built, the raft replaces it. The raft SHALL be one 64×32 sprite set used on the beach, a beached raft included, and as the crossing deck: whole above 66 integrity, worn from 66, breaking from 33; at 0 the deck sinks at once and no raft is drawn. With exactly 1 player the same stages show.

#### Scenario: A solo build
- **GIVEN** a solo player at the empty raft site
- **WHEN** they deposit every material, work half the build and then finish it
- **THEN** the site shows the outline, then the materials, then the half-built frame, and then the whole raft in its place

#### Scenario: Damage states
- **GIVEN** a raft on the crossing at integrity 100
- **WHEN** it drops to 60, to 30 and to 0
- **THEN** the deck shows worn, then breaking, and then no deck, because it sank

### Requirement: Crossing look
The crossing SHALL draw the same sea in its deep-water step, scrolling with the crossing's own scroll, under everything in the crossing; the raft deck by its integrity, above the sea and under every rider; and riders in the water cut at the water line. A client and a late joiner draw it from the crossing state they already receive. A solo crossing looks the same.

#### Scenario: A solo raft crossing
- **GIVEN** a solo player who launched the raft
- **WHEN** the crossing runs and a squall throws them in
- **THEN** the open sea scrolls with the crossing, the deck shows the raft at its integrity, and the player is drawn over the sea, cut at the water line beside it

#### Scenario: Riders and the shark over the sea and the deck
- **GIVEN** a host and a client in a raft crossing with one rider aboard, one thrown in and the shark passing that swimmer
- **WHEN** both draw the crossing
- **THEN** on both peers the rider aboard is drawn over the deck, and the swimmer and the shark over the sea

### Requirement: Draw order by foot position
Players, creatures, pick-ups, palms and structures SHALL be drawn in order of their foot position, lower on screen in front, without moving any node in the scene tree, while terrain, water, foam and decals stay beneath them. A palm crown or a lean-to roof therefore covers a player standing behind it and not one in front. A solo player is sorted the same.

#### Scenario: Behind and in front of a palm
- **GIVEN** a solo player one tile north of a palm
- **WHEN** they walk to one tile south of it
- **THEN** the crown is drawn over them at first and under them after, and no node changed its parent

### Requirement: Drop shadows
Every player, creature and pick-up on land or in the air SHALL have a soft dark ellipse at its feet, sized to it, drawn over the ground and under every actor; a flying creature's shadow lies on the ground below it, and swimmers, divers, the shark fin and a gull perched in a crown have none. A pick-up that another capability conceals (secret-cay) has no shadow while concealed. A solo player has a shadow.

#### Scenario: Shadows on the sandbar
- **GIVEN** a solo player on the beach, a crab and a flying gull
- **WHEN** they are drawn
- **THEN** each has a shadow under it on the sand, the gull's on the ground below its body, and a swimming player has none

### Requirement: Actors stand out from the ground
Every player, creature and item frame SHALL stand out from each ground it can be on. On land (sand, dune, brush) its closed outline does it: every outline colour SHALL reach a contrast ratio of at least 3:1 with each land ground's mean colour. On water (shallows, deep), where most outline colours do not, a swimmer's frames (counting their ripple) and the fin's SHALL reach 3:1 with the better of their outline ring and their mean colour. The threshold is art tuning data.

#### Scenario: An outline colour that blends in
- **GIVEN** an outline set holding a colour under 3:1 against the brush ground
- **WHEN** the palette check runs
- **THEN** it fails and names the colour and the ground

#### Scenario: A fin that blends in
- **GIVEN** a shark frame whose outline ring and mean colour both reach under 3:1 against deep water
- **WHEN** the contrast check runs
- **THEN** it fails and names the frame and the ground

### Requirement: Frame budget
No actor or structure animation SHALL have more than 6 unique frames per facing or play faster than 12 frames per second; a creature animation SHALL have at most 4 unique frames, and a character's frames at most 48 unique 32×32 frames in all. Longer holds repeat frames instead of drawing new ones. Terrain, sea and foam overlays, such as the 8-frame shoreline, are not actor animations and are exempt.

#### Scenario: Too many frames
- **GIVEN** a creature animation with 5 unique frames
- **WHEN** the frame-budget check runs
- **THEN** it fails and names the creature and the animation

### Requirement: Drawing never changes the simulation
Art SHALL only read state: no art node writes a synced or simulated value, art adds no replicated property (the player's synchronizer lists the same property paths with every art node present or freed), and a scripted host run on the sandbar gives the same positions, meters, inventories and creature states with the art present or stripped. A solo run is checked the same way.

#### Scenario: Same run with and without art
- **GIVEN** a solo sandbar run with fixed intents for 600 physics frames
- **WHEN** it runs once with every art node and once with them all removed
- **THEN** the players' positions, meters and inventories and every creature's position and state are equal at every frame, and the player's synchronizer lists the same property paths both times
