extends RefCounted
# Kanonicky hash stavu (docs/04 §4.2 a §4.7): SHA-256 z kanonicke serializace.
#
# Pravidla, bez kterych by determinismus nefungoval (docs/02 §2.3):
#   * klice slovniku se radi podle textove podoby, ne podle poradi vlozeni,
#   * pole zustavaji v poradi (poradi je soucast stavu),
#   * cisla jen jako int (float ve stavu je drift - viz nize),
#   * stejny stav => stejny hash, jiny stav => jiny hash.

func of_state(parts: Array) -> String:
	return _canonical(parts).sha256_text()


func _canonical(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var keys: Array = dict.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			var pairs: Array[String] = []
			for k in keys:
				pairs.append(str(k) + "=" + _canonical(dict[k]))
			return "{" + ",".join(pairs) + "}"
		TYPE_ARRAY:
			var items: Array[String] = []
			for v in (value as Array):
				items.append(_canonical(v))
			return "[" + ",".join(items) + "]"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			# Float ve stavu je vada (docs/09 §9.10 bod 3). Hash ho musi zpracovat
			# deterministicky, aby se vada dala najit - ne aby shodila beh.
			return "f:" + str(roundi(float(value) * 1000000.0))
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"" + str(value) + "\""
		TYPE_NIL:
			return "null"
		_:
			return str(value)
