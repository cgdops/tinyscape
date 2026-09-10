# TinyScape — Item Icon Generator (Off-screen SubViewport Render & Cache)
class_name IconGenerator
extends RefCounted

static var _cache: Dictionary = {}

static func get_icon_texture(viewport_owner: Node, item_type: String) -> Texture2D:
	if _cache.has(item_type):
		return _cache[item_type]

	var model_path: String = "res://assets/models/woodcutting/CutLog.glb"
	if item_type.ends_with("_stump"):
		model_path = "res://assets/models/woodcutting/%s.glb" % item_type.capitalize().replace(" ", "")
	elif item_type == "mabb_axe":
		model_path = "res://assets/models/villagers/MabbFellingAxe.glb"

	if not ResourceLoader.exists(model_path):
		var fallback = _generate_fallback_texture()
		_cache[item_type] = fallback
		return fallback

	var packed = load(model_path) as PackedScene
	if packed == null:
		var fallback = _generate_fallback_texture()
		_cache[item_type] = fallback
		return fallback

	var tex = _render_model_to_texture(viewport_owner, packed)
	if tex != null:
		_cache[item_type] = tex
		return tex

	var fallback = _generate_fallback_texture()
	_cache[item_type] = fallback
	return fallback

static func _render_model_to_texture(owner_node: Node, packed_model: PackedScene) -> Texture2D:
	var vp = SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner_node.add_child(vp)

	var root_3d = Node3D.new()
	vp.add_child(root_3d)

	var model_inst = packed_model.instantiate()
	root_3d.add_child(model_inst)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_color = Color("fff0cc")
	light.light_energy = 1.0
	root_3d.add_child(light)

	var ambient = DirectionalLight3D.new()
	ambient.rotation_degrees = Vector3(45, -145, 0)
	ambient.light_color = Color("d5e4d1")
	ambient.light_energy = 0.45
	root_3d.add_child(ambient)

	var camera = Camera3D.new()
	camera.fov = 30.0
	root_3d.add_child(camera)

	# Check for IconAnchor node per A1 specification
	var icon_anchor = model_inst.find_child("IconAnchor", true, false) as Node3D
	if icon_anchor:
		camera.global_transform = icon_anchor.global_transform
	else:
		# Fallback 3/4 front-above view showing cut face and length
		model_inst.rotation_degrees = Vector3(18, -42, 12)
		camera.position = Vector3(0.0, 0.12, 0.95)

	# In headless or offscreen, grab texture or image
	var texture: ImageTexture = null
	if DisplayServer.get_name() != "headless":
		var vp_tex = vp.get_texture()
		if vp_tex != null:
			var img = vp_tex.get_image()
			if img != null and not img.is_empty():
				texture = ImageTexture.create_from_image(img)

	if texture == null:
		texture = _generate_fallback_texture()

	vp.queue_free()
	return texture

static func _generate_fallback_texture() -> Texture2D:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var log_color = Color("ab8653")
	var end_color = Color("d4b16d")
	for y in range(40, 88):
		for x in range(30, 98):
			if x > 78:
				img.set_pixel(x, y, end_color)
			else:
				img.set_pixel(x, y, log_color)
	return ImageTexture.create_from_image(img)
