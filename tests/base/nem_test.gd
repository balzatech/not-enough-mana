class_name NemTest
extends GutTest
## Base común de los tests de Not Enough Mana (V3-12, M4).
##
## Restaura, antes y después de cada test, el estado estático global que los tests
## pueden tocar: catálogo, registro de efectos, UiNav, UiUtil y CardInfo.
## CardInfo usa una ruta user:// propia de pruebas, nunca la de ajustes reales.
##
## Si el test hereda y define su propio before_each/after_each, debe llamar a
## super.before_each() / super.after_each().

const TEST_SETTINGS_PATH: String = "user://nem_test_settings.cfg"


func before_each() -> void:
	reset_statics()


func after_each() -> void:
	reset_statics()
	# Los nodos que la UI retira con queue_free() solo desaparecen al pasar un fotograma.
	await get_tree().process_frame


## Deja los estáticos como en un arranque limpio del juego (catálogo real incluido).
static func reset_statics() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	UiNav.session_factory = Callable()
	UiNav.pending_session = null
	UiNav.pending_lobby = {}
	UiNav.last_setup = {}
	UiNav.replay_handler = Callable()
	UiUtil.extra_defs = {}
	UiUtil.prefer_extra = false
	CardInfo.settings_path = TEST_SETTINGS_PATH
	CardInfo.summaries_path = CardInfo.SUMMARIES_PATH
	CardInfo._hint_seen_session = false
