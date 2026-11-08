class_name RescuePoint
extends Interactable
## What riders hold interact on during a crossing. A LASH is the raft's lashing (riders aboard tie
## down or untie). A CLIMB point sits at the deck edge nearest a swimmer and only that swimmer may
## use it; a PULL handle sits on the swimmer and only another rider aboard may use it (crossing
## "Rescue timing"). The crossing moves each one and enables it while it applies.

enum Kind {
	LASH,
	CLIMB,
	PULL,
}

var kind: Kind = Kind.CLIMB
## Peer id of the swimmer this point belongs to.
var swimmer: int = 0
var crossing: Crossing


func usable_by(by: Node) -> bool:
	if not is_instance_valid(crossing) or not by is PlayerBody:
		return false
	var user: int = crossing.peer_of(by as PlayerBody)
	if kind == Kind.CLIMB:
		return user == swimmer
	var aboard: bool = crossing.rider_state(user) == Crossing.Rider.ABOARD or crossing.rider_state(user) == Crossing.Rider.TIED
	return aboard and (kind == Kind.LASH or user != swimmer)


## The HUD prompt (inventory-hud design D4): the lashing reads tie down or untie by the user's own
## state, a climb point "climb aboard", a pull handle "pull" and the swimmer's name.
func prompt_id_for(by: Node) -> StringName:
	match kind:
		Kind.LASH:
			var tied: bool = is_instance_valid(crossing) and by is PlayerBody \
				and crossing.rider_state(crossing.peer_of(by as PlayerBody)) == Crossing.Rider.TIED
			return &"untie" if tied else &"tie_down"
		Kind.PULL:
			return &"pull"
		_:
			return &"climb_aboard"


func prompt_target(_by: Node, _locale: String) -> String:
	var session := CoopSession.of(crossing) if is_instance_valid(crossing) else null
	if kind != Kind.PULL or session == null:
		return ""
	return session.player_name(swimmer)
