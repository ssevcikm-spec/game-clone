extends RefCounted
# ui.debug_overlay - debug info na obrazovku (2026-10-09).
#
# Zadani uzivatele: "Navrhuji pridat informaci o lokaci, kde screenshot fotim,
# pripadne jakoukoliv dalsi debug informace ... Staci mozna vlepit na obrazovku
# at se to zachyti se screenshotem."
#
# Co se meri (a proc):
#   1. PRESNY text pro ZNAMY vstup - kdyby se format tise zmenil, screenshot
#      z minule session by se nedal porovnat s dnesnim,
#   2. chybejici hodnoty: text se nesmi rozbit a "nevim" musi byt VIDET
#      ("(?)"), ne jako namERena nula,
#   3. `toggle()` vraci NOVY stav (volajici ho hlasi do konzole),
#   4. ⚠ overlay je VIDITELNY od startu (ma se zachytit se screenshotem),
#   5. ⚠⚠ `mouse_filter = MOUSE_FILTER_IGNORE` na overlayi I na dilech - `Control`
#      ma ve Godotu vychozi STOP, takze by prekryl klikani do sveta pod sebou.

const Lib = preload("res://tests/lib.gd")
const OverlayScript = preload("res://ui/debug_overlay.gd")

const ZNAMY := {
	"loc": "Britain", "x": 1495, "y": 1629, "z": 10, "dir": 7,
	"win": "1280x720", "zoom": 0.75, "pick": Vector2(480, 300),
	"hp": 87, "hp_max": 87, "stam": 130, "stam_max": 130,
	"mana": 20, "mana_max": 20, "weight": 0, "gold": 0,
	"anim": "run", "anim_frame": 3, "anim_count": 10,
	"step_run": true, "step_elapsed_ms": 165, "step_delay_ms": 200,
	"fps": 60.0, "frame_ms": 16.6, "peak_ms": 132.0,
	"drawn": 8216, "holes": 0, "tiles": Vector2i(59, 33), "map": "7168x4096",
}
const ZNAMY_TEXT := "loc: Britain x=1495 y=1629 z=10 dir=7 | win=1280x720 zoom=0.75 | pick=(480,300)\n" \
	+ "state: hp=87/87 stam=130/130 mana=20/20 weight=0 gold=0 | anim=run f=3/10 | step=run 165/200ms\n" \
	+ "gfx: fps=60.0 frame=16.60ms peak=132ms drawn=8216 holes=0 | tiles=(59,33) | map=7168x4096"


func run(t) -> void:
	var overlay = OverlayScript.new()
	if overlay == null:
		t._pending("ui.debug_overlay NENI HOTOVA: ui/debug_overlay.gd chybi")
		return

	# 1) Presny text pro znami vstup.
	var text: String = overlay.text_for(ZNAMY)
	t._check(text == ZNAMY_TEXT,
		"ui.debug_overlay: text pro znami vstup sedi (namEReno:\n%s)" % text)

	# 2) Prazdny vstup: nesmi spadnout a "nevim" je videt.
	var prazdny: String = overlay.text_for({})
	t._check(prazdny.contains("pick=(?)"),
		"ui.debug_overlay: nezmereny stred je '(?)', ne (0,0) (namEReno %s)" % prazdny)
	t._check(prazdny.contains("tiles=(?)"),
		"ui.debug_overlay: nezmereny pocet dlazdic je '(?)' (namEReno %s)" % prazdny)
	t._check(prazdny.contains("anim=? f=0/0"),
		"ui.debug_overlay: nezmerena animace je '?' (namEReno %s)" % prazdny)
	t._check(prazdny.contains("step=idle"),
		"ui.debug_overlay: bez kroku je 'idle' (namEReno %s)" % prazdny)

	# 3) Text nebo null v cisle nesmi shodit UI (vzor ui.status_bar).
	var vadny: String = overlay.text_for({"x": "abc", "stam": null, "zoom": "nope"})
	t._check(vadny.contains("x=0") and vadny.contains("zoom=0.00"),
		"ui.debug_overlay: necitelna hodnota je 0 (namEReno %s)" % vadny)

	# 4) VIDITELNY od startu + F3 ho prepina (a vraci novy stav).
	t._check(overlay.visible == true,
		"ui.debug_overlay: overlay je viditelny od startu (kvuli screenshotu)")
	var po: bool = bool(overlay.toggle())
	t._check(po == false and overlay.visible == false,
		"ui.debug_overlay: toggle() schova a vraci novy stav (vratil %s)" % str(po))
	po = bool(overlay.toggle())
	t._check(po == true and overlay.visible == true,
		"ui.debug_overlay: druhy toggle() zapne (vratil %s)" % str(po))

	# 5) ⚠ MYS: overlay NESMI prekryt klikani do sveta (vychozi `MOUSE_FILTER_STOP`
	#    by presne to udelal - hra by "nereagovala na mys" pod textem).
	overlay.update(ZNAMY)
	t._check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"ui.debug_overlay: overlay ma MOUSE_FILTER_IGNORE (namEReno %d)" % overlay.mouse_filter)
	var dily_ok: bool = true
	for dite in overlay.get_children():
		if dite is Control and dite.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			dily_ok = false
	t._check(dily_ok, "ui.debug_overlay: i dily overlaye maji MOUSE_FILTER_IGNORE")

	# 6) Po `update` je text v Labelu (ne jen v navratove hodnote) - jinak by
	#    se na obrazovce neobjevil nic a test by to nepoznal.
	t._check(overlay.label != null and overlay.label.text == ZNAMY_TEXT,
		"ui.debug_overlay: update() zapise text do Labelu")

	# 7) Klic `F3` je zavedeny v klientovi (jinak by overlay nesel vypnout).
	var src: String = Lib.text_at("res://app/player_controller.gd")
	t._check(src.contains("\"debug_overlay_toggle\": [KEY_F3]"),
		"app.player_controller: F3 je v UI_KEYS na 'debug_overlay_toggle'")
