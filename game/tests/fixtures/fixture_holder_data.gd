class_name FixtureHolderData
extends ContentData
## Test-only content type that embeds parts as a single value and as an array.

@export var main: FixturePartData = null
@export var parts: Array[FixturePartData] = []
