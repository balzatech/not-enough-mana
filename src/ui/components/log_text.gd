class_name LogText
extends RefCounted
## Texto de una entrada del log (Types.make_log_entry). Los textos viven en Strings.

const NAME_COLOR: String = "#f5c242"


static func card_name(card_id: String) -> String:
	return Strings.card_name(card_id)


static func format(entry: Dictionary, names: Dictionary) -> String:
	return Strings.log_text(entry, names)


## BBCode con los nombres de mago resaltados (el resto del texto se escapa).
static func highlight(text: String, names: Dictionary) -> String:
	var found: Array[String] = []
	for v: Variant in names.values():
		var n: String = String(v)
		if n != "" and not found.has(n):
			found.append(n)
	found.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out: String = ""
	var i: int = 0
	while i < text.length():
		var hit: String = ""
		for n: String in found:
			if text.substr(i, n.length()) == n:
				hit = n
				break
		if hit != "":
			out += "[color=%s][b]%s[/b][/color]" % [NAME_COLOR, _esc(hit)]
			i += hit.length()
		else:
			out += _esc(text[i])
			i += 1
	return out


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
