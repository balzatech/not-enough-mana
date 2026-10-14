class_name UiNav
extends RefCounted
## Navegación entre pantallas y paso de datos (sin autoloads).
##
## `session_factory`: Callable(setup: Dictionary) -> GameSession, con `setup` =
## salida de LocalSetup (players + config). Si no se asigna, se usa
## LocalSession.from_setup (partida local real: hot-seat + bots).
## `replay_handler`: Callable(tree) para "Jugar otra vez" en la pantalla de fin
## de partida (start_local lo fija con la misma configuración; la sesión en
## línea puede poner el suyo o dejarlo vacío para ocultar el botón).

const MAIN_MENU: String = "res://src/ui/screens/main_menu.tscn"
const LOCAL_SETUP: String = "res://src/ui/screens/local_setup.tscn"
const LOBBY: String = "res://src/ui/screens/lobby.tscn"
const SETTINGS: String = "res://src/ui/screens/settings.tscn"
const HELP: String = "res://src/ui/screens/help_screen.tscn"
const TABLE: String = "res://src/ui/screens/table.tscn"

static var session_factory: Callable = Callable()
static var pending_session: GameSession = null
static var pending_lobby: Dictionary = {}
static var last_setup: Dictionary = {}
static var replay_handler: Callable = Callable()


static func go(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file(path)


static func open_main_menu(tree: SceneTree) -> void:
	replay_handler = Callable()
	go(tree, MAIN_MENU)


## Crea la sesión local a partir de la configuración y abre la mesa.
static func start_local(tree: SceneTree, setup: Dictionary) -> void:
	last_setup = setup.duplicate(true)
	replay_handler = _replay_local
	pending_session = make_local_session(setup)
	go(tree, TABLE)


## "Jugar otra vez": mismos jugadores y opciones, semilla nueva (siempre distinta de la anterior).
static func _replay_local(tree: SceneTree) -> void:
	start_local(tree, replay_setup())


static func replay_setup() -> Dictionary:
	var setup: Dictionary = last_setup.duplicate(true)
	var old: int = int(setup.get("seed", -1))
	var sd: int = randi() & 0x7fffffff
	if sd == old:
		sd = (sd + 1) & 0x7fffffff
	setup["seed"] = sd
	return setup


static func can_replay() -> bool:
	return replay_handler.is_valid()


static func replay(tree: SceneTree) -> void:
	if replay_handler.is_valid():
		replay_handler.call(tree)


static func make_local_session(setup: Dictionary) -> GameSession:
	if session_factory.is_valid():
		return session_factory.call(setup) as GameSession
	var gs: GameSession = LocalSession.from_setup(setup)
	if gs is LocalSession:
		# Una preferencia por dispositivo (hot-seat incluido); la sesión sola usa "all".
		(gs as LocalSession).reaction_notify = Settings.load_reaction_notify()
	return gs


## Sesión de maqueta (FakeSession) con los jugadores de `setup` (solo pruebas).
static func make_fake_session(setup: Dictionary) -> GameSession:
	var plist: Array = setup.get("players", []) as Array
	var state: Dictionary = FakeState.make_state(plist.size())
	var ids: Array[String] = []
	for i: int in plist.size():
		var pd: Dictionary = plist[i]
		var p: Dictionary = (state["players"] as Array)[i]
		p["name"] = String(pd.get("name", p["name"]))
		p["age"] = int(pd.get("age", 30))
		p["birth_month"] = int(pd.get("birth_month", 1))
		p["is_bot"] = bool(pd.get("is_bot", false))
		p["eliminated"] = false
		p["connected"] = true
		(p["flags"] as Dictionary)["frozen"] = 0
		if not bool(p["is_bot"]):
			ids.append(String(p["id"]))
	var cfg: Dictionary = state["config"]
	for k: Variant in (setup.get("config", {}) as Dictionary):
		cfg[k] = (setup["config"] as Dictionary)[k]
	return FakeSession.create(state, ids)
