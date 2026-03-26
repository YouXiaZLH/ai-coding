extends RefCounted

const WAVE_CONFIG_PATH := "res://assets/data/match/waves_config.json"

var _waves_by_index: Dictionary = {}
var _generated_cache: Dictionary = {}

func _init() -> void:
	_load_wave_config()

func generate_wave_payload(match_id: String, wave_index: int, match_seed: int, difficulty_profile: String = "mvp") -> Dictionary:
	var cache_key := "%s:%d:%d:%s" % [match_id, wave_index, match_seed, difficulty_profile]
	if _generated_cache.has(cache_key):
		var cached: Dictionary = _generated_cache[cache_key]
		var cached_result: Dictionary = cached.duplicate(true)
		cached_result["idempotent"] = true
		return cached_result

	var used_fallback: bool = false
	var wave_data: Dictionary
	if _waves_by_index.has(wave_index):
		wave_data = _waves_by_index[wave_index].duplicate(true)
	else:
		used_fallback = true
		wave_data = _build_fallback_wave(wave_index)

	var payload: Dictionary = {
		"wave_index": wave_index,
		"wave_type": String(wave_data.get("wave_type", _default_wave_type(wave_index))),
		"enemy_roster": wave_data.get("enemy_roster", []),
		"spawn_layout": wave_data.get("spawn_layout", []),
		"wave_modifiers": wave_data.get("wave_modifiers", {}),
		"wave_revision": 1,
		"seed": match_seed,
	}

	var result: Dictionary = {
		"ok": true,
		"idempotent": false,
		"used_fallback": used_fallback,
		"error_code": "",
		"wave_payload": payload,
	}
	_generated_cache[cache_key] = result.duplicate(true)
	return result

func _load_wave_config() -> void:
	_waves_by_index.clear()
	if not FileAccess.file_exists(WAVE_CONFIG_PATH):
		return

	var file := FileAccess.open(WAVE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var parsed_dict: Dictionary = parsed
	var waves_variant: Variant = parsed_dict.get("waves", [])
	if typeof(waves_variant) != TYPE_ARRAY:
		return
	var waves: Array = waves_variant
	for wave_item in waves:
		if typeof(wave_item) != TYPE_DICTIONARY:
			continue
		var wave_dict: Dictionary = wave_item
		var wave_index := int(wave_dict.get("wave_index", 0))
		if wave_index <= 0:
			continue
		_waves_by_index[wave_index] = wave_dict.duplicate(true)

func _build_fallback_wave(wave_index: int) -> Dictionary:
	var fallback_wave_type := _default_wave_type(wave_index)
	var front_unit_id := "enemy_%s_front" % fallback_wave_type
	var back_unit_id := "enemy_%s_back" % fallback_wave_type
	return {
		"wave_index": wave_index,
		"wave_type": fallback_wave_type,
		"enemy_roster": [
			{"unit_id": front_unit_id, "power": 40 + wave_index * 8, "hp": 120 + wave_index * 30, "atk": 18 + wave_index * 4, "defense": 10 + wave_index * 2},
			{"unit_id": back_unit_id, "power": 35 + wave_index * 8, "hp": 100 + wave_index * 25, "atk": 20 + wave_index * 4, "defense": 8 + wave_index * 2}
		],
		"spawn_layout": [
			{"unit_id": front_unit_id, "row": 0, "col": 1},
			{"unit_id": back_unit_id, "row": 1, "col": 1}
		],
		"wave_modifiers": {
			"target_power": 120 + (wave_index - 1) * 70,
			"difficulty_tag": "fallback"
		}
	}

func _default_wave_type(wave_index: int) -> String:
	if wave_index <= 1:
		return "normal"
	if wave_index == 2:
		return "elite"
	return "boss"
