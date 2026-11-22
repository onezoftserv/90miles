class_name CaptureOutcome
extends RefCounted
## guardacostas-capture design.md §2 (main spec "Capture on the final crossing", spec "Capture
## outcome"): the one router every whole-party capture goes through. On an island, or in a crossing
## that is not the final one, `la_captura` plays and its persuasion check decides. During the final
## crossing the run ends with `devuelto` instead: no scene and no check. Nothing here builds that
## ending; the host's capture keeper emits `run_devuelto` for the final-crossing work to connect. The
## cutter on the first crossing and the final crossing's patrol will call the same router.

enum Route {
	## `la_captura` plays.
	SCENE,
	## The run ends with `devuelto`; no scene, no persuasion check.
	DEVUELTO,
}


## Where a whole-party capture goes: `final_crossing` is true while the party is in the final crossing.
static func resolve(final_crossing: bool) -> Route:
	return Route.DEVUELTO if final_crossing else Route.SCENE


## Whether the route rolls the persuasion check (only the scene does).
static func checks_persuasion(route: Route) -> bool:
	return route == Route.SCENE
