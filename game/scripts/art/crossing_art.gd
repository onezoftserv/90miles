class_name CrossingArt
extends RefCounted
## What the crossing's looks share (art-sprite-polish D2; art-mood-pass D7): pure reads of the
## crossing's synced state, the same on every peer. Drawing only; it never writes the crossing.


## The rects of `crossing`'s decks drawn now: each afloat board on a board route, else the shared
## deck while its vessel is intact (CrossingDeck and CrossingBoards draw on the same rule). Empty on
## a swim with no vessel and once the deck has sunk.
static func drawn_decks(crossing: Crossing) -> Array[Rect2]:
	var decks: Array[Rect2] = []
	if crossing == null or crossing.finished:
		return decks
	if crossing.is_board_route():
		for peer: int in crossing.boards:
			if (crossing.boards[peer] as VesselIntegrity).intact():
				decks.append(crossing.deck_rect_of(peer))
	elif crossing.integrity.intact():
		decks.append(crossing.deck_rect())
	return decks
