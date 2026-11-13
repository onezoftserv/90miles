class_name TerrainArtData
extends Resource
## Which tile each terrain kind gets, only in res://assets/art/terrain/terrain_art.tres (the script
## has no defaults, like ArtTuning): the layer of every land kind, the source ids of the layers'
## tile sets, the picks that replace a corner set's tile and the depth step of each water kind.
## A new terrain kind is an edit of this file and of the sheets, never of a script (design.md D11).

const STANDARD_PATH: String = "res://assets/art/terrain/terrain_art.tres"

## The corner-set layers from the bottom up: a layer counts its own kinds and those of the layers
## after it as land, so each lies whole on the one below.
@export var set_layers: Array[StringName]
## The layer of the kinds that have one tile each (a row of `plain.png`).
@export var plain_layer: StringName
## The layer each land kind is drawn on. A kind on a set layer also lies on every layer before it;
## every land kind lies on the first one.
@export var layer_of: Dictionary[DataEnums.Terrain, StringName]
## The row of `plain.png` of each kind on the plain layer.
@export var plain_row: Dictionary[DataEnums.Terrain, int]
## The atlas source of each layer's own sheet, and of the sheet a layer uses where its cell has a
## shore (the sand layer has none: its sheet already holds the shore shapes).
@export var source_of: Dictionary[StringName, int]
@export var shore_source_of: Dictionary[StringName, int]
## Rows of a shore sheet per terrain: the tile is at (sand mask, stride x row + own mask).
@export var shore_row_stride: int
## Per layer, the corner mask whose tile the picks replace and how many picks there are (row 4 of
## the sheet). A layer with none has no entry.
@export var variant_mask: Dictionary[StringName, int]
@export var variant_count: Dictionary[StringName, int]
## The depth-mask step of each water kind: deep, shallows and brackish all differ.
@export var depth_steps: Dictionary[DataEnums.Terrain, int]
## What a land cell with no water beside it holds in the depth mask (its sea is never seen).
@export var land_step: int


static func standard() -> TerrainArtData:
	return load(STANDARD_PATH) as TerrainArtData
