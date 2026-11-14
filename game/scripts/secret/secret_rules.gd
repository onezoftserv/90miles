class_name SecretRules
extends RefCounted
## secret-cay "One shared secret check": the one question every system that shows something, or
## draws from a list of items or layouts, asks before it shows or draws an entry, and the one
## filter it passes its list through. An item is secret when it carries the SECRET tag, a layout
## when it is marked secret. Works the same for 1 player and for 4.


## Whether `entry` (an ItemData, an IslandLayoutData, or anything else) is secret.
static func is_secret(entry: Variant) -> bool:
	var item := entry as ItemData if entry is ItemData else null
	if item != null:
		return item.tags.has(DataEnums.ItemTag.SECRET)
	var layout := entry as IslandLayoutData if entry is IslandLayoutData else null
	if layout != null:
		return layout.secret
	return false


## `entries` without its secret ones, in the same order.
static func without_secrets(entries: Array) -> Array:
	var kept: Array = []
	for entry: Variant in entries:
		if not is_secret(entry):
			kept.append(entry)
	return kept
