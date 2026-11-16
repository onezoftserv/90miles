class_name FixtureBackgrounds
extends RefCounted
## Test-only stand-in for picking a background (guardacostas-capture tasks.md 1.3): players have no
## background until the backgrounds change ships, so a test gives one by id. The id must name a
## shipped background file (the stub maestro or medico), as the persuasion check reads it.


static func give(body: PlayerBody, background_id: StringName) -> void:
	assert(GameState.content.has_entry(&"backgrounds", background_id), "no background %s" % background_id)
	body.background_id = background_id
