extends Control
class_name DeckAnimator

const CARD_BACK_IMG_PATH: String = "res://assets/images/card_back_test.png"
const CARD_VIS_Z_INDEX: int = 9

signal finished_reshuffle_anim()

var draw_deck_img: TextureRect
var discard_pile_img: TextureRect

var card_vis_pool: Array[TextureRect]

var bounce_tweens: Dictionary

func setup(draw_img: TextureRect, discard_img: TextureRect) -> void:
	draw_deck_img = draw_img
	discard_pile_img = discard_img

func create_new_card_vis() -> TextureRect:
	for card in card_vis_pool:
		if !card.visible:
			card.set_visible(true)
			return card
	
	var new_card_vis: TextureRect = TextureRect.new()
	new_card_vis.texture = preload(CARD_BACK_IMG_PATH)
	new_card_vis.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_card_vis.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_card_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_card_vis.z_index = CARD_VIS_Z_INDEX
	get_tree().current_scene.add_child(new_card_vis)
	
	new_card_vis.size = draw_deck_img.size
	new_card_vis.pivot_offset = new_card_vis.size / 2.0
	
	card_vis_pool.append(new_card_vis)
	return new_card_vis

func anim_reshuffle(duration: float = 1, is_last_card: bool = false) -> void:
	var ark_height = randi_range(500, 900)
	var card_vis: TextureRect = create_new_card_vis()
	
	for card in card_vis_pool:
		if not card.visible:
			card_vis = card
			card_vis.set_visible(true)
			break
	
	if !card_vis:
		card_vis = create_new_card_vis()
	
	bounce_deck_anim(discard_pile_img, 0.1)
	
	
	var discard_pos: Transform2D = _get_visual_global_transform(discard_pile_img)
	var draw_pos: Transform2D = _get_visual_global_transform(draw_deck_img)
	var start: Vector2 = discard_pos * (discard_pile_img.size / 2.0)
	var end: Vector2 = draw_pos * (draw_deck_img.size / 2.0)
	
	var control: Vector2 = (start + end) / 2.0 + Vector2(0, -ark_height)
	
	_update_arc_card(0.0, card_vis, start, control, end)
	
	var move_tween: Tween = create_tween()
	move_tween.set_ease(Tween.EASE_IN)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_method(_update_arc_card.bind(card_vis, start, control, end), 0.0, 1.0, duration)
	move_tween.tween_callback(bounce_deck_anim.bind(draw_deck_img, 0.1))
	move_tween.tween_callback(card_vis.set_visible.bind(false))
	if is_last_card:
		move_tween.tween_callback(emit_reshuffle_done)

func anim_move_to_deck_pos(deck_ref: TextureRect):
	var deck_pos: Transform2D = _get_visual_global_transform(deck_ref)
	var end_pos: Vector2 = deck_pos * (discard_pile_img.size / 2.0)
	var start_pos: Vector2 = get_global_mouse_position()
	var card_vis = create_new_card_vis()
	var control: Vector2 = (start_pos + end_pos) / 2.0 + Vector2(0, -100)
	var move_tween: Tween = create_tween()
	
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_method(_update_arc_card.bind(card_vis, start_pos, control, end_pos), 0.0, 1.0, 0.3)
	move_tween.tween_callback(bounce_deck_anim.bind(discard_pile_img, 0.1))

func _update_arc_card(t: float, card_vis: Control, start: Vector2, control: Vector2, end: Vector2) -> void:
	var dir: Vector2 = _quadratic_bezier_tangent(start, control, end, t)
	if dir != Vector2.ZERO:
		card_vis.rotation = dir.angle() + PI / 2.0
	
	var center: Vector2 = _quadratic_bezier(start, control, end, t)
	card_vis.global_position = center - card_vis.size / 2.0
	var actual_center: Vector2 = card_vis.get_global_transform() * (card_vis.size / 2.0)
	card_vis.global_position += center - actual_center


func _get_visual_global_transform(ctrl: CanvasItem) -> Transform2D:
	var xf: Transform2D = Transform2D.IDENTITY
	var node: Node = ctrl
	while node is CanvasItem:
		var local: Transform2D = (node as CanvasItem).get_transform()
		if node is Control:
			var c: Control = node
			if c.offset_transform_enabled and c.offset_transform_visual_only:
				var pos: Vector2 = c.offset_transform_position + c.offset_transform_position_ratio * c.size
				var pivot: Vector2 = c.offset_transform_pivot + c.offset_transform_pivot_ratio * c.size
				var offset_xf: Transform2D = Transform2D(c.offset_transform_rotation, c.offset_transform_scale, 0.0, pos + pivot) \
						* Transform2D(0.0, -pivot)
				local = local * offset_xf
		xf = local * xf
		node = node.get_parent()
	return xf


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var a: Vector2 = p0.lerp(p1, t)
	var b: Vector2 = p1.lerp(p2, t)
	return a.lerp(b, t)

func _quadratic_bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)
	
func anim_reshuffle_multiple(count: int, total_time: float = 5) -> void:
	var delay: float = total_time / count
	for i in count:
		anim_reshuffle() 
		if i == count - 1:
			anim_reshuffle(1, true) 
		else:
			anim_reshuffle(1, false) 
		await get_tree().create_timer(delay).timeout

func bounce_deck_anim(deck_vis: TextureRect, duration: float = 0.15, strength: float = 1.2) -> void:
	deck_vis.offset_transform_enabled = true
	deck_vis.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	
	var old_tween: Tween = bounce_tweens.get(deck_vis)
	if old_tween:
		old_tween.kill()
	
	if old_tween:
		old_tween.kill()
		deck_vis.offset_transform_scale = Vector2(1,1)
	
	var tween: Tween = create_tween()
	bounce_tweens[deck_vis] = tween
	tween.tween_property(deck_vis, "offset_transform_scale", Vector2.ONE * strength, duration * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(deck_vis, "offset_transform_scale", Vector2.ONE, duration * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func emit_reshuffle_done():
	finished_reshuffle_anim.emit()
