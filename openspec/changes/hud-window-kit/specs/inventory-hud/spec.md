## MODIFIED Requirements

### Requirement: Inventory strip
During a run the HUD SHALL show the local player's inventory as one row of 26×26 px slots, one per inventory slot (12, or 13 with the Experiencia slot), 2 px apart, centred in the bottom band of the 640×360 view with a 4 px bottom margin, on one thin dark window, each slot a recessed well. Slots are numbered from 1 on screen: screen slot n is inventory slot n − 1. The selected item's line and the refusal line sit above the row and the weight to its right, all on thin HUD windows, clear of the meters, the day phase, the teammate list and the centre.

#### Scenario: Solo strip at 640×360
- **GIVEN** a solo run on the sandbar
- **WHEN** the HUD is drawn
- **THEN** 12 slots of 26×26 px sit in one row from x 153 to 487 and y 330 to 356, inside the view and overlapping neither the meters panel nor the day phase

#### Scenario: Co-op strip beside the teammates
- **GIVEN** a host with one client
- **WHEN** each peer draws its HUD
- **THEN** each shows its own player's strip in the bottom band and its teammate list top-right, and the two do not overlap

#### Scenario: Screen slot 1 is inventory slot 0
- **GIVEN** a solo player with an empty inventory next to a coconut
- **WHEN** they pick it up
- **THEN** inventory slot 0 holds it and the strip draws it in screen slot 1, the slot key 1 selects

#### Scenario: The strip's window
- **GIVEN** a solo run, offline, with exactly 1 player on the sandbar
- **WHEN** the HUD is drawn
- **THEN** the strip's window lies inside y 329 to 358, below the selected item's line and left of the weight, and every slot keeps its 26×26 rect as a recessed well

### Requirement: Slot contents
Each slot SHALL show its item's 16×16 icon with its top-left at (5,4) or, while it has none, the first three letters of its Spanish name. Bottom-right, in small 3×5 digits outlined in dark, it shows a stack's count above 1 or the uses left of an item with more than 1 use, in orange on the last use. A slot whose item has a use that the use button would refuse right now is dimmed, never hidden. Top-left, on the selected slot only and while the last device used is the keyboard, it shows the slot's key in the same digits. No digit pixel lies inside the icon's square. An empty slot keeps its well. The selected slot has a sun-yellow ring with an orange inner ring. The weight reads "Peso <carried>/<limit>" with a decimal comma. Solo the same.

#### Scenario: A stack, a tool and an empty slot
- **GIVEN** a solo player on the keyboard holding 3 coco in screen slot 1, which is selected, and a knife with 39 uses left in screen slot 2, with screen slot 3 empty
- **WHEN** the strip is drawn
- **THEN** slot 1 shows the coconut's icon with 3 bottom-right and "1" top-left, slot 2 shows the knife's icon with 39 and no key, slot 3 shows only its well, and the weight reads "Peso 2,5/30"

#### Scenario: No slot keys on a gamepad
- **GIVEN** the same player after pressing a gamepad button
- **WHEN** the strip is drawn
- **THEN** no slot shows a key

#### Scenario: The key follows the selection
- **GIVEN** a solo player, offline, on the keyboard with screen slot 1 selected
- **WHEN** they press 4
- **THEN** screen slot 4 shows "4" top-left and no other slot shows a key

#### Scenario: Digits clear of the icon
- **GIVEN** a solo player, offline, on the keyboard holding a full stack of 40 in the selected slot
- **WHEN** the strip is drawn
- **THEN** neither the count's nor the key's digit pixels lie inside the icon's 16×16 square, and the icon's black outline stands at 5:1 or more against the well

#### Scenario: The last use
- **GIVEN** a solo player, offline, holding a knife with 1 use left and a lighter with 20
- **WHEN** the strip is drawn
- **THEN** the knife's slot shows "1" in orange bottom-right and the lighter's shows "20" in cream

#### Scenario: Refused now, dimmed
- **GIVEN** a solo player, offline, on the raft crossing, holding a rain cup and driftwood
- **WHEN** the strip is drawn
- **THEN** the rain cup's slot is dimmed with its icon still shown, and the driftwood's slot, which has no use, is not dimmed

#### Scenario: A blade makes the coconut usable
- **GIVEN** a solo player, offline, with thirst 50, holding a coconut and nothing that opens coconuts, its slot dimmed
- **WHEN** they pick up a knife
- **THEN** the coconut's slot is no longer dimmed

## ADDED Requirements

### Requirement: Slot tooltip
Resting the mouse pointer on a slot that holds an item for half a second SHALL show a tooltip with the item's name and its use verb, from the content and HUD text files in the session's language, on a thin dark window inside the view. It takes no focus, selects nothing, and goes when the pointer leaves. A gamepad never shows it; the selected item's line names the item there. Solo the same.

#### Scenario: Pointing at a coconut
- **GIVEN** a solo player, offline, holding a coconut in screen slot 3 with slot 1 selected
- **WHEN** they rest the pointer on slot 3 for half a second
- **THEN** a tooltip reads "Coco · Beber" on a thin dark window inside the 640×360 view, and slot 1 stays selected

#### Scenario: No tooltip on an empty slot
- **GIVEN** the same player
- **WHEN** they rest the pointer on an empty slot
- **THEN** no tooltip shows
