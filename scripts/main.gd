extends Node
## 화면 전환: 메뉴 ↔ 경기

var menu: Menu
var current_match: Match
var ui_layer: CanvasLayer
var _went_fullscreen := false


func _ready() -> void:
	UiKit.init_theme(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--mode="):
			Game.mode = a.substr(7)
		elif a.begins_with("--char="):
			Game.character = a.substr(7)
		elif a.begins_with("--map="):
			Game.map_id = a.substr(6)
	if args.has("--autoplay"):
		_start_match()
	elif args.has("--menu") or Array(args).any(func(a): return a.begins_with("--tab=")):
		_show_menu()
	else:
		_show_title()
	for a in args:
		if a.begins_with("--tab=") and menu:
			menu.call_deferred("_set_tab", a.substr(6))
		if a.begins_with("--shots="):
			_shots(a.substr(8))


## 디버그: --shots=경로접두:초,초,...  지정 시각마다 화면 저장 후 종료
func _shots(spec: String) -> void:
	var parts := spec.split(":")
	var prefix := parts[0]
	var times := parts[1].split(",")
	var prev := 0.0
	for i in times.size():
		var t := float(times[i])
		await get_tree().create_timer(t - prev, true, false, true).timeout
		prev = t
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, i])
	get_tree().quit()


var title: Control


func _show_title() -> void:
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.theme = UiKit.theme
	ui_layer.add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/keyart.jpg"):
		art.texture = load("res://assets/ui/keyart.jpg")
	title.add_child(art)
	var tap := UiKit.label("화면을 터치하면 시작!", 34, Color(1, 0.92, 0.6), true)
	tap.add_theme_color_override("font_outline_color", Color.BLACK)
	tap.add_theme_constant_override("outline_size", 10)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tap.offset_top = -110
	tap.offset_bottom = -50
	tap.offset_left = -400
	tap.offset_right = 400
	title.add_child(tap)
	var tw := tap.create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 0.35, 0.7)
	tw.tween_property(tap, "modulate:a", 1.0, 0.7)
	title.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and title:
			Sfx.play("go", -6.0)
			_go_fullscreen()
			title.queue_free()
			title = null
			_show_menu())


func _show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = Menu.new()
	ui_layer.add_child(menu)
	menu.play_requested.connect(_start_match)


func _start_match() -> void:
	_go_fullscreen()
	if menu:
		menu.queue_free()
		menu = null
	if current_match:
		current_match.queue_free()
	current_match = Match.new()
	current_match.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(current_match)
	current_match.finished.connect(_on_finished)
	current_match.start(Game.mode, Game.map_id)


func _on_finished(res: Dictionary) -> void:
	get_tree().paused = false
	var again: bool = res.get("again", false)
	current_match.queue_free()
	current_match = null
	await get_tree().process_frame
	if again:
		_start_match()
	else:
		_show_menu()


func _go_fullscreen() -> void:
	if _went_fullscreen or not OS.has_feature("web"):
		return
	_went_fullscreen = true
	if Game.is_touch:
		JavaScriptBridge.eval("""
			(function(){
				var d=document.documentElement;
				var p=(d.requestFullscreen||d.webkitRequestFullscreen);
				if(p){ try{ var r=p.call(d); if(r&&r.then){ r.then(function(){ if(screen.orientation&&screen.orientation.lock){ screen.orientation.lock('landscape').catch(function(){}); } }).catch(function(){}); } }catch(e){} }
			})();
		""", true)
