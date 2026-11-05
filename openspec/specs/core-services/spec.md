# core-services Specification

## Purpose
Defines the fixed set of global services (game state, networking, weather, dialogue, audio) that every scene and headless script can rely on from startup, and makes changes to that set a deliberate spec decision.

## Requirements

### Requirement: Core services are available from startup
The game SHALL provide exactly five global services, available to every scene and to headless scripts from the first frame: game state, networking, weather, dialogue and audio.

#### Scenario: Services present in a normal run
- **WHEN** the game starts its main scene
- **THEN** all five services are reachable before the main scene's first frame

#### Scenario: Services present in a headless script
- **WHEN** a headless script runs against the project
- **THEN** all five services are reachable from it

### Requirement: The service set changes only through a spec change
The set of global services SHALL match this specification. A project configuration that adds, removes or renames a global service without a matching change to this specification SHALL fail verification.

#### Scenario: Unlisted service added
- **GIVEN** the project configuration registers a sixth global service
- **WHEN** the verification checks run
- **THEN** they fail and name the unlisted service

#### Scenario: Listed service missing
- **GIVEN** the project configuration no longer registers the audio service
- **WHEN** the verification checks run
- **THEN** they fail and name the missing service

### Requirement: Services hold no content data
Global services SHALL NOT embed content values (creature stats, item effects, recipe costs, dialogue lines); they SHALL read them from content data.

#### Scenario: Tuning a value
- **WHEN** a designer changes a coconut's thirst restore
- **THEN** only the coconut content file changes and no service script is edited
