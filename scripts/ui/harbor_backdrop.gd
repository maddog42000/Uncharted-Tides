extends Control

const SKY_TOP := Color("#6e9fc2")
const SKY_HORIZON := Color("#f1b56f")
const SEA := Color("#174b68")
const SEA_LIGHT := Color("#287895")
const DISTANT := Color("#294454")
const DOCK := Color("#4a3428")
const GOLD := Color("#edc36b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var horizon := h * 0.52
	var band_count := 14
	for i in range(band_count):
		var t := float(i) / float(band_count - 1)
		var color := SKY_TOP.lerp(SKY_HORIZON, t)
		draw_rect(Rect2(0, h * 0.02 + horizon * t, w, horizon / band_count + 2), color)
	for i in range(band_count):
		var t := float(i) / float(band_count - 1)
		var color := SEA_LIGHT.lerp(SEA, t)
		draw_rect(Rect2(0, horizon + h * 0.015 + h * 0.37 * t, w, h * 0.37 / band_count + 2), color)
	# Low sun and a soft reflection across the bay.
	draw_circle(Vector2(w * 0.77, h * 0.30), minf(w, h) * 0.065, Color("#ffe1a0"))
	draw_circle(Vector2(w * 0.77, h * 0.30), minf(w, h) * 0.09, Color(1.0, 0.84, 0.53, 0.22))
	for i in range(10):
		var yy := horizon + h * (0.045 + 0.025 * i)
		var half_width := w * (0.025 + 0.01 * i)
		draw_line(Vector2(w * 0.77 - half_width, yy), Vector2(w * 0.77 + half_width, yy), Color(1.0, 0.81, 0.48, 0.25 - 0.015 * i), 2.0)
	# Distant waterfront roofs and a lighthouse silhouette.
	for i in range(16):
		var x := w * (0.03 + 0.061 * i)
		var bh := h * (0.065 + float((i * 7) % 5) * 0.012)
		var bw := w * 0.052
		var base_y := horizon + h * 0.015
		draw_rect(Rect2(x, base_y - bh, bw, bh), DISTANT)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base_y - bh), Vector2(x + bw * 0.5, base_y - bh - h * 0.025), Vector2(x + bw + 4, base_y - bh)]), Color("#344f5c"))
		for window_i in range(2):
			draw_rect(Rect2(x + bw * (0.22 + 0.38 * window_i), base_y - bh * 0.62, w * 0.006, h * 0.013), Color("#f6c978"))
	var lx := w * 0.14
	var ly := horizon - h * 0.02
	draw_colored_polygon(PackedVector2Array([Vector2(lx - w * 0.018, ly), Vector2(lx - w * 0.009, ly - h * 0.21), Vector2(lx + w * 0.009, ly - h * 0.21), Vector2(lx + w * 0.018, ly)]), Color("#e5d8b8"))
	draw_rect(Rect2(lx - w * 0.013, ly - h * 0.225, w * 0.026, h * 0.025), Color("#384c58"))
	draw_rect(Rect2(lx - w * 0.008, ly - h * 0.217, w * 0.016, h * 0.008), GOLD)
	# Harbor ship: hull, mast, rigging, and canvas sails.
	var sx := w * 0.53
	var sy := horizon + h * 0.16
	draw_colored_polygon(PackedVector2Array([Vector2(sx - w * 0.16, sy), Vector2(sx + w * 0.16, sy), Vector2(sx + w * 0.12, sy + h * 0.055), Vector2(sx - w * 0.11, sy + h * 0.055)]), Color("#39281f"))
	draw_line(Vector2(sx, sy - h * 0.34), Vector2(sx, sy + h * 0.01), Color("#30251f"), 5.0)
	draw_line(Vector2(sx - w * 0.075, sy - h * 0.24), Vector2(sx - w * 0.075, sy + h * 0.01), Color("#30251f"), 3.0)
	draw_line(Vector2(sx + w * 0.078, sy - h * 0.20), Vector2(sx + w * 0.078, sy + h * 0.01), Color("#30251f"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(sx - w * 0.004, sy - h * 0.31), Vector2(sx - w * 0.004, sy - h * 0.12), Vector2(sx - w * 0.085, sy - h * 0.12)]), Color("#f0dfbb"))
	draw_colored_polygon(PackedVector2Array([Vector2(sx + w * 0.006, sy - h * 0.28), Vector2(sx + w * 0.006, sy - h * 0.10), Vector2(sx + w * 0.085, sy - h * 0.10)]), Color("#ead3a6"))
	draw_colored_polygon(PackedVector2Array([Vector2(sx - w * 0.08, sy - h * 0.225), Vector2(sx - w * 0.08, sy - h * 0.09), Vector2(sx - w * 0.135, sy - h * 0.09)]), Color("#e6d4b0"))
	draw_line(Vector2(sx, sy - h * 0.34), Vector2(sx + w * 0.04, sy - h * 0.36), GOLD, 2.0)
	# Water glints and timber quay along the foreground.
	for i in range(36):
		var x := w * (float((i * 37) % 97) / 100.0)
		var yy := horizon + h * (0.09 + float((i * 13) % 31) / 100.0)
		var glint_w := w * (0.012 + float(i % 4) * 0.004)
		draw_line(Vector2(x, yy), Vector2(x + glint_w, yy), Color(0.74, 0.84, 0.78, 0.28), 1.5)
	draw_rect(Rect2(0, h * 0.91, w, h * 0.09), DOCK)
	draw_rect(Rect2(0, h * 0.91, w, h * 0.012), GOLD)
	for i in range(18):
		var x := w * float(i) / 18.0
		draw_line(Vector2(x, h * 0.92), Vector2(x + w * 0.025, h), Color("#76543a"), 2.0)
