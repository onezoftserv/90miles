extends GutHookScript
## GUT post-run hook (build-verification spec): GUT exits 0 when it collects no tests, so a
## renamed folder or a wrong .gutconfig.json would pass CI with nothing tested. Fail instead.


func run() -> void:
	var totals: Dictionary = gut.get_summary().get_totals()
	if int(totals.get("tests", 0)) == 0:
		printerr("GUT ran no tests: check \"dirs\" and \"prefix\" in game/.gutconfig.json.")
		set_exit_code(1)
