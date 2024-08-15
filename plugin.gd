@tool
extends EditorPlugin

const preview_scene = preload("res://addons/m_terrain_minimap/preview.tscn")

var preview: MTerrain_Minimap
var current_main_screen_name: String

func _enter_tree() -> void:
	main_screen_changed.connect(_on_main_screen_changed)
	EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
	
	# Initialise preview panel and add to main screen.
	preview = preview_scene.instantiate() as MTerrain_Minimap
	preview.request_hide()
	
	var main_screen = EditorInterface.get_editor_main_screen()
	main_screen.add_child(preview)
	
func _exit_tree() -> void:
	if preview:
		preview.queue_free()
		
func _ready() -> void:
	# TODO: Currently there is no API to get the main screen name without 
	# listening to the `EditorPlugin.main_screen_changed` signal:
	# https://github.com/godotengine/godot-proposals/issues/2081
	EditorInterface.set_main_screen_editor("Script")
	EditorInterface.set_main_screen_editor("3D")
	
func _on_main_screen_changed(screen_name: String) -> void:
	current_main_screen_name = screen_name
	
	 # TODO: Bit of a hack to prevent pinned staying between view changes on the same scene.
	#preview.unlink_mterrain()
	_on_editor_selection_changed()

func _on_editor_selection_changed() -> void:
	if not is_instance_valid(EditorInterface.get_edited_scene_root()): return
	if not is_main_screen_viewport():
		# This hides the preview "container" and not the preview itself, allowing
		# any locked previews to remain visible once switching back to 3D tab.
		preview.visible = false
		return
	
	if not EditorInterface.is_plugin_enabled("m_terrain"):
		preview.visible = false
		return
	
	preview.visible = true
	
	#var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	var selected_mterrain: MTerrain
	var all_nodes = EditorInterface.get_edited_scene_root().find_children("*")
	for node in all_nodes:
		if node is MTerrain:
			selected_mterrain = node
			break

	if selected_mterrain and current_main_screen_name == "3D":				
		var cam = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		preview.link_with_mterrain(selected_mterrain, cam)
		preview.request_show()
	else:
		preview.request_hide()
	
func is_main_screen_viewport() -> bool:
	return current_main_screen_name == "3D" or current_main_screen_name == "2D"

func _on_selected_camera_3d_tree_exiting() -> void:
	preview.unlink_camera()
