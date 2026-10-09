extends RefCounted
# Stavba seznamu PO CASTECH (2026-10-09, faze 1 bod 5.5).
#
# ZADANI UZIVATELE: "Zaseky pri chuzi (dnes 2 framy z ~2 300 na ~130 ms)".
#
# NAMERENO (`_analyza/p29-zasek.gd`): spike 145,6 ms padl PRESNE ve framu, kdy
# `prestaveb` stouplo z 1 na 2 - tedy blokujici `render.chunk_renderer` stavba
# seznamu. Atlas to NENI (`hold 0`, `ceka 0`). Rozpad stavby: grid ~21-33 ms,
# land ~59-61, statiky ~53-56, klice ~46, celkem **179-199 ms**.
#
# RESENI: stavba se dela PO CASTECH (jako davka v `render.chunk_mesh`): dokud
# neni hotova, vrati `visible()` STARY seznam, takze se nikdy nekresli neuplny
# seznam s dirami. `visible(..., rozpocet_ms)` ma rozpocet; `-1` = synchronne
# (testy a sondy), `>= 0` = po castech (hra si to zapina v `app/main`).
#
# CO SE MERI (chovani, ne pritomnost):
#   1. s rozpoctem prvni volani NEDODA hotovy seznam (stavi se),
#   2. stavba se posouva po krocich a NAKONEC dobehne,
#   3. HOTOVY SEZNAM PO CASTECH JE STEJNY jako synchronni (`-1`) - jinak by se
#      hra a testy rozesly v tom, co se kresli,
#   4. rozpocet plati na CELY frame: druhe volani v tomtez framu uz neposune
#      `stavba_kroku` (jinak by se rozpocet nasobil poctem volani `_list()`),
#   5. `-1` postavi seznam v JEDNOM volani (synchronni cesta).

const ITEM_OFFSET := 0x4000
const CHUNK_SCRIPT := "res://render/chunk_renderer.gd"


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.substr(name.length() + 3)
	return fallback


class FakeMap:
	var podle_dlazdice: Dictionary = {}
	var land_tile: int = 3

	func statics_at(bx: int, by: int) -> Array:
		var out: Array = []
		for dx in 8:
			for dy in 8:
				var klic := Vector2i(bx + dx, by + dy)
				if not podle_dlazdice.has(klic):
					continue
				for s in podle_dlazdice[klic]:
					out.append({"x": dx, "y": dy,
						"tile": int(s["art"]) - ITEM_OFFSET, "z": int(s["z"])})
		return out

	func land_at(_x: int, _y: int) -> int:
		return land_tile

	func z_at(x: int, y: int) -> int:
		return (x + y) % 5          # vyska se meni, aby mrizka nebyla konstantni


class FakeTextures:
	func offset(_art_id: int) -> Vector2i:
		return Vector2i.ZERO


class FakeTiledata:
	func flags(_art_id: int) -> int:
		return 0

	func height(_art_id: int) -> int:
		return 0

	func texture(tile: int) -> int:
		return tile


func _sestav(stranky: int = 8) -> Array:
	var skript = load(_arg("chunk-script", CHUNK_SCRIPT))
	if skript == null:
		return []
	var mapa := FakeMap.new()
	# Par statiku, aby stavba mela i fazi statiku (a ne jen land).
	for i in 20:
		mapa.podle_dlazdice[Vector2i(10 + i, 10)] = [{"art": ITEM_OFFSET + 100 + i, "z": 0}]
	return [skript.new(mapa, FakeTextures.new(), FakeTiledata.new()), mapa]


func _otisk(seznam: Array) -> String:
	# Otisk obsahu seznamu (druh + souradnice + art), aby se daly dve cesty
	# porovnat CELE, ne jen poctem.
	var casti: Array = []
	for obj in seznam:
		casti.append("%s@%d,%d,%d:%d" % [str(obj["kind"]), int(obj["x"]), int(obj["y"]),
			int(obj["z"]), int(obj["art_id"])])
	casti.sort()
	return str(casti.size()) + "|" + ",".join(casti)


func run(t) -> void:
	var s: Array = _sestav()
	if s.is_empty():
		t._pending("render.chunk NENI HOTOV: " + CHUNK_SCRIPT)
		return
	var chunk = s[0]
	var stred := Vector2i(14, 14)
	var stranky := 12

	# 3) REFERENCNI (synchronni) seznam na TÉŽE oblasti - s cim se porovnava.
	var sync = _sestav()[0]
	var seznam_sync: Array = sync.visible(stred, stranky, stranky)
	t._check(seznam_sync.size() > 0, "render.chunk: synchronni stavba neco postavi (%d objektu)"
		% seznam_sync.size())

	# 1) S rozpoctem prvni volani HOTOVO NEDODA (stavi se).
	var prvni: Array = chunk.visible(stred, stranky, stranky, 0.0)
	t._check(prvni.is_empty() and chunk.stavba_seznamu(),
		"render.chunk: s rozpoctem se prvni volani jen ROZJEDE (objektu %d, stavi %s)"
			% [prvni.size(), str(chunk.stavba_seznamu())])

	# 4) Rozpocet plati na CELY frame: druhe volani v tomtez framu neposune.
	var kroku_pred: int = chunk.stavba_kroku
	chunk.visible(stred, stranky, stranky, 0.0)
	t._check(chunk.stavba_kroku == kroku_pred,
		"render.chunk: druhe volani v tomtez framu stavbu neposune (kroku %d, bylo %d)"
			% [chunk.stavba_kroku, kroku_pred])

	# 2) Stavba dobehne - a seznam se objevi. Kroky se pocitaji, aby bylo videt,
	#    ze se opravdu deli (ne ze se postavi v jednom volani).
	var volani: int = 0
	while chunk.stavba_seznamu() and volani < 5000:
		volani += 1
		chunk.visible(stred, stranky, stranky, 0.0)
		# Ramec posouvame rucne: rozpocet plati na frame, a test zadny frame nema.
		chunk._krok_frame = -1
	t._check(not chunk.stavba_seznamu() and volani > 1,
		"render.chunk: stavba se deli na kroky a dobehne (volani %d)" % volani)
	var po_castech: Array = chunk.visible(stred, stranky, stranky, 0.0)

	# 3) STEJNY VYSLEDEK jako synchronni cesta.
	t._check(_otisk(po_castech) == _otisk(seznam_sync),
		"render.chunk: seznam po castech je STEJNY jako synchronni (deleny %d, sync %d objektu)"
			% [po_castech.size(), seznam_sync.size()])

	# 5) `-1` = synchronne v JEDNOM volani.
	var sync2 = _sestav()[0]
	var hned: Array = sync2.visible(Vector2i(14, 14), stranky, stranky, -1.0)
	t._check(not sync2.stavba_seznamu() and hned.size() == seznam_sync.size(),
		"render.chunk: s rozpoctem -1 se postavi hned (%d objektu, stavi %s)"
			% [hned.size(), str(sync2.stavba_seznamu())])
