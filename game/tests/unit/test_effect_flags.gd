extends GutTest
## creature-perch-ride "Sighting effects": a flag effect sets or clears a run flag in the host's run
## record, through the session the player is in. One offline player sets it the same way, and a
## body outside any session changes nothing.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FLAG: StringName = &"galleguito_a_bordo"


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()


func _flag_effect(kind: EffectData.Kind) -> EffectData:
	var effect := EffectData.new()
	effect.kind = kind
	effect.ref_id = FLAG
	return effect


func test_a_solo_player_sets_and_clears_a_run_flag() -> void:
	var session := CrossingRig.make_session(self, 1)
	var body := session.body(1)
	EffectApplier.apply(_flag_effect(EffectData.Kind.SET_FLAG), body, body)
	assert_true(session.run_record.has_flag(FLAG), "set")
	EffectApplier.apply(_flag_effect(EffectData.Kind.CLEAR_FLAG), body, body)
	assert_false(session.run_record.has_flag(FLAG), "cleared")


func test_a_body_outside_a_session_changes_nothing() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	EffectApplier.apply(_flag_effect(EffectData.Kind.SET_FLAG), body, body)
	EffectApplier.apply(_flag_effect(EffectData.Kind.CLEAR_FLAG), body, body)
	assert_eq(body.meters.morale, SurvivalMeters.MAX_VALUE, "nothing else moved")
