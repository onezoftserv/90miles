class_name IslandLayoutData
extends ContentData
## A handmade island as text rows plus a legend (island-generation "Handmade sandbar"). Every
## glyph in the rows needs a terrain in `terrain_glyphs`; the other glyph fields say which ones
## are the palms, the workbench, the spawn points, the tide pools and the pick-ups. Moving a palm
## or adding a jug is an edit of the rows. Files live in game/resources/islands/.

@export_multiline var description_es: String = ""
@export_multiline var description_en: String = ""

@export_group("Map")
## One string per row, all the same length.
@export var rows: PackedStringArray = PackedStringArray()
@export var terrain_glyphs: Dictionary[String, DataEnums.Terrain] = {}
## Glyphs whose cells are shaded (the hut).
@export var shade_glyphs: String = ""

@export_group("Palms")
@export var palm_glyph: String = ""
## Coconuts on the island, shared over the palms in reading order (the first ones get more).
@export var coconut_total: int = 0
## Indices into the palms (reading order) where gulls nest (creatures-ai).
@export var nest_palms: Array[int] = []
## Seconds the interact button is held to climb.
@export var climb_hold_s: float = 2.0
## What one climb costs the climber (energy).
@export var climb_effects: Array[EffectData] = []

@export_group("Markers")
@export var workbench_glyph: String = ""
@export var solo_spawn_glyph: String = ""
## One glyph per co-op spawn point, in join order (the host first).
@export var coop_spawn_glyphs: String = ""
@export var tide_pool_glyph: String = ""
## The beach cell where the raft is built.
@export var raft_site_glyph: String = ""

@export_group("Routes")
## The routes the island offers (RouteData ids in game/resources/routes/).
@export var route_ids: Array[StringName] = []

@export_group("Pick-ups")
@export var pickups: Array[IslandGlyphData] = []
