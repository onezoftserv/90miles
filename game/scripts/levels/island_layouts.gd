class_name IslandLayouts
extends RefCounted
## The one listing of the handmade layouts a run may use as numbered islands (island-generation
## "Off-graph handmade layouts"): every layout in the catalog's islands folder except those marked
## off-graph, such as the secret cay. Whatever builds the run graph lists islands through here, so
## the off-graph rule lives in one place. With 1 player it lists the same.


static func numbered(catalog: ContentCatalog) -> Array[IslandLayoutData]:
	var listed: Array[IslandLayoutData] = []
	for id: StringName in catalog.list_ids(&"islands"):
		var layout := catalog.get_entry(&"islands", id) as IslandLayoutData
		if layout != null and not layout.off_graph:
			listed.append(layout)
	return listed
