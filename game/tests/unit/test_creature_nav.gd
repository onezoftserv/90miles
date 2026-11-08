extends GutTest
## creatures-ai "Creature navigation".

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")


func test_land_grid_costs_and_solid_deep_water() -> void:
	var built := IslandLayout.build(SANDBAR)
	var nav := CreatureNav.build(built.terrain, built.size)
	assert_eq(nav.land.get_point_weight_scale(built.solo_spawn), 1.0)
	for cell: Vector2i in built.terrain.cells:
		match built.terrain.cells[cell]:
			DataEnums.Terrain.DUNE:
				assert_eq(nav.land.get_point_weight_scale(cell), 1.5)
			DataEnums.Terrain.SHALLOWS:
				assert_eq(nav.land.get_point_weight_scale(cell), 2.0)
			DataEnums.Terrain.DEEP:
				assert_true(nav.land.is_point_solid(cell))


func test_water_grid_keeps_the_shore_margin() -> void:
	var built := IslandLayout.build(SANDBAR)
	var nav := CreatureNav.build(built.terrain, built.size)
	var water := nav.water(2)
	var open: int = 0
	for cell: Vector2i in built.terrain.cells:
		if water.is_point_solid(cell):
			continue
		open += 1
		assert_true(TerrainQuery.is_water(built.terrain.cells[cell]))
		assert_gte(nav.land_distance(cell), 2)
	assert_gt(open, 0)


func test_sandbar_has_one_beach() -> void:
	var built := IslandLayout.build(SANDBAR)
	var nav := CreatureNav.build(built.terrain, built.size)
	assert_eq(nav.beach_groups().size(), 1)
