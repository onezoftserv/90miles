class_name CreditChecks
extends RefCounted
## The credits checks of task 1.7 (art-pass "Credits list every pack used"; design.md D10, K15).
## Stub: every check passes until it is written.


static func is_cc_by(_licence: String) -> bool:
	return false


static func licence_texts_under(_root: String) -> Dictionary[String, String]:
	return {}


static func check_cc_by_credited(_licences: Dictionary[String, String], _credits: ArtCredits, _credits_md: String) -> PackedStringArray:
	return []


static func check_packs_credited(_licences: Dictionary[String, String], _credits: ArtCredits, _credits_md: String) -> PackedStringArray:
	return []


static func check_cc_by_entries(_credits: ArtCredits, _credits_md: String) -> PackedStringArray:
	return []
