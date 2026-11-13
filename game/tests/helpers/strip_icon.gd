class_name StripIcon
extends RefCounted
## What a strip slot shows by its icon, for inventory-hud's strip tests once every item has an
## icon (design.md K5): the id of the item whose sprite is the slot's icon texture, "" while the
## icon is hidden (an empty slot, or an item drawn as its three letters) or for no slot.


static func item_shown(view: StripSlot) -> String:
	if view == null or not view.icon.visible or view.icon.texture == null:
		return ""
	for id: StringName in GameState.content.list_ids(&"items"):
		var item := GameState.content.get_entry(&"items", id) as ItemData
		if item != null and item.sprite == view.icon.texture:
			return String(id)
	return "no item's icon: %s" % view.icon.texture.resource_path
