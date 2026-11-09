# Spec Delta

## MODIFIED Requirements

### Requirement: Named input actions
The game SHALL define named input actions, each with a keyboard or mouse default and, where one exists, a gamepad default: moving up, down, left and right (WASD; left stick), run (Shift; a shoulder button), crouch (Ctrl or C; a face button), interact (E; another face button), use the selected item (F; a third face button, X), slots 1 to 12 (the number row 1-9, 0, - and =; none on a gamepad, where D-pad cycling reaches them), next and previous slot (mouse wheel down and up; D-pad right and left) and list up and down (arrow keys up and down; D-pad up and down).

#### Scenario: Gamepad movement
- **WHEN** a player pushes the left stick fully right
- **THEN** the move intent points east with full strength and the player walks at 4 tiles/s

#### Scenario: Use on a gamepad
- **GIVEN** a solo player on a gamepad with a rain cup selected
- **WHEN** they hold X for 1 s
- **THEN** the cup is drunk, exactly as holding F would
