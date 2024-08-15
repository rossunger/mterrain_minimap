@tool
class_name MTerrain_Minimap extends Control

@onready var is_locked
@onready var lock_button = find_child("lock_button")
@onready var resize_handle = find_child("resize_handle")
@onready var locator = find_child("locator")
@onready var controls = find_child("controls")
@onready var minimap = find_child("minimap")

var mterrain: MTerrain
var mgrass: MGrass
var camera: Node3D

var is_resizing = false

var MIN_POSITION
var MAX_POSITION
var MARGIN = Vector2(20,10)
var aspect_ratio = 1
var position_offset = Vector2(0,0)

func _ready():
	resize_handle.button_down.connect(start_resizing)
	resize_handle.button_up.connect(stop_resizing)
	lock_button.toggled.connect(func(toggle_on): is_locked = toggle_on)
	minimap.mouse_entered.connect(func(): controls.visible = true)
	controls.mouse_exited.connect(func(): controls.visible = false)
	minimap.gui_input.connect(on_gui_input)

func _process(delta):
	if not mterrain or not camera or not locator: return
	var x_percent = camera.position.x / (mterrain.get_base_size() * mterrain.terrain_size.x)
	locator.position.x = clamp( minimap.position.x + x_percent * minimap.size.x - MARGIN.x, minimap.position.x-50, minimap.position.x + minimap.size.x) 				
	
	var y_percent = camera.position.z / (mterrain.get_base_size() * mterrain.terrain_size.y)
	locator.position.y = clamp( minimap.position.y + y_percent * minimap.size.y - MARGIN.y, minimap.position.y-30, minimap.position.y + minimap.size.y+10) 				
	
func start_resizing():
	MIN_POSITION = size * 0.75
	MAX_POSITION = size * 0.9
	if EditorInterface.is_plugin_enabled("m_terrain"):
		var mtools = get_tree().root.find_child("mtools_root", true, false)		
		if mtools and mtools.is_visible_in_tree():	
			position_offset.y = mtools.size.y		
		else:
			position_offset.y = 0
	is_resizing=true
	resize_handle.mouse_filter = MOUSE_FILTER_PASS
	lock_button.mouse_filter = MOUSE_FILTER_PASS

func stop_resizing():
	is_resizing=false
	resize_handle.mouse_filter = MOUSE_FILTER_STOP
	lock_button.mouse_filter = MOUSE_FILTER_STOP
	load_minimap()
	
func _input(event):
	if is_resizing and event is InputEventMouseMotion:
		var relative = clamp(minimap.position + event.relative, MIN_POSITION, MAX_POSITION) - minimap.position		
		minimap.position.x += relative.x
		minimap.size.x -= relative.x		
		minimap.size.y = minimap.size.x / aspect_ratio
		minimap.position.y = -minimap.size.y - MARGIN.y - position_offset.y

func on_gui_input(event):	
	if is_resizing: return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var x_percent = event.position.x / minimap.size.x
		camera.position.x = mterrain.get_base_size() * mterrain.terrain_size.x * x_percent
	
		var y_percent = event.position.y / minimap.size.y
		camera.position.z = mterrain.get_base_size() * mterrain.terrain_size.y * y_percent
		pass

func link_with_mterrain(new_mterrain: MTerrain, new_camera: Node3D):	
	mterrain = new_mterrain		
	camera = new_camera	
	load_minimap()
	
	aspect_ratio = mterrain.terrain_size.x / mterrain.terrain_size.y

func request_hide() -> void:
	if is_locked: return
	visible = false
	
func request_show() -> void:
	visible = true

func _on_lock_button_pressed() -> void:
	is_locked = !is_locked


func _enter_tree():
	clear()	

func _physics_process(delta):	
	if is_instance_valid(camera):
		locator.size = Vector2(clamp(size.x/20, 14, 30), clamp(size.y/20, 14,30))
		locator.pivot_offset = locator.size/2
		locator.position = Vector2((camera.position.x+4096)/8192 *size.x ,(camera.position.z+4096)/8192 * size.y) - locator.pivot_offset
		locator.rotation = -camera.rotation.y -PI/2
			
func load_minimap():		
	if not mterrain or not mterrain.is_grid_created(): return
	var img = Image.create(minimap.size.x, minimap.size.y, false, Image.FORMAT_RGB8)
	var height_range:Vector2 = detect_heightmap_range(mterrain)
	var x_percent = mterrain.terrain_size.x * mterrain.get_base_size() / minimap.size.x 
	var y_percent = mterrain.terrain_size.y * mterrain.get_base_size() / minimap.size.y
	for y in minimap.size.y-1:
		for x in minimap.size.x-1:			
			var h = (mterrain.get_height_by_pixel(floor(x*x_percent), floor(y*y_percent)) - height_range.x) / (height_range.y-height_range.x)
			img.set_pixel(x,y,  Color(h,h,h))
	minimap.texture = ImageTexture.create_from_image(img)
	
func clear():
	mterrain = null
	visible = false	
	mgrass = null

func detect_heightmap_range(active_terrain)->Vector2:
	assert(active_terrain)
	var first_path = active_terrain.dataDir.path_join("x0_y0.res")
	assert( ResourceLoader.exists(first_path))	
	var mres:MResource
	var mres_load = ResourceLoader.load(first_path)
	assert(mres_load and mres_load is MResource)		
	mres = mres_load
	var min_height:float=mres.get_min_height()
	var max_height:float=mres.get_max_height()
	var x:int=1
	var y:int=0
	while true:
		var path = active_terrain.dataDir.path_join("x"+str(x)+"_y"+str(y)+".res")
		if not ResourceLoader.exists(path):
			y+=1
			x=0
			path = active_terrain.dataDir.path_join("x"+str(x)+"_y"+str(y)+".res")
			if not ResourceLoader.exists(path):
				break
		x+=1
		mres_load = ResourceLoader.load(path)
		if not mres_load:
			continue
		if not (mres_load is MResource):
			continue
		mres = mres_load
		if min_height > mres.get_min_height():
			min_height = mres.get_min_height()
		if max_height < mres.get_max_height():
			max_height = mres.get_max_height()
	return Vector2(min_height, max_height)
