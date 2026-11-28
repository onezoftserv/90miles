extends GutTest
## inventory-hud "Vessel words in crossing prompts" (menu-clarity design D8, the Fable review's H19):
## a crossing's tie-down, untie and climb prompts name the route's own vessel from the HUD text, so
## the car is never called "la balsa". One player, offline; the rescue points are built alone.

const RAFT_ROUTE: String = "res://resources/routes/raft.tres"


class TiedPoint:
	extends RescuePoint

	func prompt_id_for(_by: Node) -> StringName:
		return &"untie"


func _crossing(vessel: DataEnums.Vessel) -> Crossing:
	var route := (load(RAFT_ROUTE) as RouteData).duplicate() as RouteData
	route.vessel = vessel
	var crossing: Crossing = autofree(Crossing.new())
	crossing.route = route
	return crossing


func _point(kind: RescuePoint.Kind, vessel: DataEnums.Vessel, tied: bool = false) -> RescuePoint:
	var point: RescuePoint = autofree(TiedPoint.new() if tied else RescuePoint.new())
	point.kind = kind
	point.crossing = _crossing(vessel)
	return point


func _prompt(point: RescuePoint) -> String:
	var parts := InteractPrompt.head_parts(point, null, "E", HudText.load_default(), "es")
	return " ".join(parts).strip_edges()


func test_the_car_is_the_almendron() -> void:
	assert_eq(_prompt(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.CAR)), "[E] Amarrarse al almendrón")
	assert_eq(_prompt(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.CAR, true)), "[E] Soltarse del almendrón")
	assert_eq(_prompt(_point(RescuePoint.Kind.CLIMB, DataEnums.Vessel.CAR)), "[E] Subir al almendrón")


func test_the_raft_is_unchanged() -> void:
	assert_eq(_prompt(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.RAFT)), "[E] Amarrarse a la balsa")
	assert_eq(_prompt(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.RAFT, true)), "[E] Soltarse de la balsa")


func test_a_board_is_your_own() -> void:
	assert_eq(_prompt(_point(RescuePoint.Kind.CLIMB, DataEnums.Vessel.BOARD)), "[E] Subir a tu tabla")


func test_a_vessel_with_no_words_of_its_own_reads_the_rafts() -> void:
	assert_eq(_prompt(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.BOAT)), "[E] Amarrarse a la balsa")


func test_the_vessel_key() -> void:
	assert_eq(InteractPrompt.vessel_key(_point(RescuePoint.Kind.LASH, DataEnums.Vessel.CAR)), "car")
	var loose: RescuePoint = autofree(RescuePoint.new())
	assert_eq(InteractPrompt.vessel_key(loose), "", "no crossing, no vessel")
