## MODIFIED Requirements

### Requirement: Master palette
Every tracked image under `game/assets/art/`, the UI window kit in `art/ui/` included, SHALL use only master palette colours (at most 64: DawnBringer's 32-colour palette plus the tropical, sea and skin ramps the packs need), each pixel fully opaque or fully transparent. Only drop shadows and shade decals, kept in `shadows/` and `decals/`, may use the darkest colour at partial alpha; pack art loses its baked half-transparent shadows.

#### Scenario: Off-palette pixel
- **GIVEN** a tracked creature frame with one pixel not in the master palette
- **WHEN** the palette check runs
- **THEN** it fails and names the file and the pixel

#### Scenario: Partial alpha outside shadows
- **GIVEN** a tracked item icon with a half-transparent pixel
- **WHEN** the palette check runs
- **THEN** it fails, while the same alpha in a file under `shadows/` or `decals/` passes

#### Scenario: A UI piece off the palette
- **GIVEN** a window piece in `art/ui/` with one pixel not in the master palette
- **WHEN** the palette check runs
- **THEN** it fails and names the file and the pixel
