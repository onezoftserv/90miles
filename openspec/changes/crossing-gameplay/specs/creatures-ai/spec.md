# Spec Delta

## MODIFIED Requirements

### Requirement: Crossing reef shark
The crossing's shark pass SHALL be resolved by a reef shark from `reef_shark.tres` through the `CrossingThreats` hook: it appears at the pass's warning, 5 s before the strike, and circles 1 tile off the side the pass names (crossing "Shooing the shark"). At the strike, unless a rider shooed it, it applies the crossing's choice (a swimmer who meets its strike conditions, else an intact vessel, else nobody) through `bite_swimmer` and `hit_vessel`, then circles for its circle time and leaves; a vessel strike lands 1 tile off the hit deck's (or board's) edge on the side the pass names, never on the planks. A shooed shark leaves at once and bites nothing. The crossing's numbers and "Shark pass event" scenarios are unchanged. With exactly 1 player, the lone player or their raft is the only target. (Adds the crossing tell to docs/BESTIARY.md "Reef shark".)

#### Scenario: Solo crossing shark
- GIVEN a 1-player raft crossing whose player swims at energy 15 beside an intact raft
- WHEN the shark pass comes
- THEN a reef shark creature appears, the player loses 25 health and bleeds, the raft keeps its integrity, and the shark is gone after its circle time

#### Scenario: Solo sees the fin before it bites
- **GIVEN** a 1-player raft crossing whose shark pass strikes at 30 s on the east side
- **WHEN** the crossing reaches 25 s
- **THEN** a reef shark circles 1 tile off the raft's east edge and has bitten and hit nothing yet

#### Scenario: Solo strike lands beside the raft, not on it
- **GIVEN** a 1-player raft crossing at integrity 100 whose shark pass strikes at 10 s on the east side, nobody in the water
- **WHEN** the shark strikes
- **THEN** the raft is at 80 and the reef shark circles 1 tile off the raft's east edge, level with its middle, not on the deck

#### Scenario: Solo shoos the reef shark
- **GIVEN** a 1-player raft crossing at integrity 100 whose reef shark circles the west side before a strike at 30 s
- **WHEN** the player holds interact on it for 1 s at 27 s
- **THEN** the shark leaves at once, the raft is at 100 at 30 s, and no reef shark is in the crossing after 28 s

### Requirement: Every peer sees the crossing shark
The crossing's reef shark SHALL be a host-run creature like the island's: every peer in the crossing's session sees it from the pass's warning, circling beside the side it will strike, then beside its victim or the vessel; a peer that joins during its circle sees it too, and it leaves every screen when its circle ends on the host or when it is shooed. It is a passing creature, not one of the island's: phases, fires and island counts ignore it. With exactly 1 player, offline, the lone player sees it and it leaves after its circle time or when shooed, as before.

#### Scenario: A client sees the shark that bites them
- **GIVEN** a host and a client on a raft crossing, the client in the water at energy 15
- **WHEN** the shark pass comes
- **THEN** the client's screen shows a reef shark beside the client's player, and after its circle time it is gone there too

#### Scenario: A late joiner sees the circling shark
- **GIVEN** a reef shark circling during a crossing
- **WHEN** a client joins before the circle ends
- **THEN** the client sees the shark where the host has it

#### Scenario: The crossing shark is not an island creature
- **GIVEN** a crossing whose shark is circling while the island's night creatures are out
- **WHEN** dawn comes or a fire is lit on the island
- **THEN** the island's spawner neither counts nor removes the crossing's shark

#### Scenario: Solo crossing shark is unchanged
- **GIVEN** a 1-player raft crossing, offline, whose player swims at energy 15
- **WHEN** the shark pass comes
- **THEN** a reef shark appears, the player loses 25 health and bleeds, and the shark is gone after its circle time

#### Scenario: A shooed shark leaves the client's screen
- **GIVEN** a host and a client on a raft crossing, a reef shark circling the east side before its strike
- **WHEN** the client holds interact on it for 1 s
- **THEN** the host shoos it, and it is gone from both screens before the strike time
