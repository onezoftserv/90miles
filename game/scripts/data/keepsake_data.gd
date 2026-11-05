class_name KeepsakeData
extends ItemData
## A between-run memory and a real item (cuchillo_abuelo is an unbreakable knife), saved flat in
## game/resources/items/. Always bound to its owner (one slot, lost only on death), so no flag.
## Adds perks, run-event effects and the profile unlock; content sets category and tags KEEPSAKE.
## Sources: ITEMS.md Keepsakes, endings-progression spec.

## Profile event that unlocks the keepsake.
enum UnlockKind {
	NONE,
	FINISH_RUN,
	KILL_CREATURE,
	KILL_CREATURE_WITH_TAG,
	QUEST_COMPLETED,
	CROSSINGS_BY_ROUTE,
	REACH_CHAIN_FAMILY,
	FINISH_WITH_BACKGROUND,
	NPC_REACHES_LAND,
}

## Whether unlock_count is counted within one run or across the profile.
enum CountScope {
	SINGLE_RUN,
	LIFETIME,
}

@export_group("Perks and Events")
## Perks granted to the holder while perk_conditions hold.
@export var granted_perks: Array[DataEnums.Perk] = []
## Conditions for granted_perks (cassette: radio and a power source).
@export var perk_conditions: Array[ConditionData] = []
## Fired when the holder would go down (medalla: one free revive per run).
@export var holder_downed_effects: Array[EffectData] = []
## Fired on arrival at an island, gated by each effect's conditions.
@export var island_arrival_effects: Array[EffectData] = []

@export_group("Unlock")
## Profile event that unlocks it in user://profile.cfg; NONE: unlocked from the start. Seeded runs never unlock.
@export var unlock: UnlockKind = UnlockKind.NONE
## Ids the trigger matches (any): creatures, quest ids, routes, backgrounds or NPCs, by unlock.
@export var unlock_ref_ids: Array[StringName] = []
## For KILL_CREATURE_WITH_TAG. The tiger shark has health 0 and cannot count.
@export var unlock_creature_tag: DataEnums.CreatureTag = DataEnums.CreatureTag.SHARK
## For REACH_CHAIN_FAMILY.
@export var unlock_chain_family: DataEnums.ChainFamily = DataEnums.ChainFamily.SANDBAR
## How many times the trigger must happen.
@export var unlock_count: int = 1
## Count within one run or across the profile.
@export var unlock_count_scope: CountScope = CountScope.LIFETIME
## For FINISH_* kinds: endings that count; empty means any.
@export var unlock_endings: Array[DataEnums.Ending] = []
## Every player in the session unlocks it.
@export var unlock_for_party: bool = false
## Profile-screen unlock hint in Spanish.
@export var unlock_hint_es: String = ""
## Profile-screen unlock hint in English.
@export var unlock_hint_en: String = ""


## ItemData's references plus unlock_ref_ids, whose folder depends on unlock. Quest ids are not
## a content folder, so QUEST_COMPLETED adds nothing.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	var refs: Dictionary[StringName, StringName] = {}
	refs.merge(super.get_reference_fields())
	match unlock:
		UnlockKind.KILL_CREATURE:
			refs[&"unlock_ref_ids"] = &"creatures"
		UnlockKind.CROSSINGS_BY_ROUTE:
			refs[&"unlock_ref_ids"] = &"routes"
		UnlockKind.FINISH_WITH_BACKGROUND:
			refs[&"unlock_ref_ids"] = &"backgrounds"
		UnlockKind.NPC_REACHES_LAND:
			refs[&"unlock_ref_ids"] = &"npcs"
	return refs
