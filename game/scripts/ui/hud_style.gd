class_name HudStyle
extends RefCounted
## The run HUD's colours and glyph width in one place (inventory-hud design D1), for the HUD pieces
## that draw, tint or measure text in code: the ring and the strip's slot ring, the crafting list's
## highlight, the prompt's progress bar and the hidden mark. The theme (game_theme.tres) uses the
## same values in its own styles (HudSlotSelected's border, HudSlot's frame, HudCount's outline,
## Label's font colour); a palette change goes to both.

## The selection's sun yellow: the selected slot, the highlighted row, a filling ring or bar.
const SUN: Color = Color(1.0, 0.8, 0.0)
## The HUD's cream text colour.
const CREAM: Color = Color(0.95686275, 0.9372549, 0.8784314)
## The cream at 35 %: an empty ring's track, an empty bar.
const TRACK: Color = Color(0.95686275, 0.9372549, 0.8784314, 0.35)
## The dark blue outline under counts and marks.
const OUTLINE: Color = Color(0.04, 0.08, 0.13)
## Width of one glyph of the HUD's 8 px pixel font (the theme's default font size).
const GLYPH_PX: float = 8.0
