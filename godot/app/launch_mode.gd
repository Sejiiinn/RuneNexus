extends RefCounted
## Command-line launch flags. The formal app enters through boot.tscn, which
## marks its battlefield as the app explicitly; these defaults only decide what
## a battlefield created without boot does (development and checks).

## --session: development session with its own manual lifecycle.
static func development_session() -> bool:
	return "--session" in OS.get_cmdline_user_args()

## --fixture: fixed preview frame without any session.
static func fixture() -> bool:
	return "--fixture" in OS.get_cmdline_user_args()

## Default for a battlefield created without boot: the app unless a development
## flag is given or a check script (--script/-s) drives the scene tree.
static func default_app_mode() -> bool:
	if "--app" in OS.get_cmdline_user_args(): return true
	return not development_session() and not fixture() and not "--script" in OS.get_cmdline_args() and not "-s" in OS.get_cmdline_args()
