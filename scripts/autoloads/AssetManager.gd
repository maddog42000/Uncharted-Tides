extends Node

const GITHUB_RAW_BASE: String = "https://raw.githubusercontent.com/maddog42000/Uncharted-Tides/main/"
const CACHE_DIR: String = "user://asset_cache"

# User-supplied repository-root filenames. These are JPEGs (.jpg), not PNGs.
const ASSET_MAPPING: Dictionary = {
	# Resources & Materials
	"copper_ore": "1794560483063.jpg",
	"iron_bar": "1794560595521.jpg",
	"mithril_bar": "1794565378876.jpg",
	"runite_bar": "1794560757443.jpg",
	"oak_plank": "1794561097075.jpg",
	"mahogany_plank": "1794561286554.jpg",
	"magic_plank": "1794561350261.jpg",
	# Consumables & Provisions
	"repair_plank": "1794561246247.jpg",
	"cannonball": "1794561513881.jpg",
	"raw_sea_bass": "1794561544340.jpg",
	# Currencies
	"gold_coin": "1794561860326.jpg",
	"doubloon": "1794561671332.jpg",
	# Ship Portraits
	"sloop_icon": "1794561907703.jpg",
	"brigantine_icon": "1794562037636.jpg",
	"galleon_icon": "1794562076139.jpg",
	"manowar_icon": "1794562114163.jpg",
	# UI Navigation Tabs
	"icon_bank": "1794562211355.jpg",
	"icon_shipyard": "1794562323781.jpg",
	"icon_market": "1794562376881.jpg",
	"icon_chart": "1794562535806.jpg",
	# Screen artwork
	"loading_screen": "1794565997504.jpg",
	"main_menu": "1794566539395.jpg"
}

var _textures: Dictionary = {}
var _pending: Dictionary = {}
const LOCAL_SCREEN_FALLBACKS: Dictionary = {
	"main_menu": "res://assets/screens/main_menu.jpg",
	"loading_screen": "res://assets/screens/loading_screen.jpg"
}

func get_asset_url(asset_id: String) -> String:
	var filename: String = str(ASSET_MAPPING.get(asset_id, ""))
	if filename.is_empty():
		return ""
	return GITHUB_RAW_BASE + filename

func has_asset(asset_id: String) -> bool:
	return ASSET_MAPPING.has(asset_id)

func get_asset_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for asset_id in ASSET_MAPPING:
		result.append(str(asset_id))
	return result

# Asynchronously loads an asset, caching the JPEG under user://asset_cache for offline reuse.
# callback is invoked with a Texture2D, or null if both cache and network retrieval fail.
func request_texture(asset_id: String, callback: Callable) -> void:
	if not ASSET_MAPPING.has(asset_id):
		callback.call(null)
		return
	if _textures.has(asset_id):
		callback.call(_textures[asset_id])
		return
	var local_path: String = str(LOCAL_SCREEN_FALLBACKS.get(asset_id, ""))
	if not local_path.is_empty() and ResourceLoader.exists(local_path):
		var local_texture: Texture2D = load(local_path) as Texture2D
		if local_texture != null:
			_textures[asset_id] = local_texture
			callback.call(local_texture)
			return
	var cached: Texture2D = _load_cached_texture(asset_id)
	if cached != null:
		_textures[asset_id] = cached
		callback.call(cached)
		return
	if _pending.has(asset_id):
		_pending[asset_id].append(callback)
		return
	_pending[asset_id] = [callback]
	var http := HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(asset_id, http))
	var err: Error = http.request(get_asset_url(asset_id))
	if err != OK:
		_finish_asset_request(asset_id, null)
		http.queue_free()

func _cache_path(asset_id: String) -> String:
	return CACHE_DIR + "/" + str(ASSET_MAPPING.get(asset_id, ""))

func _load_cached_texture(asset_id: String) -> Texture2D:
	var path: String = _cache_path(asset_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var error: Error = image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, asset_id: String, http: HTTPRequest) -> void:
	var texture: Texture2D = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not body.is_empty():
		var image := Image.new()
		if image.load_jpg_from_buffer(body) == OK and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
			var file := FileAccess.open(_cache_path(asset_id), FileAccess.WRITE)
			if file != null:
				file.store_buffer(body)
				file.close()
	_finish_asset_request(asset_id, texture)
	if is_instance_valid(http):
		http.queue_free()

func _finish_asset_request(asset_id: String, texture: Texture2D) -> void:
	if texture != null:
		_textures[asset_id] = texture
	var callbacks: Array = _pending.get(asset_id, [])
	_pending.erase(asset_id)
	for callback in callbacks:
		if callback is Callable and callback.is_valid():
			callback.call(texture)
