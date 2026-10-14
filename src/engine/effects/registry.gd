class_name EffectRegistry
extends RefCounted
## Registro id de carta -> efecto (Callable). Parte del contrato T1.
##
## Firma de TODO efecto:
##     static func mi_carta(state: Dictionary, ctx: Dictionary) -> Dictionary
## - `state` es la copia de trabajo del reducer: se puede mutar y se devuelve.
## - `ctx` = Types.make_effect_ctx(): card, def, caster, targets, payment, extra,
##   spell, is_response, action, error, events.
## - Para abortar: ctx["error"] = Types.ERR_*; el reducer descarta los cambios.
## - Para informar: ctx["events"].append(Types.make_log_entry(...)).
##
## Hooks extra (Types.HOOK_*) con la MISMA firma (state, ctx) -> Dictionary.
## Handlers de modificadores (Types.OP_CUSTOM):
##     static func h(state: Dictionary, mod: Dictionary, event: Dictionary) -> Dictionary
##   devuelven el evento modificado (pueden mutar state, p. ej. quitar maná).
##
## REGLA DE TRABAJO EN PARALELO: cada agente solo descomenta/añade **una línea
## por carta suya** en _register_all(). No reordenes ni toques otras líneas.

static var _effects: Dictionary = {}           # card_id -> Callable
static var _hooks: Dictionary = {}             # hook -> {card_id -> Callable}
static var _modifier_handlers: Dictionary = {} # handler_id -> Callable
static var _initialized: bool = false


## Registra el efecto principal de una carta (al resolverse el hechizo, al
## equipar un artefacto, al entrar un evento…).
static func register(card_id: String, effect: Callable) -> void:
	_effects[card_id] = effect


## Registra un hook extra (Types.HOOK_*) para una carta.
static func register_hook(hook: String, card_id: String, fn: Callable) -> void:
	if not _hooks.has(hook):
		_hooks[hook] = {}
	(_hooks[hook] as Dictionary)[card_id] = fn


## Registra un handler para modificadores con op = OP_CUSTOM y handler = id.
static func register_modifier_handler(handler_id: String, fn: Callable) -> void:
	_modifier_handlers[handler_id] = fn


## Efecto principal; Callable() (inválido) si no hay ninguno registrado.
static func get_effect(card_id: String) -> Callable:
	_ensure_init()
	return _effects.get(card_id, Callable())


static func has_effect(card_id: String) -> bool:
	_ensure_init()
	return _effects.has(card_id)


static func get_hook(hook: String, card_id: String) -> Callable:
	_ensure_init()
	var h: Dictionary = _hooks.get(hook, {})
	return h.get(card_id, Callable())


static func get_modifier_handler(handler_id: String) -> Callable:
	_ensure_init()
	return _modifier_handlers.get(handler_id, Callable())


## Ids con efecto registrado (para T7 / QA).
static func registered_ids() -> Array[String]:
	_ensure_init()
	var out: Array[String] = []
	for k: Variant in _effects:
		out.append(String(k))
	return out


## Vacía y vuelve a cargar los registros (útil en tests tras registrar fakes).
static func reset() -> void:
	_effects.clear()
	_hooks.clear()
	_modifier_handlers.clear()
	_initialized = false
	_ensure_init()


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_register_all()


## UNA LÍNEA POR CARTA. Descomenta la tuya cuando exista la función.
## Para hooks/handlers añade también una línea por carta debajo de su bloque.
static func _register_all() -> void:
	# --- Fuego (T6a: src/engine/effects/fire.gd, class FireEffects) ---
	register(Types.CARD_FIRE_ARROW, FireEffects.fire_arrow)
	register(Types.CARD_FIREBALL, FireEffects.fireball)
	register(Types.CARD_METEOR_SHOWER, FireEffects.meteor_shower)
	register(Types.CARD_ARMAGEDDON, FireEffects.armageddon)
	register(Types.CARD_MANA_IMPLOSION, FireEffects.mana_implosion)

	# --- Hielo (T6a: ice.gd, class IceEffects) ---
	register(Types.CARD_ICE_BOLT, IceEffects.ice_bolt)
	register(Types.CARD_BLIZZARD, IceEffects.blizzard)
	register(Types.CARD_ICE_BOOMERANG, IceEffects.ice_boomerang)
	register(Types.CARD_VAMPIRIC_TOUCH, IceEffects.vampiric_touch)
	register(Types.CARD_FREEZE, IceEffects.freeze)
	register(Types.CARD_ICY_GRASP, IceEffects.icy_grasp)

	# --- Electricidad (T6a: electric.gd, class ElectricEffects) ---
	register(Types.CARD_LIGHTNING, ElectricEffects.lightning)
	register(Types.CARD_ELECTRIC_EXPLOSION, ElectricEffects.electric_explosion)
	register(Types.CARD_BLINDING_FLASH, ElectricEffects.blinding_flash)
	register(Types.CARD_ELECTRIC_ARC, ElectricEffects.electric_arc)
	register(Types.CARD_PARALYSING_TOUCH, ElectricEffects.paralysing_touch)

	# --- Defensivas (T6b: defensive.gd, class DefensiveEffects) ---
	register(Types.CARD_MAGIC_SHIELD, DefensiveEffects.magic_shield)
	register(Types.CARD_MIRROR_SHIELD, DefensiveEffects.mirror_shield)
	register(Types.CARD_FROZEN_BUNNY, DefensiveEffects.frozen_bunny)
	register(Types.CARD_LAST_WISH, DefensiveEffects.last_wish)
	register(Types.CARD_MAGIC_CAPTURE, DefensiveEffects.magic_capture)
	register(Types.CARD_ANNIHILATION, DefensiveEffects.annihilation)
	register(Types.CARD_FORCE_FIELD, DefensiveEffects.force_field)  # T6b: interactúa con la ventana

	# --- Soporte (T6c: support.gd, class SupportEffects) ---
	register(Types.CARD_HEAL, SupportEffects.heal)
	register(Types.CARD_GREATER_HEAL, SupportEffects.greater_heal)
	register(Types.CARD_BOOK_EXCHANGE, SupportEffects.book_exchange)
	register(Types.CARD_MAGIC_HAND, SupportEffects.magic_hand)
	# register(Types.CARD_FORCE_FIELD, SupportEffects.force_field)
	register(Types.CARD_POTENT_ELIXIR, SupportEffects.potent_elixir)
	register(Types.CARD_SPACE_SHIFT, SupportEffects.space_shift)

	# --- Maldiciones (T6c: curses.gd, class CurseEffects) ---
	register(Types.CARD_CURSE_OF_RULES, CurseEffects.curse_of_rules)
	register(Types.CARD_CURSE_OF_THE_ELDER, CurseEffects.curse_of_the_elder)
	register(Types.CARD_CURSE_OF_THE_YOUNGER, CurseEffects.curse_of_the_younger)
	register(Types.CARD_CURSE_OF_VIGOUR, CurseEffects.curse_of_vigour)
	register(Types.CARD_CURSE_OF_EVEN, CurseEffects.curse_of_even)
	register(Types.CARD_CURSE_OF_ODD, CurseEffects.curse_of_odd)

	# --- Artefactos (T6c: artifacts.gd, class ArtifactEffects) ---
	register(Types.CARD_FIREPROOF_TIARA, ArtifactEffects.fireproof_tiara)
	register(Types.CARD_PADDED_BOOTS, ArtifactEffects.padded_boots)
	register(Types.CARD_FARADAYS_CLOAK, ArtifactEffects.faradays_cloak)
	register(Types.CARD_WILD_FIRE, ArtifactEffects.wild_fire)
	register(Types.CARD_DRAGON_GLASS, ArtifactEffects.dragon_glass)
	register(Types.CARD_TESLA_COIL, ArtifactEffects.tesla_coil)
	register(Types.CARD_SPELLBOOK, ArtifactEffects.spellbook)
	register(Types.CARD_MAGIC_CAP, ArtifactEffects.magic_cap)
	register(Types.CARD_RUNIC_ARMOR, ArtifactEffects.runic_armor)
	register(Types.CARD_SCROLL_OF_ELEMENTS, ArtifactEffects.scroll_of_elements)
	register(Types.CARD_TRANSFORMATION_GLOVE, ArtifactEffects.transformation_glove)
	register(Types.CARD_TWARDOWSKYS_MIRROR, ArtifactEffects.twardowskys_mirror)

	# --- Eventos (T6c: events.gd, class EventEffects) ---
	register(Types.CARD_VISIT_OF_THE_ARCHMAGE, EventEffects.visit_of_the_archmage)
	register(Types.CARD_NOT_ENOUGH_MANA, EventEffects.not_enough_mana)
	register(Types.CARD_SHOT_GLASS, EventEffects.shot_glass)
	register(Types.CARD_FIRE_STORM, EventEffects.fire_storm)
	register(Types.CARD_ICE_STORM, EventEffects.ice_storm)
	register(Types.CARD_LIGHTNING_STORM, EventEffects.lightning_storm)
	register(Types.CARD_MANA_FOCUS, EventEffects.mana_focus)
	register(Types.CARD_DISRUPTED_GRAVITY, EventEffects.disrupted_gravity)
	register(Types.CARD_BLESSING, EventEffects.blessing)
	register(Types.CARD_WARP_DISCHARGE, EventEffects.warp_discharge)
	register(Types.CARD_ELIXIR_TRANSMUTATION, EventEffects.elixir_transmutation)

	# --- Hooks (una línea por carta y hook) ---
	register_hook(Types.HOOK_USE, Types.CARD_TRANSFORMATION_GLOVE, ArtifactEffects.use_transformation_glove)
	register_hook(Types.HOOK_USE, Types.CARD_TWARDOWSKYS_MIRROR, ArtifactEffects.use_twardowskys_mirror)
	register_hook(Types.HOOK_USE, Types.CARD_MAGIC_CAP, ArtifactEffects.use_magic_cap)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_ELIXIR_TRANSMUTATION, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_MANA_FOCUS, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_CAN_PLAY, Types.CARD_SPELLBOOK, ArtifactEffects.can_play_spellbook)
	register_hook(Types.HOOK_PROMPT, Types.CARD_MAGIC_CAP, ArtifactEffects.prompt_magic_cap)
	register_hook(Types.HOOK_PROMPT, Types.CARD_MAGIC_HAND, SupportEffects.prompt_magic_hand)
	register_hook(Types.HOOK_PROMPT, Types.CARD_MANA_FOCUS, EventEffects.prompt_mana_focus)
	register_hook(Types.HOOK_LEGAL_ACTIONS, Types.CARD_MAGIC_CAP, ArtifactEffects.legal_magic_cap)
	register_hook(Types.HOOK_LEGAL_ACTIONS, Types.CARD_MAGIC_HAND, SupportEffects.legal_magic_hand)
	register_hook(Types.HOOK_LEGAL_ACTIONS, Types.CARD_TRANSFORMATION_GLOVE, ArtifactEffects.legal_transformation_glove)
	register_hook(Types.HOOK_LEGAL_ACTIONS, Types.CARD_TWARDOWSKYS_MIRROR, ArtifactEffects.legal_twardowskys_mirror)
	register_hook(Types.HOOK_LEGAL_ACTIONS, Types.CARD_ELIXIR_TRANSMUTATION, EventEffects.legal_elixir_transmutation)
	register_hook(Types.HOOK_PAY_WILDCARD, Types.CARD_SCROLL_OF_ELEMENTS, ArtifactEffects.pay_scroll_of_elements)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_VISIT_OF_THE_ARCHMAGE, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_NOT_ENOUGH_MANA, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_SHOT_GLASS, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_FIRE_STORM, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_ICE_STORM, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_LIGHTNING_STORM, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_DISRUPTED_GRAVITY, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_BLESSING, EventEffects.use_event_prompt)
	register_hook(Types.HOOK_USE_EVENT, Types.CARD_WARP_DISCHARGE, EventEffects.use_event_prompt)
	register_hook(ElectricEffects.HOOK_CAN_RESPOND, Types.CARD_LIGHTNING, ElectricEffects.can_respond_lightning)

	# --- Handlers de modificadores OP_CUSTOM (una línea por handler) ---
	register_modifier_handler("not_enough_mana", EventEffects.mod_not_enough_mana)
	register_modifier_handler("mana_focus", EventEffects.mod_mana_focus)
	register_modifier_handler("magic_cap", ArtifactEffects.mod_magic_cap)
	register_modifier_handler("runic_armor", ArtifactEffects.mod_runic_armor)
	register_modifier_handler("last_wish", DefensiveEffects.mod_last_wish)
	pass
