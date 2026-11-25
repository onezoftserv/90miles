class_name GeneratedIsland
extends RefCounted
## What IslandGenerator.generate returns: the layout, its reading, its hash and how it was found.

var layout: IslandLayoutData
var built: IslandLayout
## SHA-256 of the layout's canonical text (IslandLayoutWriter.write).
var island_hash: String = ""
## Attempts run, the accepted one included (all of them when the fallback was used).
var attempts: int = 0
## true when no attempt passed and the chain's fallback island was used.
var fallback: bool = false
## The placed POIs, {id: StringName, anchor: Vector2i}.
var pois: Array[Dictionary] = []
## Measured numbers for tests and the dev scene: attempts (each {failures, pois, terrain,
## land_count, shore_width}), land_cells, generation_ms.
var report: Dictionary = {}
