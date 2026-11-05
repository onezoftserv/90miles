class_name TestFs
extends RefCounted
## File helpers for tests that build throwaway content under user://.


## Deletes `path` and everything under it. Only user:// paths are allowed.
static func remove_tree(path: String) -> void:
	assert(path.begins_with("user://"), "remove_tree only deletes under user://")
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	for sub: String in dir.get_directories():
		remove_tree(path.path_join(sub))
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Saves `res` as `<root>/<folder>/<file_id>.tres`, creating folders as needed.
static func save_content(root: String, folder: String, file_id: String, res: Resource) -> Error:
	var dir_path: String = root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(dir_path)
	return ResourceSaver.save(res, dir_path.path_join(file_id + ".tres"))
