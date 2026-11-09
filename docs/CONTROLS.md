# Controls

Every named input action and its default binding, read from the `[input]` section of `game/project.godot`. Keys are bound by physical position, so a non-US layout keeps the same places (the HUD prints the key your layout shows there). Gamepad names are Xbox names; PlayStation glyphs and rebinding come later.

No key, mouse button or gamepad button is bound to two of these actions (`test_input_map_hud.gd`). Godot's built-in `ui_*` focus actions are not listed: menus use them, and they share Enter, Esc, the arrows, the D-pad and A/B with these by design.

| Action | What it does | Keyboard / mouse | Gamepad |
| --- | --- | --- | --- |
| `move_up` | Walk north | W | Left stick up |
| `move_down` | Walk south | S | Left stick down |
| `move_left` | Walk west | A | Left stick left |
| `move_right` | Walk east | D | Left stick right |
| `run` | Run while held | Shift | LB (button 9) |
| `crouch` | Crouch while held | Ctrl or C | B (button 1) |
| `interact` | Use what the prompt names; choose in the crafting list | E | A (button 0) |
| `use_item` | Use the selected item (hold for its time) | F | X (button 2) |
| `slot_1` ... `slot_9` | Select screen slots 1 to 9 | 1 ... 9 (number row) | none |
| `slot_10` | Select screen slot 10 | 0 | none |
| `slot_11` | Select screen slot 11 | - (minus) | none |
| `slot_12` | Select screen slot 12 | = (equal) | none |
| `slot_next` | Next slot that holds something (while the crafting list is open the mouse wheel moves its row down instead; D-pad right still moves the slot) | Mouse wheel down | D-pad right (button 14) |
| `slot_prev` | Previous slot that holds something (while the crafting list is open the mouse wheel moves its row up instead; D-pad left still moves the slot) | Mouse wheel up | D-pad left (button 13) |
| `list_up` | Crafting list: row up | Arrow up | D-pad up (button 11) |
| `list_down` | Crafting list: row down | Arrow down | D-pad down (button 12) |
| `quick_chat` | Quick-chat wheel while held (co-op only) | Q | RB (button 10) |
| `toggle_fullscreen` | Fullscreen on or off | F11 or Alt+Enter | none |
| `pause` | Close the crafting list; else pause (solo only) | Esc | Start (button 6) |

Slots 1 to 12 have no gamepad default: D-pad left and right cycle through every slot that holds an item, and the 13th (Experiencia) slot has no number key, so the wheel, the D-pad and a click reach it. A left click on a slot selects it.
