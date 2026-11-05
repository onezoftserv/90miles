class_name NpcData
extends ContentData
## One NPC: identity, look, dialogue mode, spawn rules, trust, embedded quests and hooks, an
## optional companion block, animal behavior and ending roles. One file per NPC, flat in
## game/resources/npcs/ (category is an enum, subfolders are not discovered). The id keys
## companion_<id>_alive, the DialogueService npc_id and the backend profile. See CHARACTERS, npcs-dialogue.

## Manifest subgroup.
enum Category {
	IMPORTANT,
	COMPANION,
	MINOR,
	ANIMAL,
}

## How the NPC talks: the spec's handwritten | ai, NONE for animals.
enum DialogueMode {
	NONE,
	HANDWRITTEN,
	AI,
}

## How the NPC exists in the world.
enum Presence {
	STANDING,
	HIDING,
	ON_VESSEL,
	CORPSE,
	ANIMAL,
	POD,
}

## What the NPC does while not engaged.
enum AmbientBehavior {
	IDLE,
	WANDER,
	GATHER,
	WORK,
	FOLLOW_PARTY,
}

@export_group("Profile")
## Short examine text in Spanish. AI backstory and voice live in the backend profile.
@export_multiline var description_es: String = ""
## English examine text.
@export_multiline var description_en: String = ""
## Manifest subgroup. COMPANION counts toward the 1-3 per run budget.
@export var category: Category = Category.MINOR
## Age in years; 0 means not given. Sent in the AI context.
@export var age: int = 0

@export_group("Look")
## 32x32 world sprite.
@export var sprite_frames: SpriteFrames = null
## Dialogue portrait.
@export var portrait: Texture2D = null
## Per-instance sprites for group NPCs.
@export var look_variants: Array[SpriteFrames] = []
## Portraits matching look_variants by index.
@export var portrait_variants: Array[Texture2D] = []
## Cloned voice for gen_voice.py and the per-emotion grunt set.
@export var voice_id: StringName = &""

@export_group("Dialogue")
## The spec's handwritten | ai; NONE for animals.
@export var dialogue_mode: DialogueMode = DialogueMode.HANDWRITTEN
## Profile path relative to backend/prompts/ ("npcs/ramon.md"). Informational; a test validates it.
@export var ai_profile_path: String = ""
## Speech registers sent as context.register (loudhailer, in_person ...).
@export var speech_registers: Array[StringName] = []
## DialogueData with this NPC's handwritten lines or AI fallbacks; empty means same as id.
@export var dialogue_id: StringName = &""

@export_group("Spawn")
## Spawn rules; each matching rule rolls.
@export var spawn_rules: Array[NpcSpawnRuleData] = []
## Most instances per run; 0 means unlimited.
@export var max_per_run: int = 1
## How the NPC exists in the world.
@export var presence: Presence = Presence.STANDING
## Behavior while not engaged.
@export var ambient_behavior: AmbientBehavior = AmbientBehavior.IDLE
## Item ids taken from the island pool when ambient_behavior is GATHER.
@export var gather_item_ids: Array[StringName] = []

@export_group("Trust")
## Tracks trust this run.
@export var has_trust: bool = false
## Keeps 50% trust on death and 100% on a win, and sets returning in the AI context.
@export var trust_carries_over: bool = false
## Background id -> trust-gain multiplier. The only home of the Pescador softening.
@export var background_trust_mult: Dictionary[StringName, float] = {}
## Minor NPC picks RETURNING dialogue variants across runs.
@export var remembers_across_runs: bool = false

@export_group("Quests")
## Embedded quests, encounters, trades, rescues and gifts.
@export var quests: Array[QuestData] = []
## Event-to-effect rules (needs, fears, ending flags).
@export var hooks: Array[NpcHookData] = []

@export_group("Companion")
## Party-member block, set for anyone who can join (8 companions, yunior, ramon, vieja_turtle).
@export var companion: CompanionData = null

@export_group("Animal")
## false means it cannot be fed or kept.
@export var keepable: bool = true
## Creature tags kept away from swimmers inside repel_radius_tiles.
@export var repels_creature_tags: Array[DataEnums.CreatureTag] = []
## Repel radius in tiles. TBD.
@export var repel_radius_tiles: float = 0.0

@export_group("Endings")
## Declared run flags this NPC can set; a test checks it against the effects.
@export var ending_flags: Array[StringName] = []
## Slots this NPC fills in ending scenes, so a new companion never edits an ending file.
@export var ending_roles: Array[EndingRoleData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"dialogue_id": &"dialogue", &"gather_item_ids": &"items", &"background_trust_mult": &"backgrounds"}
