class_name HudStyle
extends RefCounted
## The run HUD's colours and glyph width in one place (inventory-hud design D1; hud-window-kit
## design D3), for the HUD pieces that draw, tint or measure text in code: the ring and the strip's
## slot ring, the crafting list's highlight, the prompt's progress bar, the hidden mark, the meter
## rows' steps and pulse, the teammate blocks. Every colour is a master palette colour, the same the
## theme (game_theme.tres) and the window kit (tools/art/ui_kit.json) use; a palette change goes to
## all three in one commit.

## The selection's sun yellow (#fbf236): the selected slot, the highlighted row, a filling ring or
## bar, focused text.
const SUN: Color = Color(0.98431373, 0.94901961, 0.21176471)
## The HUD's cream text colour (#ffedde).
const CREAM: Color = Color(1.0, 0.92941176, 0.87058824)
## An empty ring's or bar's track (#3f3f74), opaque and on the palette.
const TRACK: Color = Color(0.24705882, 0.24705882, 0.45490196)
## The dark outline under counts and marks, and the dark window's fill (#222034).
const OUTLINE: Color = Color(0.13333333, 0.1254902, 0.20392157)
## The alert red (#d95763): a critical meter, "Sangrando", "Caído", "Muerto", a lost slice. 4.15:1
## on the dark window, so only for short alert words and pulsing values (ui-shell "Readable HUD and
## menu text").
const ALERT: Color = Color(0.85098039, 0.34117647, 0.38823529)
## The warning orange (#df7126): a meter at its warning step, a tool's last use. 4.93:1 on the dark
## window.
const ORANGE: Color = Color(0.8745098, 0.44313725, 0.14901961)
## Width of one glyph of the HUD's 8 px pixel font (the theme's default font size).
const GLYPH_PX: float = 8.0
