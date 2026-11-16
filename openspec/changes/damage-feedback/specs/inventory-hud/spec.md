## ADDED Requirements

### Requirement: Effect line
While the selected item has a use, the row above its line (the refusal row) SHALL say what the use the button would send does. The text is built from that use's effects by the rules the host applies:
- signed meter changes ("Sed +15");
- a meal's energy;
- a change over time ("Salud -50 en 60 s");
- statuses cured ("Cura sangrado y quemadura");
- a revive ("Levanta").

Kinds the host does not apply are left out. A refusal replaces the row for 2 s. Solo the same.

#### Scenario: A coconut's line, solo
- **GIVEN** a solo player, offline, holding a knife and a coconut, the coconut selected
- **WHEN** the strip is drawn
- **THEN** the row reads "Sed +15 · Hambre +5 · Energía +10"

#### Scenario: Waste shows before use
- **GIVEN** a solo player at thirst 94, hunger 50 and energy 50, holding a knife and a coconut, the coconut selected
- **WHEN** the strip is drawn
- **THEN** the row reads "Sed +15 (+6 útil) · Hambre +5 · Energía +10"

#### Scenario: Sábila's line
- **GIVEN** a solo player with sábila selected
- **WHEN** the strip is drawn
- **THEN** the row reads "Cura quemadura y sangrado", in the order of sábila's effects

#### Scenario: A drain over time
- **GIVEN** a solo player with manzanillo selected
- **WHEN** the strip is drawn
- **THEN** the row reads "Salud -50 en 60 s"

#### Scenario: The line follows the use the button picks
- **GIVEN** a co-op player with a coconut selected, 0.5 tiles from a downed teammate
- **WHEN** the strip is drawn
- **THEN** the row reads "Levanta · Sed +15 · Hambre +5 · Energía +10"

#### Scenario: Nothing to use
- **GIVEN** a solo player with driftwood selected
- **WHEN** the strip is drawn
- **THEN** the row is empty

#### Scenario: A refusal takes the row
- **GIVEN** a solo player with a coconut selected and no blade
- **WHEN** they press F
- **THEN** "Te falta con qué abrir el coco." shows in the row for 2 s, then the effect line returns

#### Scenario: The line never drifts from the effects
- **GIVEN** every item in the content catalog
- **WHEN** its uses' lines are built
- **THEN** each effect kind the host applies has its words in `hud_text.tres`, and no line names a kind the host skips

### Requirement: Uses that would do nothing
Before sending, the HUD SHALL refuse a use that would change nothing for whoever it goes on: every meter it raises is already full or less than 1 point from it, every status it cures is absent, and it has no other effect. It shows a Cuban reason from `hud_text.tres` for 2 s, and nothing is sent or spent. Solo the same.

#### Scenario: Which reason shows
- **GIVEN** a refused use that would do nothing
- **WHEN** its reason is picked
- **THEN** it is the line of the first meter it raises ("No tienes sed."), or of the one status it cures ("No 'tás sangrando."), or "No hay na' que curar." for several statuses, and "A Papo no le hace falta." when it goes on Papo

#### Scenario: Sábila with nothing to cure, solo
- **GIVEN** a solo player, offline, who is neither bleeding nor sunburnt, with sábila selected
- **WHEN** they press F
- **THEN** "No hay na' que curar." shows (sábila cures two statuses), nothing is sent and the sábila stays

#### Scenario: A coconut at full thirst and hunger
- **GIVEN** a solo player with thirst, hunger and energy all full, holding a knife and a coconut
- **WHEN** they press F
- **THEN** "No tienes sed." shows, nothing is sent, and the coconut and the knife's uses stay

#### Scenario: Part of it still helps
- **GIVEN** a solo player with full thirst and hunger 80, holding a knife and a coconut
- **WHEN** they hold F for 2 s
- **THEN** the coconut is drunk and hunger rises

#### Scenario: Sábila on a teammate who does not need it
- **GIVEN** a co-op player with sábila selected, aiming it at Papo, who is neither bleeding nor sunburnt
- **WHEN** they press F
- **THEN** "A Papo no le hace falta." shows and nothing is sent
