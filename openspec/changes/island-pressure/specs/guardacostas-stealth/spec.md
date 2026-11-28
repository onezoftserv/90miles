## ADDED Requirements

### Requirement: Launch in view
A route marked as seen at launch (the raft) SHALL be seen when it starts while one of the island's patrol boats is out and sight works. In a phase when that boat's searchlight is off (dawn, day, dusk) it always sees it: by day the guard sees the whole sea. In a searchlight phase (night) it sees it only while its light covers the starter. A squall (patrols in port), a weather that blinds sight, or an island with no patrol hides it. Solo the same. (Adds to docs/GAME_DESIGN.md §9.)

#### Scenario: Solo by day
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather, its one patrol boat away beyond the horizon
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is seen

#### Scenario: Solo at night, out of the light
- **GIVEN** a 1-player run, offline, on the sandbar at 22:00 in calm weather, its patrol boat on its lap with the searchlight not on the player
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is not seen and the raft route starts

#### Scenario: Solo at night, in the light
- **GIVEN** the same run at 22:00 with the searchlight's cone on the player at the raft
- **WHEN** the player asks to launch
- **THEN** the launch is seen

#### Scenario: Solo in a squall
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 during a squall, its patrol boat in port
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is not seen and the raft route starts into the squall

#### Scenario: A swim is not a launch
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather, a player at energy 100 carrying binoculars
- **WHEN** they start binoculars-and-swim
- **THEN** the route starts, since a swim is not marked as seen at launch and the water rule still applies to the swimmer

### Requirement: A seen launch is a spot
A launch that is seen SHALL NOT start: nothing is spent, the vessel stays on the beach and no rider leaves. The boat that saw it raises an alert on land on the starter, cause `launch`, as for any spot of a player on land: it lands its squad when it has one and none is ashore, otherwise it locks on or searches. When several boats see it, the first by member index raises it. With exactly 1 player, the shore squad hunts that player, and a capture follows "Capture outcome".

#### Scenario: Solo spotted at launch
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather with a built raft at 100 and no squad ashore
- **WHEN** the player asks to launch
- **THEN** the raft stays at 100 on the beach, the player stays on the island, and the patrol boat docks and lands its squad, whose search starts at the player's cell

#### Scenario: Co-op party spotted
- **GIVEN** a 2-player run on the sandbar by day with a built raft and both players beside it
- **WHEN** the client asks to launch
- **THEN** neither player leaves, the alert names the client's player, and both peers see the boat dock
