class_name RaftJob
extends BuildSite
## A mend or a fitting being worked on a raft (island-stop "Raft jobs are shared"): a build site on
## the raft's work point, at the same path on every peer (`Raft/Job`). Anyone deposits its inputs
## and works it as at any build site, and its deposits and progress reach every peer the way a
## level site's do. It never becomes a structure: when the work is done the host tells the raft
## (`Raft.finish_job`), which mends or fits itself and closes the job everywhere; a client's copy
## only marks itself done and waits for the raft's state. The host remembers who deposited what, so
## a launch can give it back (`Raft.end_job`).

## The raft this job is on.
var raft: Raft = null
# Host: one entry per item moved in, {body, id, count}.
var _given: Array[Dictionary] = []


## Moves matching inputs from the player's inventory into the job and remembers them as theirs;
## returns the units moved.
func deposit(player: PlayerBody) -> int:
	var moved: int = 0
	for id: StringName in recipe.inputs:
		var take: int = mini(recipe.inputs[id] - deposited.get(id, 0), player.inventory.count_id(id))
		if take > 0 and player.inventory.remove_id(id, take):
			deposited[id] = deposited.get(id, 0) + take
			_given.append({"body": player, "id": id, "count": take})
			moved += take
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var need: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		var taken: Array[StringName] = player.inventory.take_tag(tag, need)
		tags_deposited[tag] = tags_deposited.get(tag, 0) + taken.size()
		for id: StringName in taken:
			_given.append({"body": player, "id": id, "count": 1})
		moved += taken.size()
	if moved > 0:
		_push_state()
	return moved


## Host: what each player put in, {body, id, count} per deposit.
func given() -> Array[Dictionary]:
	return _given


# Done: the host pushes it as built and has the raft take the result; a client's copy waits for the
# raft's state, which closes it.
func _complete() -> void:
	_mark_built()
	if not multiplayer.is_server():
		return
	_push_state()
	if is_instance_valid(raft):
		raft.finish_job(recipe)
