# Tasks

## 1. Project and tooling

- [x] 1.1 Create `game/project.godot` (Godot 4.7, GL Compatibility, 640×360, integer scaling, nearest filter, pixel snap, untyped declarations as errors) and verify `godot --headless --path game --import` exits 0
- [x] 1.2 Vendor GUT 9.7.1 in `game/addons/gut/` with `game/.gutconfig.json` and the post-run hook, and verify a GUT run that collects no tests exits 1
- [x] 1.3 Add `.gitattributes` (LF for Godot files and scripts) and ignore Git Bash crash dumps, and verify `git add --renormalize .` changes nothing

## 2. Content data

- [x] 2.1 Add `ContentData` and `ContentCatalog` (folder discovery with `ResourceLoader.list_directory`, exact-name lookups, unregistered-folder listing) and verify `test_content_catalog.gd` passes
- [x] 2.2 Add `ContentValidator` (folder type, id equals file name, duplicate ids, Spanish name, references as id / id array / id-keyed dictionary, unknown fields and types) and verify `test_content_validator.gd` passes
- [x] 2.3 Add `DataEnums` and the `DataPart` base, make the validator recurse into embedded parts with path-qualified messages, and verify `test_content_parts.gd` passes
- [x] 2.4 Add the data classes for the 11 manifest folders and their embedded parts, register the folders in `ContentCatalog.DEFAULT_TYPES`, and verify `test_data_classes.gd` passes (instantiation, reference declarations for every kind, `.tres` round trips, validation of real classes)
- [x] 2.5 Record the data model's open questions in `data-model-questions.md` and verify each class's choice is named there

## 3. Core services and main scene

- [x] 3.1 Add the five autoload stubs and `CoreServices` (names, singleton flag, registered script) and verify `test_core_services.gd` passes, including "services hold no content data"
- [x] 3.2 Add the main scene and verify the smoke run and `--quit-after 300` boot it with no errors

## 4. Verification and CI

- [x] 4.1 Add `game/tests/smoke.gd` and verify it exits 0 on the project and 1 on scratch copies with a parse error, a mismatched content id, an untyped declaration, a scene depending on a git-ignored asset, a broken test file and an unregistered content folder
- [x] 4.2 Add `test_suite_integrity.gd` and verify GUT exits non-zero when a test file does not compile, does not extend `GutTest`, has no tests or sits outside `tests/unit/`
- [ ] 4.3 Add `.github/workflows/ci.yml` (pinned Godot download and actions, version check, import, smoke, game run, GUT) and verify the first GitHub Actions run passes

## 5. Docs

- [x] 5.1 Correct the test commands in `CLAUDE.md` and `HANDOFF.md` and the layout in `README.md`, and verify the documented commands run as written
- [ ] 5.2 Tick `TASKS.md` §2 and verify each ticked line matches a passing check

## Workflow follow-up

- Run the ECC review over the whole change and fix what survives verification.
- Archive the change with `/opsx:archive` and verify `openspec validate --all` passes with the three new capability specs.
