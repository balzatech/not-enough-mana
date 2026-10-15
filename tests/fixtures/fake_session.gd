class_name FakeSession
extends GameSession
## Sesión de maqueta para la UI (hasta que exista LocalSession): guarda las
## acciones recibidas y simula solo beber poción y fin de turno.

var state: Dictionary = {}
var submitted: Array[Dictionary] = []
var local_ids: Array[String] = []


static func create(p_state: Dictionary, p_local: Array[String]) -> FakeSession:
	var fs: FakeSession = FakeSession.new()
	fs.state = p_state
	fs.local_ids = p_local
	return fs


func submit_action(action: Dictionary) -> void:
	submitted.append(action)
	var pid: String = String(action.get("player", ""))
	match String(action.get("type", "")):
		Types.ACTION_DRINK_POTION:
			var p: Dictionary = Types.get_player(state, pid)
			if not p.is_empty():
				p["potions"] = int(p["potions"]) + 1
				p["mana"] = int(p["mana"]) + int((state["config"] as Dictionary)["potion_mana"])
		Types.ACTION_END_TURN:
			var ids: Array[String] = Types.alive_ids(state)
			var idx: int = ids.find(pid)
			if idx >= 0:
				var turn: Dictionary = state["turn"]
				turn["current"] = ids[(idx + 1) % ids.size()]
				turn["number"] = int(turn["number"]) + 1
		Types.ACTION_PASS_REACTION:
			state["reaction"] = {}
	state["rev"] = int(state["rev"]) + 1
	state_changed.emit(int(state["rev"]), [])


func get_view_for(player_id: String) -> Dictionary:
	return Types.view_for(state, player_id)


func get_local_player_ids() -> Array[String]:
	return local_ids


func get_rev() -> int:
	return int(state.get("rev", 0))


func is_authority() -> bool:
	return true
