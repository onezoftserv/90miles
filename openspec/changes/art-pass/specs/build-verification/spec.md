# Spec Delta

## MODIFIED Requirements

### Requirement: No dependency on downloaded assets
The smoke run and the unit tests SHALL pass on a checkout that has none of the git-ignored downloaded asset packs (`game/assets/kenney/`, `game/assets/oga/` and `game/assets/itch/`), and no tracked scene, resource, GDScript or shader under `game/` SHALL refer to a file inside those folders: art the game uses is copied into a tracked folder first. The pipeline tools under `tools/`, which read the packs as data, are outside this rule.

#### Scenario: Clean CI checkout
- **GIVEN** a checkout without `game/assets/kenney/`, `game/assets/oga/` and `game/assets/itch/`
- **WHEN** the import, smoke run and unit tests run
- **THEN** all three pass

#### Scenario: A reference into a download folder
- **GIVEN** a tracked scene whose sprite points at a PNG under `game/assets/itch/`
- **WHEN** the unit tests run
- **THEN** the downloaded-asset check fails and names the scene and the path
