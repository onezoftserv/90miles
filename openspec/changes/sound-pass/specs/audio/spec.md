## ADDED Requirements

### Requirement: Sounds are data
Every sound the game plays SHALL be listed by id in one sound bank content file, with its audio file, bus (Efectos or Ambiente), level, loop flag, random pitch spread and shortest repeat interval. The cue thresholds (motor swell, low thirst, thunder interval) SHALL live in the same file. Every id SHALL resolve to a tracked audio file, and every loop's file SHALL loop. Adding, replacing or retuning a sound SHALL edit only content data and the credits, never a script.

#### Scenario: Every id resolves
- **WHEN** the verification checks run
- **THEN** each of the fifteen ids resolves to a tracked audio file that loads:
  - `sea`, `wind`, `night` and `patrol_motor` (loops);
  - `pickup`, `hurt_hit`, `hurt_big`, `hurt_drain` and `use_done`;
  - `thirst_low`, `raft_hit`, `loudhailer`, `thunder`, `arrival` and `compass_rattle`.
- **AND** the four loops load as looping streams and the rest do not

#### Scenario: Swapping a sound is a data change
- **WHEN** a designer replaces the `raft_hit` file with a CC0 recording
- **THEN** only the sound bank entry, the new file and the credits change, and no script is edited

#### Scenario: A missing file fails the checks
- **GIVEN** a bank entry whose file does not exist
- **WHEN** the verification checks run
- **THEN** they fail and name the id

### Requirement: Playing a one-shot by id
The audio service SHALL play a one-shot sound by its id at its bank level, with its pitch shifted at random within its spread, and SHALL play repeated requests for one id inside its repeat interval once. An empty or unlisted id SHALL play nothing and SHALL NOT fail. The service SHALL report every sound it plays, so checks can read what was asked for without an audio device.

#### Scenario: Solo pinch plays the hit
- **GIVEN** a solo run, offline, with exactly 1 player at 100 health
- **WHEN** a land crab pinches the player for 5
- **THEN** `hurt_hit` is played once

#### Scenario: Unknown ids are silent
- **WHEN** something asks for the id `""` or `no_such_sound`
- **THEN** nothing plays and nothing fails

#### Scenario: A burst plays once
- **GIVEN** `pickup` with a repeat interval of 0.08 s
- **WHEN** it is asked for three times in the same frame
- **THEN** it plays once

### Requirement: Loops are set by level
The audio service SHALL set a loop to a level by its id. The loop starts when its level rises above silence, fades between levels over its bank fade time, and stops when set to silence.

#### Scenario: A loop fades in and out
- **GIVEN** the `night` loop is silent
- **WHEN** it is set to full, and later to silence
- **THEN** it rises to full over its fade time, then falls and stops

### Requirement: Own events are heard only by their player
A peer SHALL play these own-event cues for its own player only:
- `pickup`, `thirst_low` and `compass_rattle`;
- the hurt and use cues `hurt_hit`, `hurt_big`, `hurt_drain` and `use_done`, which follow the body whose meters the HUD shows (the teammate watched while dead).

Another player's own events SHALL NOT be heard. With exactly 1 player (solo, offline) the player hears all of their own events.

#### Scenario: A teammate's pick-up is not heard
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** Yuni picks up a coconut
- **THEN** Yuni's game plays `pickup` and Papo's does not

#### Scenario: A client's own hit
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** a crab pinches Papo
- **THEN** Papo's game plays `hurt_hit` and Yuni's does not

### Requirement: Pick-up cue
`pickup` SHALL play when the player's bag gains an item, whether picked up or crafted. Taking items out, spending a use, and the first state a peer sees of a bag SHALL play nothing.

#### Scenario: Solo pick-up
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player picks up a piece of driftwood
- **THEN** `pickup` plays once

#### Scenario: Joining with a full bag is silent
- **GIVEN** a client rejoining a run with 4 items in their bag
- **WHEN** the host's state arrives
- **THEN** `pickup` does not play

### Requirement: Low-thirst cue
`thirst_low` SHALL play when the player's thirst falls to 25 or less, the step at which the Sed bar starts to pulse. It SHALL play again only after thirst has risen above 30 and fallen to 25 again. A player first seen at 25 or less is not warned until thirst has been above 30.

#### Scenario: Solo low thirst warns once
- **GIVEN** a solo player, offline, whose thirst is 26
- **WHEN** thirst falls to 25, then to 10
- **THEN** `thirst_low` plays once
- **AND** after a coconut raises thirst to 40, a later fall to 25 plays it again

### Requirement: Compass rattle cue
`compass_rattle` SHALL play when the broken compass's needle rattles on the player's HUD.

#### Scenario: Solo needle rattles
- **GIVEN** a solo player, offline, carrying the broken compass
- **WHEN** they come within the needle's first band of a concealed item
- **THEN** `compass_rattle` plays once

### Requirement: World events are heard by every peer
Each peer SHALL play the world-event cues from the run state it already holds, whatever player caused them: `sea`, `wind`, `night`, `thunder`, `patrol_motor`, `loudhailer`, `raft_hit` and `arrival`. With exactly 1 player (solo, offline) they play the same way.

#### Scenario: A client hears the host's squall
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** a squall breaks on the host
- **THEN** both games play `thunder` and raise the `wind` loop

### Requirement: Ambience follows place, time and weather
- The `sea` loop SHALL play while a run is on screen, louder while the player rides a crossing.
- The `wind` loop SHALL play while the player rides a crossing and while a squall blows, louder in a squall.
- The `night` loop SHALL play during the night phase while the player is on an island.

#### Scenario: Solo night
- **GIVEN** a solo run, offline, on the first island
- **WHEN** the day phase turns to night
- **THEN** the `night` loop rises from silence and the `sea` loop keeps playing

#### Scenario: Solo crossing
- **GIVEN** a solo player on the first island by day
- **WHEN** they launch the raft and ride the crossing
- **THEN** the `sea` loop grows louder and the `wind` loop rises

### Requirement: Thunder
`thunder` SHALL play:
- quietly when a squall is warned;
- loudly when it breaks;
- again at random intervals from the bank while the squall lasts.

That randomness SHALL belong to the audio, never to the game.

#### Scenario: Solo squall
- **GIVEN** a solo run, offline
- **WHEN** a squall is warned and later breaks
- **THEN** `thunder` plays quietly at the warning and loudly at the break

### Requirement: Raft hit and arrival
- `raft_hit` SHALL play when the vessel the player rides in a crossing loses integrity, whether from a rock, debris, a shark or a squall. The first value a peer sees of a vessel plays nothing.
- `arrival` SHALL play when the player's crossing ends with the player alive.

#### Scenario: Solo raft hit
- **GIVEN** a solo player, offline, riding a raft in a crossing
- **WHEN** the raft strikes a rock and loses integrity
- **THEN** `raft_hit` plays once

#### Scenario: Solo arrival
- **GIVEN** a solo player, offline, riding a crossing
- **WHEN** the crossing ends with the player alive
- **THEN** `arrival` plays once

### Requirement: The patrol motor swells over the horizon warning
While a patrol boat is in its horizon warning (the seconds before its lap, 20 s in the coast patrol's data), every peer SHALL play the `patrol_motor` loop. It swells from the bank's low level at the warning's start to its high level at the warning's end. This is the sound half of the Fable review's H5 warning; the horizon band's mark is unchanged. With exactly 1 player (solo, offline) the warning sounds the same.

#### Scenario: Solo warning swells
- **GIVEN** a solo run, offline, with the coast patrol's boat entering its 20 s horizon warning
- **WHEN** 5 s and then 15 s of the warning have passed
- **THEN** the `patrol_motor` loop is louder at 15 s than at 5 s
- **AND** it reaches the bank's high level as the warning ends

#### Scenario: A client hears the warning
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** a patrol boat is 10 s into its horizon warning
- **THEN** both games play the `patrol_motor` loop at about the same level

### Requirement: The patrol motor follows the boat in sight
While a patrol boat is in sight (on its lap, alerting, searching or chasing), the `patrol_motor` loop's level SHALL follow the boat's distance from the player's view: loudest within the bank's near distance, fading to its far level at the far distance. A boat that is away or docked SHALL be silent. With several boats, the loudest sets the level.

#### Scenario: The boat leaves
- **GIVEN** a solo run with a patrol boat whose lap ends
- **WHEN** the boat goes away
- **THEN** the `patrol_motor` loop fades to silence

### Requirement: Loudhailer
Each time a patrol boat calls out (each new loudhailer line shown over it), every peer SHALL play `loudhailer` once. The first state a peer sees of a boat plays nothing.

#### Scenario: Solo alert
- **GIVEN** a solo player, offline, spotted by a patrol boat's searchlight
- **WHEN** the boat calls out its alert
- **THEN** `loudhailer` plays once

### Requirement: Audio never changes the simulation
Sound SHALL be client-side output only. Choosing, playing, muting or failing to play a sound SHALL NOT change any simulated state: positions, meters, inventories, creature brains, the weather or the game's random rolls. Sound SHALL add no synced property and no remote call. A solo run with sound SHALL reach the same state as the same run without it.

#### Scenario: Same run with and without sound
- **GIVEN** two identical solo runs, offline, with exactly 1 player, one with the run's sound cues attached and one without
- **WHEN** both run the same 600 frames of input, through a pick-up, a crab pinch and a patrol warning
- **THEN** both end in the same simulated state

### Requirement: Loops end with the run
Every loop SHALL stop when its run ends, however it ends: death, the run summary, abandoning the run, or the host being lost. In this pass no sound SHALL play on the title, lobby, credits or summary screens.

#### Scenario: Solo death silences the sea
- **GIVEN** a solo run, offline, at night with the `sea` and `night` loops playing
- **WHEN** the player dies and the run summary shows
- **THEN** no loop is playing

### Requirement: Volume level
Each install SHALL keep a volume level that scales every sound. It lasts across launches and is never synced to other players. A malformed stored value SHALL fall back to the default. Setting the level to 0 silences the game and changes nothing else. With exactly 1 player (solo, offline) it applies the same way.

#### Scenario: Default level on a fresh install
- **GIVEN** a fresh install with no settings file
- **WHEN** the game starts
- **THEN** the volume is at its default level

#### Scenario: The level is kept
- **GIVEN** a player who sets the volume to 30 %
- **WHEN** they quit and launch the game again
- **THEN** the volume is 30 %

### Requirement: Generated sounds are reproducible and credited
Every generated sound file SHALL come from the repository's own sound generator and its stored parameters, and running the generator again SHALL rebuild the same files. Every shipped sound file SHALL be listed with its origin in the asset credits and in its folder's licence file.

#### Scenario: Rebuilding the sounds
- **WHEN** the generator runs on the stored parameters
- **THEN** it writes the same twelve generated files, byte for byte on the machine that wrote them and within one step of the last bit on another
- **AND** it leaves the three recordings untouched

#### Scenario: Every file is credited
- **WHEN** the verification checks run
- **THEN** every audio file under the game's audio folders appears in its folder's licence file and in the asset credits

### Requirement: Approved recordings
A sound from outside the repository SHALL be added only after the owner has approved that file. Its author, licence and source page SHALL be recorded in its folder's licence file and in the asset credits, no own-work entry SHALL claim it, and the generator SHALL never write it. In this pass `sea`, `wind` and `thunder` are approved CC0 recordings (owner Q2 B), and the other twelve sounds are generated.

#### Scenario: A recording is credited to its author
- **GIVEN** `thunder` is an approved CC0 recording
- **WHEN** the verification checks run
- **THEN** its folder's licence file names its author, its CC0 licence and its source page
- **AND** no own-work entry claims it
