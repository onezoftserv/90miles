# Spec Delta

## Purpose

Guarantees that the game project can be opened, run and tested without a display, and that every push and pull request is checked automatically on the same engine version developers use.

## ADDED Requirements

### Requirement: Headless smoke run
The project SHALL open, run its main scene, verify the core services and the content data, and quit with exit code 0 and no script errors, without a display.

#### Scenario: Clean project
- **GIVEN** a fresh checkout whose project has been imported once
- **WHEN** the smoke run starts headless
- **THEN** it exits with code 0 within 60 seconds

#### Scenario: Broken script
- **GIVEN** a script with a parse error in the project
- **WHEN** the smoke run starts headless
- **THEN** it exits with a non-zero code and the error names the script

#### Scenario: Invalid content
- **GIVEN** a content file that fails the content check
- **WHEN** the smoke run starts headless
- **THEN** it exits with a non-zero code and names the file

### Requirement: Headless unit tests
Unit tests SHALL run headless from the command line and exit non-zero when any test fails or errors.

#### Scenario: All tests pass
- **WHEN** the unit test run finishes with every test passing
- **THEN** it exits with code 0 and reports the number of tests run

#### Scenario: A test fails
- **GIVEN** one failing assertion
- **WHEN** the unit test run finishes
- **THEN** it exits with a non-zero code and names the failing test

### Requirement: Continuous integration gate
Every push to `main` and every pull request SHALL run the import, the smoke run and the unit tests on Linux, and the check SHALL fail if any of them fails.

#### Scenario: Passing change
- **WHEN** a pull request whose smoke run and tests pass is opened
- **THEN** the CI check reports success

#### Scenario: Failing change
- **WHEN** a commit that makes a unit test fail is pushed to `main`
- **THEN** the CI check reports failure and shows the failing test

### Requirement: Pinned engine version
The project SHALL declare the engine version it targets, and CI SHALL run that exact engine release.

#### Scenario: Version match
- **WHEN** CI runs
- **THEN** the engine version it reports equals the version the project declares

### Requirement: No dependency on downloaded assets
The smoke run and the unit tests SHALL pass on a checkout that has none of the git-ignored downloaded asset packs.

#### Scenario: Clean CI checkout
- **GIVEN** a checkout without `game/assets/kenney/`
- **WHEN** the import, smoke run and unit tests run
- **THEN** all three pass
