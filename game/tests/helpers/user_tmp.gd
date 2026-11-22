class_name UserTmp
extends RefCounted
## Per-process scratch paths under user:// for tests. Godot's user:// folder is per project name,
## so every checkout of this repo on one machine (each worktree) shares it, and two GUT runs at
## once clobbered each other's fixed files and folders. Tests never name a user:// path
## themselves: each process writes only under user://test_tmp/<pid>/ and deletes only inside it.

const BASE: String = "user://test_tmp"

static var _cleared: bool = false


## `name` (a file or folder name owned by one suite, such as "test_lobby_screen_settings.cfg")
## inside this process's folder, which exists afterwards. The first call in a process empties
## a folder left by a killed run that had the same process id.
static func path(name: String) -> String:
	assert(not name.is_empty() and not name.contains("/") and not name.contains(".."), "one plain name: %s" % name)
	var root: String = own_root()
	if not _cleared:
		_cleared = true
		FsHelpers.remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)
	return root.path_join(name)


## This process's folder, user://test_tmp/<pid>.
static func own_root() -> String:
	return BASE.path_join(str(OS.get_process_id()))


## Deletes this process's folder (the post-run hook). Other runs' folders are never touched, not
## even stale ones: Godot cannot tell whether another process id is still running.
static func remove_own() -> void:
	FsHelpers.remove_tree(own_root())
