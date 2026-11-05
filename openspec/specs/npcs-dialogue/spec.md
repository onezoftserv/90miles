# npcs-dialogue

## Purpose
NPCs, companions, quests, found texts and the in-game dialogue UI. Content in `docs/CHARACTERS.md`.

## Requirements

### Requirement: NPC resource
Each NPC SHALL be a `.tres` with: id, name, sprite, spawn rules (chains, chance, min island), dialogue mode (`handwritten` | `ai`), profile path (for AI), quests, companion stats (if any), ending flags it sets.

#### Scenario: Minimum island
- GIVEN an NPC whose spawn rules set min island 3
- WHEN island 2 is generated
- THEN that NPC does not spawn

### Requirement: Dialogue UI
Dialogue SHALL show a portrait, the speaker name, text revealed at 40 chars/s with a skip, and 1–3 choices when offered. Voice clips play when available. Co-op: the player who talks drives; others see the text.

#### Scenario: Text reveal
- GIVEN a 120-character line
- WHEN the dialogue opens and the player does not skip
- THEN the full text is revealed after 3 s

### Requirement: Handwritten lines
Minor NPCs and all story beats SHALL read lines from `game/resources/dialogue/*.tres` keyed by NPC id, state and language (es/en).

#### Scenario: English line for a minor NPC
- GIVEN a minor NPC in a given state and the language set to en
- WHEN a player talks to them
- THEN the line comes from `game/resources/dialogue/*.tres` keyed by that NPC's id, that state and en

### Requirement: AI lines
Important NPCs SHALL request lines from `DialogueService` with a context object (island, weather, party, companions alive/dead, quests, run history, recent events). The service returns `{speaker, text, emotion}` or a handwritten fallback within 3 s.

#### Scenario: Offline
- GIVEN no backend reachable
- WHEN Ramón is talked to
- THEN a handwritten fallback line plays within 100 ms and the UI shows no error

### Requirement: Quests
Quests SHALL be data: steps with conditions (item in inventory, flag set, location reached) and rewards. Quest state is host-authoritative and shared by the party.

#### Scenario: Shared quest step
- GIVEN a quest step whose condition is reaching a location
- WHEN one player reaches that location
- THEN the host marks the step complete and every player in the party sees it complete

### Requirement: Companions
Rescued balseros SHALL follow the nearest player, have their own meters (simplified: thirst, health), a skill effect, a need, and a death that sets ending flags. They board routes with capacity and can be left behind (flag).

#### Scenario: Companion left behind
- GIVEN a rescued companion and a route whose capacity is full without them
- WHEN the route starts
- THEN the companion stays on the island and the left-behind flag is set

### Requirement: Found texts
Found texts SHALL be items that open a reading panel; important ones call `DialogueService` with mode `text`. Reading restores +10 morale once.

#### Scenario: Reading twice
- GIVEN a player with morale 50 and an unread found text
- WHEN they read it twice
- THEN their morale is 60

### Requirement: Ending flags
NPCs and companions SHALL set flags consumed by `endings-progression` (`ramon_photo`, `caridad_lamp`, `yunior_alive`, `companion_<id>_alive`, `rodriguez_deal`, `others_helped|robbed`).

#### Scenario: Caridad's lamp
- GIVEN Caridad's lamp was lit during the run
- WHEN `endings-progression` selects an ending
- THEN it reads the `caridad_lamp` flag as set
