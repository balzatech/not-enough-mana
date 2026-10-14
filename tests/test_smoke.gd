extends GutTest
## Test de humo: GUT funciona, la configuración del proyecto es la esperada y
## todos los scripts de src/ compilan.


func test_gut_runs() -> void:
	assert_true(true, "GUT ejecuta tests")


func test_project_settings() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Not Enough Mana")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1)


func test_all_src_scripts_compile() -> void:
	var paths: Array[String] = []
	_collect("res://src", paths)
	assert_gt(paths.size(), 20, "se encontraron scripts en src/")
	for p: String in paths:
		var s: GDScript = load(p)
		assert_not_null(s, "carga " + p)
		if s != null:
			assert_true(s.can_instantiate(), "compila " + p)


func _collect(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
