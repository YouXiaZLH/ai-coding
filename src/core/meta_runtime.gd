extends Node

const META_CAP_DEFAULT := 999
const SAVE_PATH := "user://meta_progress.save.json"
const PLAYTEST_UNLOCK_LOG_PATH := "user://playtest_unlock_log.json"
const META_ECONOMY_CONFIG_PATH := "res://assets/data/meta/economy_config.json"
const REWARD_BASE_DEFAULT := 10
const REWARD_WIN_BONUS_DEFAULT := 5
const REWARD_WAVE_BONUS_PER_WAVE_DEFAULT := 1

var meta_progress: Dictionary = {
	"meta_point": 0,
	"meta_cap": META_CAP_DEFAULT,
	"unlock_state": {},
	"unlock_revision": 0,
	"unlock_schema_version": 1,
	"first_unlock_guide_seen": false,
}

var _applied_settlements: Dictionary = {}
var _applied_unlock_txns: Dictionary = {}
var _unlock_catalog_by_id: Dictionary = {}
var _event_logs: Array[Dictionary] = []
var _playtest_unlock_logs: Array[Dictionary] = []
var _economy_config: Dictionary = {
	"reward": {
		"base": REWARD_BASE_DEFAULT,
		"win_bonus": REWARD_WIN_BONUS_DEFAULT,
		"wave_bonus_per_wave": REWARD_WAVE_BONUS_PER_WAVE_DEFAULT,
	},
	"unlock_cost_overrides": {},
}

func _ready() -> void:
	_load_progress_template()
	_load_meta_economy_config()
	_load_unlock_catalog()
	reload_meta_progress()

func apply_end_of_match_settlement(match_id: String, reward_revision: int, is_win: bool, wave_cleared: int) -> Dictionary:
	var txn_key := "%s:%d" % [match_id, reward_revision]
	if _applied_settlements.has(txn_key):
		var existing: Dictionary = _applied_settlements[txn_key]
		var idempotent_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": true,
			"meta_point_before": existing["meta_point_before"],
			"meta_point_after": existing["meta_point_after"],
			"meta_point_delta": 0,
			"error_code": "IDEMPOTENT_DUPLICATE",
		}
		_append_log("meta_settlement_duplicate", idempotent_result)
		return idempotent_result

	var meta_point_before: int = int(meta_progress.get("meta_point", 0))
	var meta_cap: int = int(meta_progress.get("meta_cap", META_CAP_DEFAULT))
	var reward_cfg := _get_reward_config()
	var base_reward: int = int(reward_cfg.get("base", REWARD_BASE_DEFAULT))
	var win_bonus_cfg: int = int(reward_cfg.get("win_bonus", REWARD_WIN_BONUS_DEFAULT))
	var wave_bonus_per_wave: int = int(reward_cfg.get("wave_bonus_per_wave", REWARD_WAVE_BONUS_PER_WAVE_DEFAULT))
	var wave_bonus: int = maxi(0, wave_cleared) * maxi(0, wave_bonus_per_wave)
	var win_bonus: int = win_bonus_cfg if is_win else 0
	var meta_point_delta: int = maxi(0, base_reward) + win_bonus + wave_bonus
	var meta_point_after: int = mini(meta_cap, meta_point_before + meta_point_delta)

	meta_progress["meta_point"] = meta_point_after

	var result := {
		"txn_key": txn_key,
		"match_id": match_id,
		"reward_revision": reward_revision,
		"applied": true,
		"idempotent": false,
		"meta_point_before": meta_point_before,
		"meta_point_after": meta_point_after,
		"meta_point_delta": meta_point_after - meta_point_before,
		"error_code": "",
	}
	_applied_settlements[txn_key] = result
	_append_log("meta_settlement_applied", result)
	persist_meta_progress()
	return result

func get_meta_point() -> int:
	return int(meta_progress.get("meta_point", 0))

func get_unlock_level(unlock_id: String) -> int:
	var unlock_state := _get_unlock_state_dict()
	return int(unlock_state.get(unlock_id, 0))

func get_unlock_cost(unlock_id: String) -> int:
	if not _unlock_catalog_by_id.has(unlock_id):
		return -1
	return int(_unlock_catalog_by_id[unlock_id].get("cost", 0))

func has_unlock(unlock_id: String) -> bool:
	return _unlock_catalog_by_id.has(unlock_id)

func get_unlock_catalog_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for unlock_id in _unlock_catalog_by_id.keys():
		var cfg: Dictionary = _unlock_catalog_by_id[unlock_id]
		items.append(cfg.duplicate(true))
	return items

func is_first_unlock_guide_seen() -> bool:
	return bool(meta_progress.get("first_unlock_guide_seen", false))

func mark_first_unlock_guide_seen() -> Dictionary:
	if is_first_unlock_guide_seen():
		var idempotent_result := {
			"ok": true,
			"updated": false,
			"error_code": "",
		}
		_append_log("first_unlock_guide_mark_idempotent", idempotent_result)
		return idempotent_result

	meta_progress["first_unlock_guide_seen"] = true
	var persist_result := persist_meta_progress()
	var result := {
		"ok": bool(persist_result.get("ok", false)),
		"updated": true,
		"error_code": String(persist_result.get("error_code", "")),
	}
	_append_log("first_unlock_guide_marked", result)
	return result

func unlock_item(player_id: String, unlock_id: String, request_seq: int, simulate_write_failure: bool = false) -> Dictionary:
	var start_ticks_usec := Time.get_ticks_usec()
	var txn_key := "%s:%s:%d" % [player_id, unlock_id, request_seq]
	if _applied_unlock_txns.has(txn_key):
		var existing: Dictionary = _applied_unlock_txns[txn_key]
		var dup_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": true,
			"rolled_back": false,
			"meta_point_before": existing.get("meta_point_before", get_meta_point()),
			"meta_point_after": existing.get("meta_point_after", get_meta_point()),
			"meta_point_delta": 0,
			"unlock_id": unlock_id,
			"unlock_revision": int(meta_progress.get("unlock_revision", 0)),
			"error_code": "IDEMPOTENT_TXN_DUPLICATE",
		}
		_append_log("meta_unlock_duplicate_txn", dup_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, dup_result, start_ticks_usec)
		return dup_result

	if not _unlock_catalog_by_id.has(unlock_id):
		var missing_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": false,
			"rolled_back": false,
			"unlock_id": unlock_id,
			"error_code": "UNLOCK_NOT_FOUND",
		}
		_append_log("meta_unlock_rejected", missing_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, missing_result, start_ticks_usec)
		return missing_result

	var unlock_cfg: Dictionary = _unlock_catalog_by_id[unlock_id]
	var unlock_state := _get_unlock_state_dict()
	if int(unlock_state.get(unlock_id, 0)) >= 1:
		var unlocked_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": true,
			"rolled_back": false,
			"meta_point_before": get_meta_point(),
			"meta_point_after": get_meta_point(),
			"meta_point_delta": 0,
			"unlock_id": unlock_id,
			"unlock_revision": int(meta_progress.get("unlock_revision", 0)),
			"error_code": "ALREADY_UNLOCKED",
		}
		_applied_unlock_txns[txn_key] = unlocked_result
		_append_log("meta_unlock_already_unlocked", unlocked_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, unlocked_result, start_ticks_usec)
		return unlocked_result

	var cost: int = int(unlock_cfg.get("cost", 0))
	if cost < 0:
		var invalid_cost_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": false,
			"rolled_back": false,
			"unlock_id": unlock_id,
			"error_code": "INVALID_COST",
		}
		_append_log("meta_unlock_rejected", invalid_cost_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, invalid_cost_result, start_ticks_usec)
		return invalid_cost_result

	var prereq_ids: Array = unlock_cfg.get("prereq_ids", [])
	for prereq in prereq_ids:
		if int(unlock_state.get(String(prereq), 0)) <= 0:
			var prereq_result := {
				"txn_key": txn_key,
				"applied": false,
				"idempotent": false,
				"rolled_back": false,
				"unlock_id": unlock_id,
				"error_code": "PREREQ_NOT_MET",
			}
			_append_log("meta_unlock_rejected", prereq_result)
			_append_playtest_unlock_log(player_id, unlock_id, request_seq, prereq_result, start_ticks_usec)
			return prereq_result

	var meta_point_before: int = get_meta_point()
	if meta_point_before < cost:
		var not_enough_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": false,
			"rolled_back": false,
			"meta_point_before": meta_point_before,
			"meta_point_after": meta_point_before,
			"meta_point_delta": 0,
			"unlock_id": unlock_id,
			"unlock_revision": int(meta_progress.get("unlock_revision", 0)),
			"error_code": "INSUFFICIENT_META_POINT",
		}
		_append_log("meta_unlock_rejected", not_enough_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, not_enough_result, start_ticks_usec)
		return not_enough_result

	var snapshot_before: Dictionary = meta_progress.duplicate(true)
	meta_progress["meta_point"] = meta_point_before - cost

	if simulate_write_failure:
		meta_progress = snapshot_before
		var rollback_result := {
			"txn_key": txn_key,
			"applied": false,
			"idempotent": false,
			"rolled_back": true,
			"meta_point_before": meta_point_before,
			"meta_point_after": int(meta_progress.get("meta_point", 0)),
			"meta_point_delta": 0,
			"unlock_id": unlock_id,
			"unlock_revision": int(meta_progress.get("unlock_revision", 0)),
			"error_code": "WRITE_FAILED_ROLLBACK",
		}
		_append_log("meta_unlock_rolled_back", rollback_result)
		_append_playtest_unlock_log(player_id, unlock_id, request_seq, rollback_result, start_ticks_usec)
		return rollback_result

	unlock_state[unlock_id] = 1
	meta_progress["unlock_state"] = unlock_state
	meta_progress["unlock_revision"] = int(meta_progress.get("unlock_revision", 0)) + 1
	var applied_result := {
		"txn_key": txn_key,
		"applied": true,
		"idempotent": false,
		"rolled_back": false,
		"meta_point_before": meta_point_before,
		"meta_point_after": int(meta_progress.get("meta_point", 0)),
		"meta_point_delta": int(meta_progress.get("meta_point", 0)) - meta_point_before,
		"unlock_id": unlock_id,
		"unlock_revision": int(meta_progress.get("unlock_revision", 0)),
		"error_code": "",
	}
	_applied_unlock_txns[txn_key] = applied_result
	_append_log("meta_unlock_applied", applied_result)
	_append_playtest_unlock_log(player_id, unlock_id, request_seq, applied_result, start_ticks_usec)
	persist_meta_progress()
	return applied_result

func export_playtest_unlock_logs() -> Dictionary:
	var payload := {
		"schema": "s1_s1_unlock_diagnostics_v1",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"entries": _playtest_unlock_logs.duplicate(true),
	}
	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(PLAYTEST_UNLOCK_LOG_PATH, FileAccess.WRITE)
	if file == null:
		var fail_result := {
			"ok": false,
			"path": PLAYTEST_UNLOCK_LOG_PATH,
			"exported_count": 0,
			"error_code": "PLAYTEST_LOG_EXPORT_OPEN_FAILED",
		}
		_append_log("playtest_unlock_log_export_failed", fail_result)
		return fail_result

	file.store_string(json_text)
	var ok_result := {
		"ok": true,
		"path": PLAYTEST_UNLOCK_LOG_PATH,
		"exported_count": _playtest_unlock_logs.size(),
		"error_code": "",
	}
	_append_log("playtest_unlock_log_exported", ok_result)
	return ok_result

func persist_meta_progress() -> Dictionary:
	var save_payload: Dictionary = meta_progress.duplicate(true)
	if typeof(save_payload.get("unlock_state", {})) != TYPE_DICTIONARY:
		save_payload["unlock_state"] = {}
	var json_text := JSON.stringify(save_payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var fail_result := {
			"ok": false,
			"path": SAVE_PATH,
			"error_code": "SAVE_OPEN_FAILED",
		}
		_append_log("meta_progress_save_failed", fail_result)
		return fail_result

	file.store_string(json_text)
	var ok_result := {
		"ok": true,
		"path": SAVE_PATH,
		"error_code": "",
	}
	_append_log("meta_progress_saved", ok_result)
	return ok_result

func reload_meta_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		var no_file_result := {
			"ok": true,
			"path": SAVE_PATH,
			"used_fallback": true,
			"error_code": "SAVE_NOT_FOUND",
		}
		_append_log("meta_progress_load_fallback", no_file_result)
		persist_meta_progress()
		return no_file_result

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var open_fail_result := {
			"ok": false,
			"path": SAVE_PATH,
			"used_fallback": true,
			"error_code": "LOAD_OPEN_FAILED",
		}
		_append_log("meta_progress_load_failed", open_fail_result)
		persist_meta_progress()
		return open_fail_result

	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var parse_fail_result := {
			"ok": false,
			"path": SAVE_PATH,
			"used_fallback": true,
			"error_code": "LOAD_PARSE_FAILED",
		}
		_append_log("meta_progress_load_failed", parse_fail_result)
		persist_meta_progress()
		return parse_fail_result

	meta_progress = parsed.duplicate(true)
	if typeof(meta_progress.get("unlock_state", {})) != TYPE_DICTIONARY:
		meta_progress["unlock_state"] = {}
	if not meta_progress.has("meta_cap"):
		meta_progress["meta_cap"] = META_CAP_DEFAULT
	if not meta_progress.has("unlock_revision"):
		meta_progress["unlock_revision"] = 0
	if not meta_progress.has("unlock_schema_version"):
		meta_progress["unlock_schema_version"] = 1
	if not meta_progress.has("first_unlock_guide_seen"):
		meta_progress["first_unlock_guide_seen"] = false

	var ok_result := {
		"ok": true,
		"path": SAVE_PATH,
		"used_fallback": false,
		"error_code": "",
	}
	_append_log("meta_progress_loaded", ok_result)
	return ok_result

func write_corrupted_save_for_test() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var fail_result := {
			"ok": false,
			"path": SAVE_PATH,
			"error_code": "CORRUPT_WRITE_OPEN_FAILED",
		}
		_append_log("meta_progress_corrupt_write_failed", fail_result)
		return fail_result

	file.store_string("{invalid-json")
	var ok_result := {
		"ok": true,
		"path": SAVE_PATH,
		"error_code": "",
	}
	_append_log("meta_progress_corrupted_for_test", ok_result)
	return ok_result

func get_recent_logs(max_count: int = 8) -> Array[Dictionary]:
	if _event_logs.is_empty():
		return []
	var from_index := maxi(0, _event_logs.size() - max_count)
	return _event_logs.slice(from_index, _event_logs.size())

func _load_progress_template() -> void:
	var template_path := "res://assets/data/meta/progression_template.json"
	if not FileAccess.file_exists(template_path):
		_append_log("meta_progress_template_missing", {"path": template_path})
		return

	var file := FileAccess.open(template_path, FileAccess.READ)
	if file == null:
		_append_log("meta_progress_template_open_failed", {"path": template_path})
		return

	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_append_log("meta_progress_template_parse_failed", {"path": template_path})
		return

	meta_progress = parsed.duplicate(true)
	_append_log("meta_progress_template_loaded", {"meta_point": meta_progress.get("meta_point", 0)})

func _load_unlock_catalog() -> void:
	var catalog_path := "res://assets/data/meta/unlock_catalog.json"
	if not FileAccess.file_exists(catalog_path):
		_append_log("unlock_catalog_missing", {"path": catalog_path})
		return

	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		_append_log("unlock_catalog_open_failed", {"path": catalog_path})
		return

	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_append_log("unlock_catalog_parse_failed", {"path": catalog_path})
		return

	var items: Array = parsed.get("items", [])
	var cost_overrides := _get_unlock_cost_overrides()
	_unlock_catalog_by_id.clear()
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_dict: Dictionary = item
		var unlock_id := String(item_dict.get("unlock_id", ""))
		if unlock_id.is_empty():
			continue
		if cost_overrides.has(unlock_id):
			item_dict["cost"] = int(cost_overrides[unlock_id])
		_unlock_catalog_by_id[unlock_id] = item_dict.duplicate(true)
	_append_log("unlock_catalog_loaded", {"count": _unlock_catalog_by_id.size()})

func _load_meta_economy_config() -> void:
	if not FileAccess.file_exists(META_ECONOMY_CONFIG_PATH):
		_append_log("meta_economy_config_missing", {"path": META_ECONOMY_CONFIG_PATH})
		return

	var file := FileAccess.open(META_ECONOMY_CONFIG_PATH, FileAccess.READ)
	if file == null:
		_append_log("meta_economy_config_open_failed", {"path": META_ECONOMY_CONFIG_PATH})
		return

	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_append_log("meta_economy_config_parse_failed", {"path": META_ECONOMY_CONFIG_PATH})
		return

	var parsed_dict: Dictionary = parsed
	var reward: Dictionary = parsed_dict.get("reward", {})
	if typeof(reward) == TYPE_DICTIONARY:
		_economy_config["reward"] = {
			"base": int(reward.get("base", REWARD_BASE_DEFAULT)),
			"win_bonus": int(reward.get("win_bonus", REWARD_WIN_BONUS_DEFAULT)),
			"wave_bonus_per_wave": int(reward.get("wave_bonus_per_wave", REWARD_WAVE_BONUS_PER_WAVE_DEFAULT)),
		}

	var unlock_cost_overrides: Variant = parsed_dict.get("unlock_cost_overrides", {})
	if typeof(unlock_cost_overrides) == TYPE_DICTIONARY:
		_economy_config["unlock_cost_overrides"] = unlock_cost_overrides.duplicate(true)

	_append_log("meta_economy_config_loaded", {
		"path": META_ECONOMY_CONFIG_PATH,
		"reward": _economy_config.get("reward", {}),
		"cost_override_count": _get_unlock_cost_overrides().size(),
	})

func _get_reward_config() -> Dictionary:
	var reward: Variant = _economy_config.get("reward", {})
	if typeof(reward) != TYPE_DICTIONARY:
		return {
			"base": REWARD_BASE_DEFAULT,
			"win_bonus": REWARD_WIN_BONUS_DEFAULT,
			"wave_bonus_per_wave": REWARD_WAVE_BONUS_PER_WAVE_DEFAULT,
		}
	return reward

func _get_unlock_cost_overrides() -> Dictionary:
	var overrides: Variant = _economy_config.get("unlock_cost_overrides", {})
	if typeof(overrides) != TYPE_DICTIONARY:
		return {}
	return overrides

func _get_unlock_state_dict() -> Dictionary:
	if typeof(meta_progress.get("unlock_state", {})) != TYPE_DICTIONARY:
		meta_progress["unlock_state"] = {}
	return meta_progress["unlock_state"]

func _append_log(event_type: String, payload: Dictionary) -> void:
	_event_logs.append({
		"event_type": event_type,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"payload": payload,
	})

func _append_playtest_unlock_log(player_id: String, unlock_id: String, request_seq: int, unlock_result_payload: Dictionary, started_ticks_usec: int) -> void:
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_ticks_usec)
	var unlock_result := "failed"
	if bool(unlock_result_payload.get("applied", false)):
		unlock_result = "success"
	elif bool(unlock_result_payload.get("rolled_back", false)):
		unlock_result = "rollback"
	elif bool(unlock_result_payload.get("idempotent", false)):
		unlock_result = "idempotent"

	_playtest_unlock_logs.append({
		"timestamp_unix": Time.get_unix_time_from_system(),
		"player_id": player_id,
		"unlock_id": unlock_id,
		"request_seq": request_seq,
		"txn_key": String(unlock_result_payload.get("txn_key", "")),
		"unlock_result": unlock_result,
		"txn_latency": elapsed_usec,
		"error_code": String(unlock_result_payload.get("error_code", "")),
	})
