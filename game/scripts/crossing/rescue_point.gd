class_name RescuePoint
extends Interactable
## What riders hold interact on during a crossing. A LASH is the raft's lashing (riders aboard tie
## down or untie). A CLIMB point sits at the deck edge nearest a swimmer and only that swimmer may
## use it; a PULL handle sits on the swimmer and only another rider aboard may use it (crossing
## "Rescue timing"). A PADDLE sits inside one edge of the deck (or beside one side of a board, for
## that board's rider only): holding it paddles that way until the button comes up (crossing
## "Paddling"). The crossing moves each one and enables it while it applies.

enum Kind {
	LASH,
	CLIMB,
	PULL,
	PADDLE,
}

var kind: Kind = Kind.CLIMB
## Peer id of the swimmer this point belongs to; for a board's paddle, the board's rider.
var swimmer: int = 0
## A paddle's side: CrossingSteer.WEST or CrossingSteer.EAST.
var side: int = 0
var crossing: Crossing


func usable_by(by: Node) -> bool:
	if not is_instance_valid(crossing) or not by is PlayerBody:
		return false
	var user: int = crossing.peer_of(by as PlayerBody)
	var state: Crossing.Rider = crossing.rider_state(user)
	match kind:
		Kind.CLIMB:
			return user == swimmer
		Kind.PADDLE:
			# Jobs aboard: an untied rider aboard; a board's paddles are its own rider's.
			return state == Crossing.Rider.ABOARD and (swimmer == 0 or user == swimmer)
	var aboard: bool = state == Crossing.Rider.ABOARD or state == Crossing.Rider.TIED
	return aboard and (kind == Kind.LASH or user != swimmer)


## A paddle paddles for as long as the button is held: letting go stops it.
func release(by: Node) -> void:
	if kind == Kind.PADDLE and is_instance_valid(crossing) and by is PlayerBody:
		crossing.stop_paddling(crossing.peer_of(by as PlayerBody))


## The HUD prompt (inventory-hud design D4): the lashing reads tie down or untie by the user's own
## state, a climb point "climb aboard", a pull handle "pull" and the swimmer's name, a paddle the
## way it paddles.
func prompt_id_for(by: Node) -> StringName:
	match kind:
		Kind.LASH:
			var tied: bool = is_instance_valid(crossing) and by is PlayerBody \
				and crossing.rider_state(crossing.peer_of(by as PlayerBody)) == Crossing.Rider.TIED
			return &"untie" if tied else &"tie_down"
		Kind.PULL:
			return &"pull"
		Kind.PADDLE:
			return &"paddle_east" if side == CrossingSteer.EAST else &"paddle_west"
		_:
			return &"climb_aboard"


func prompt_target(_by: Node, _locale: String) -> String:
	var session := CoopSession.of(crossing) if is_instance_valid(crossing) else null
	if kind != Kind.PULL or session == null:
		return ""
	return session.player_name(swimmer)


## A pull handle sits on its swimmer, so the prompt clears their name tag as over any player.
func prompt_player() -> Node2D:
	if kind != Kind.PULL or not is_instance_valid(crossing):
		return null
	return crossing.body_of(swimmer)
