extends RefCounted

const WaveGenerator := preload("res://src/core/wave_generator.gd")
const AutoBattleResolver := preload("res://src/core/auto_battle_resolver.gd")

const STATE_BOOT := "BOOT"
const STATE_WAVE_PREPARE := "WAVE_PREPARE"
const STATE_SHOP := "SHOP"
const STATE_DEPLOY := "DEPLOY"
const STATE_BATTLE := "BATTLE"
const STATE_RESOLVE := "RESOLVE"
const STATE_GAME_WIN := "GAME_WIN"
const STATE_GAME_OVER := "GAME_OVER"

const WAVE_COUNT := 3
const PLAYTEST_MATCH_LOG_PATH := "user://playtest_match_timeline.json"
const PLAYTEST_BATTLE_TOP3_LOG_PATH := "user://playtest_battle_top3.json"
const PLAYTEST_RECENT_REPLAY_PATH := "user://playtest_recent_match_replay.json"
const MATCH_BALANCE_CONFIG_PATH := "res://assets/data/match/match_balance_config.json"
const DEFAULT_SHOP_BUY_COST := 3
const DEFAULT_SHOP_REFRESH_COST := 1
const SHOP_OFFER_POOL := ["unit_spear", "unit_blade", "unit_archer", "unit_guard"]
const DEPLOY_FRONTLINE_SLOT_COUNT := 3
const DEPLOY_INITIAL_BENCH := ["unit_spear", "unit_blade", "unit_archer"]
const WAVE_GOLD_REWARD_BY_TYPE := {
	"normal": 4,
	"elite": 6,
	"boss": 9,
}
const DEFAULT_WAVE_HP_PENALTY_BY_INDEX := {
	1: 2,
	2: 3,
	3: 5,
}
const PHASE_DURATIONS := {
	STATE_BOOT: 0.2,
	STATE_WAVE_PREPARE: 1.0,
	STATE_SHOP: 25.0,
	STATE_DEPLOY: 20.0,
	STATE_BATTLE: 45.0,
	STATE_RESOLVE: 10.0,
}

const VALID_TRANSITIONS := {
	STATE_BOOT: [STATE_WAVE_PREPARE],
	STATE_WAVE_PREPARE: [STATE_SHOP],
	STATE_SHOP: [STATE_DEPLOY],
	STATE_DEPLOY: [STATE_BATTLE],
	STATE_BATTLE: [STATE_RESOLVE],
	STATE_RESOLVE: [STATE_WAVE_PREPARE, STATE_GAME_WIN, STATE_GAME_OVER],
	STATE_GAME_WIN: [],
	STATE_GAME_OVER: [],
}

var match_id: String = ""
var current_state: String = STATE_BOOT
var wave_index: int = 1
var player_hp: int = 10
var player_gold: int = 10
var state_elapsed_sec: float = 0.0
var _is_active: bool = false
var _event_logs: Array[Dictionary] = []
var _wave_generator: RefCounted
var _battle_resolver: RefCounted
var _current_wave_payload: Dictionary = {}
var _current_battle_summary: Dictionary = {}
var _last_resolve_summary: Dictionary = {}
var _last_wave_won: bool = false
var _meta_settlement_result: Dictionary = {}
var _meta_settlement_applied: bool = false
var _meta_reward_revision: int = 1
var _match_seed: int = 0
var _failure_recap_card: Dictionary = {}
var _shop_locked: bool = false
var _shop_refresh_count: int = 0
var _shop_buy_count: int = 0
var _shop_gold_spent: int = 0
var _shop_offer_id: String = ""
var _shop_last_action: String = ""
var _deploy_frontline: Array[String] = []
var _deploy_bench: Array[String] = []
var _deploy_action_count: int = 0
var _deploy_last_action: String = ""
var _deploy_frozen_snapshot: Dictionary = {}
var _shop_buy_cost: int = DEFAULT_SHOP_BUY_COST
var _shop_refresh_cost: int = DEFAULT_SHOP_REFRESH_COST
var _wave_hp_penalty_by_index: Dictionary = DEFAULT_WAVE_HP_PENALTY_BY_INDEX.duplicate(true)
var _balance_config_report: Dictionary = {}
var _last_completed_replay: Dictionary = {}

func _init() -> void:
	_wave_generator = WaveGenerator.new()
	_battle_resolver = AutoBattleResolver.new()
	_load_match_balance_config()

func start_match(new_match_id: String) -> Dictionary:
	match_id = new_match_id
	_match_seed = int(abs(hash(match_id)))
	wave_index = 1
	player_hp = 10
	player_gold = 10
	current_state = STATE_BOOT
	state_elapsed_sec = 0.0
	_is_active = true
	_event_logs.clear()
	_current_wave_payload = {}
	_current_battle_summary = {}
	_last_resolve_summary = {}
	_last_wave_won = false
	_meta_settlement_result = {}
	_meta_settlement_applied = false
	_meta_reward_revision = 1
	_failure_recap_card = {}
	_shop_locked = false
	_shop_refresh_count = 0
	_shop_buy_count = 0
	_shop_gold_spent = 0
	_shop_offer_id = ""
	_shop_last_action = ""
	_reset_deploy_state()
	_append_log("match_balance_config_loaded", _balance_config_report.duplicate(true))
	_append_log("match_started", {"match_id": match_id})
	return _request_transition_internal(STATE_WAVE_PREPARE, "boot_init", false)

func tick(delta: float) -> void:
	if not _is_active:
		return
	if is_terminal_state(current_state):
		return

	state_elapsed_sec += maxf(0.0, delta)
	var duration_limit := _get_state_duration(current_state)
	if duration_limit > 0.0 and state_elapsed_sec >= duration_limit:
		_handle_timeout_transition()

func confirm_current_state() -> Dictionary:
	if not _is_active:
		return _build_result(false, "MATCH_NOT_ACTIVE", current_state, "manual_confirm")

	match current_state:
		STATE_SHOP:
			return _request_transition_internal(STATE_DEPLOY, "manual_confirm", false)
		STATE_DEPLOY:
			return _request_transition_internal(STATE_BATTLE, "manual_confirm", false)
		STATE_BATTLE:
			return _request_transition_internal(STATE_RESOLVE, "battle_finished", false)
		STATE_RESOLVE:
			return _resolve_next_state("manual_confirm")
		_:
			return _build_result(false, "CONFIRM_NOT_ALLOWED", current_state, "manual_confirm")

func request_transition(target_state: String, reason: String) -> Dictionary:
	return _request_transition_internal(target_state, reason, true)

func get_recent_logs(max_count: int = 8) -> Array[Dictionary]:
	if _event_logs.is_empty():
		return []
	var from_index := maxi(0, _event_logs.size() - max_count)
	return _event_logs.slice(from_index, _event_logs.size())

func get_state_snapshot() -> Dictionary:
	var wave_type := String(_current_wave_payload.get("wave_type", ""))
	var enemy_roster: Array = _current_wave_payload.get("enemy_roster", [])
	var battle_result := String(_current_battle_summary.get("result", ""))
	var battle_duration := float(_current_battle_summary.get("duration_sec", 0.0))
	var battle_context: Dictionary = _current_battle_summary.get("battle_context", {})
	var battle_ally_power_raw := float(_current_battle_summary.get("ally_power_raw", 0.0))
	var battle_ally_power_modifier := float(_current_battle_summary.get("ally_power_modifier", 0.0))
	var resolve_gold_delta := int(_last_resolve_summary.get("gold_delta", 0))
	var resolve_hp_delta := int(_last_resolve_summary.get("hp_delta", 0))
	var resolve_is_win := bool(_last_resolve_summary.get("is_win", false))
	var resolve_wave_type := String(_last_resolve_summary.get("wave_type", ""))
	var resolve_gold_after := int(_last_resolve_summary.get("gold_after", player_gold))
	var resolve_hp_after := int(_last_resolve_summary.get("hp_after", player_hp))
	var meta_point_delta := int(_meta_settlement_result.get("meta_point_delta", 0))
	var failure_wave := int(_failure_recap_card.get("failed_wave", 0))
	var failure_root_cause := String(_failure_recap_card.get("root_cause", ""))
	var deploy_frozen_frontline: Array = _deploy_frozen_snapshot.get("frontline", [])
	var deploy_frozen_frontline_text := "|".join(deploy_frozen_frontline)
	return {
		"match_id": match_id,
		"state": current_state,
		"wave": wave_index,
		"wave_type": wave_type,
		"enemy_count": enemy_roster.size(),
		"battle_result": battle_result,
		"battle_duration_sec": battle_duration,
		"battle_ally_power_raw": battle_ally_power_raw,
		"battle_ally_power_modifier": battle_ally_power_modifier,
		"battle_frontline_count": int(battle_context.get("frontline_count", 0)),
		"battle_shop_buy_count": int(battle_context.get("shop_buy_count", 0)),
		"battle_shop_refresh_count": int(battle_context.get("shop_refresh_count", 0)),
		"player_hp": player_hp,
		"player_gold": player_gold,
		"resolve_gold_delta": resolve_gold_delta,
		"resolve_hp_delta": resolve_hp_delta,
		"resolve_is_win": resolve_is_win,
		"resolve_wave_type": resolve_wave_type,
		"resolve_gold_after": resolve_gold_after,
		"resolve_hp_after": resolve_hp_after,
		"meta_point_delta": meta_point_delta,
		"failed_wave": failure_wave,
		"failure_root_cause": failure_root_cause,
		"shop_locked": _shop_locked,
		"shop_refresh_count": _shop_refresh_count,
		"shop_buy_count": _shop_buy_count,
		"shop_gold_spent": _shop_gold_spent,
		"shop_offer_id": _shop_offer_id,
		"shop_buy_cost": _shop_buy_cost,
		"shop_refresh_cost": _shop_refresh_cost,
		"shop_last_action": _shop_last_action,
		"deploy_frontline": _deploy_frontline.duplicate(),
		"deploy_bench": _deploy_bench.duplicate(),
		"deploy_frontline_text": "|".join(_deploy_frontline),
		"deploy_bench_text": "|".join(_deploy_bench),
		"deploy_action_count": _deploy_action_count,
		"deploy_last_action": _deploy_last_action,
		"deploy_frozen_frontline_text": deploy_frozen_frontline_text,
		"timer": state_elapsed_sec,
		"is_active": _is_active,
	}

func get_current_wave_payload() -> Dictionary:
	return _current_wave_payload.duplicate(true)

func get_current_battle_summary() -> Dictionary:
	return _current_battle_summary.duplicate(true)

func get_failure_recap_card() -> Dictionary:
	return _failure_recap_card.duplicate(true)

func get_battle_key_events_top3() -> Array[String]:
	var events: Array = _current_battle_summary.get("key_events", [])
	var top3: Array[String] = []
	for idx in range(mini(3, events.size())):
		top3.append(String(events[idx]))
	return top3

func get_recent_match_replay() -> Dictionary:
	if not _last_completed_replay.is_empty():
		return _last_completed_replay.duplicate(true)
	return _build_recent_match_replay_payload().duplicate(true)

func export_recent_match_replay() -> Dictionary:
	var replay_payload := get_recent_match_replay()
	if replay_payload.is_empty():
		return {
			"ok": false,
			"path": PLAYTEST_RECENT_REPLAY_PATH,
			"error_code": "REPLAY_PAYLOAD_EMPTY",
		}

	var json_text := JSON.stringify(replay_payload, "\t")
	var file := FileAccess.open(PLAYTEST_RECENT_REPLAY_PATH, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"path": PLAYTEST_RECENT_REPLAY_PATH,
			"error_code": "RECENT_REPLAY_EXPORT_OPEN_FAILED",
		}

	file.store_string(json_text)
	return {
		"ok": true,
		"path": PLAYTEST_RECENT_REPLAY_PATH,
		"timeline_count": Array(replay_payload.get("timeline", [])).size(),
		"error_code": "",
	}

func export_playtest_match_log() -> Dictionary:
	var phase_timeline := _build_phase_timeline()
	var battle_summaries := _build_battle_summaries()
	var action_trace := _build_action_trace()
	var payload := {
		"schema": "s3_s1_match_timeline_v2",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"match_id": match_id,
		"snapshot": get_state_snapshot(),
		"failure_recap_card": _failure_recap_card.duplicate(true),
		"phase_timeline": phase_timeline,
		"battle_summaries": battle_summaries,
		"action_trace": action_trace,
		"events": _event_logs.duplicate(true),
	}

	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(PLAYTEST_MATCH_LOG_PATH, FileAccess.WRITE)
	if file == null:
		var fail_result := {
			"ok": false,
			"path": PLAYTEST_MATCH_LOG_PATH,
			"phase_count": phase_timeline.size(),
			"battle_count": battle_summaries.size(),
			"action_trace_count": action_trace.size(),
			"error_code": "PLAYTEST_MATCH_LOG_EXPORT_OPEN_FAILED",
		}
		_append_log("playtest_match_log_export_failed", fail_result)
		return fail_result

	file.store_string(json_text)
	var ok_result := {
		"ok": true,
		"path": PLAYTEST_MATCH_LOG_PATH,
		"phase_count": phase_timeline.size(),
		"battle_count": battle_summaries.size(),
		"action_trace_count": action_trace.size(),
		"error_code": "",
	}
	_append_log("playtest_match_log_exported", ok_result)
	return ok_result

func try_shop_placeholder_operation(source: String = "ui") -> Dictionary:
	return try_shop_buy_placeholder(source)

func try_shop_buy_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_SHOP:
		var rejected := {
			"ok": false,
			"error_code": "SHOP_BUY_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected
	if player_gold < _shop_buy_cost:
		var not_enough := {
			"ok": false,
			"error_code": "SHOP_GOLD_INSUFFICIENT",
			"state": current_state,
			"source": source,
			"gold": player_gold,
			"cost": _shop_buy_cost,
		}
		_append_log("placeholder_op_rejected", not_enough)
		return not_enough

	player_gold -= _shop_buy_cost
	_shop_buy_count += 1
	_shop_gold_spent += _shop_buy_cost
	_shop_last_action = "buy"

	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"gold_after": player_gold,
		"cost": _shop_buy_cost,
		"offer_id": _shop_offer_id,
	}
	_append_log("placeholder_op_applied", {
		"op": "shop_buy",
		"source": source,
		"wave": wave_index,
		"gold_after": player_gold,
		"offer_id": _shop_offer_id,
	})
	return accepted

func try_shop_refresh_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_SHOP:
		var rejected := {
			"ok": false,
			"error_code": "SHOP_REFRESH_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected
	if _shop_locked:
		var locked_result := {
			"ok": false,
			"error_code": "SHOP_LOCKED",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", locked_result)
		return locked_result
	if player_gold < _shop_refresh_cost:
		var not_enough := {
			"ok": false,
			"error_code": "SHOP_GOLD_INSUFFICIENT",
			"state": current_state,
			"source": source,
			"gold": player_gold,
			"cost": _shop_refresh_cost,
		}
		_append_log("placeholder_op_rejected", not_enough)
		return not_enough

	player_gold -= _shop_refresh_cost
	_shop_refresh_count += 1
	_shop_gold_spent += _shop_refresh_cost
	_shop_offer_id = _roll_shop_offer()
	_shop_last_action = "refresh"

	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"gold_after": player_gold,
		"cost": _shop_refresh_cost,
		"offer_id": _shop_offer_id,
		"refresh_count": _shop_refresh_count,
	}
	_append_log("placeholder_op_applied", {
		"op": "shop_refresh",
		"source": source,
		"wave": wave_index,
		"gold_after": player_gold,
		"offer_id": _shop_offer_id,
		"refresh_count": _shop_refresh_count,
	})
	return accepted

func toggle_shop_lock_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_SHOP:
		var rejected := {
			"ok": false,
			"error_code": "SHOP_LOCK_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected

	_shop_locked = not _shop_locked
	_shop_last_action = "lock_toggle"
	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"locked": _shop_locked,
	}
	_append_log("placeholder_op_applied", {
		"op": "shop_lock_toggle",
		"source": source,
		"wave": wave_index,
		"locked": _shop_locked,
	})
	return accepted

func try_deploy_placeholder_operation(source: String = "ui") -> Dictionary:
	return try_deploy_place_placeholder(source)

func try_deploy_place_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_DEPLOY:
		var rejected := {
			"ok": false,
			"error_code": "DEPLOY_PLACE_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected

	if _deploy_bench.is_empty():
		var empty_bench := {
			"ok": false,
			"error_code": "DEPLOY_BENCH_EMPTY",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", empty_bench)
		return empty_bench

	var empty_slot := -1
	for idx in range(_deploy_frontline.size()):
		if _deploy_frontline[idx].is_empty():
			empty_slot = idx
			break
	if empty_slot < 0:
		var no_slot := {
			"ok": false,
			"error_code": "DEPLOY_FRONTLINE_FULL",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", no_slot)
		return no_slot

	var unit_id := String(_deploy_bench.pop_front())
	_deploy_frontline[empty_slot] = unit_id
	_deploy_action_count += 1
	_deploy_last_action = "place"

	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"slot": empty_slot,
		"unit_id": unit_id,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	}
	_append_log("placeholder_op_applied", {
		"op": "deploy_place",
		"source": source,
		"wave": wave_index,
		"slot": empty_slot,
		"unit_id": unit_id,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	})
	return accepted

func try_deploy_remove_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_DEPLOY:
		var rejected := {
			"ok": false,
			"error_code": "DEPLOY_REMOVE_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected

	var occupied_slot := -1
	for idx in range(_deploy_frontline.size() - 1, -1, -1):
		if not _deploy_frontline[idx].is_empty():
			occupied_slot = idx
			break
	if occupied_slot < 0:
		var no_unit := {
			"ok": false,
			"error_code": "DEPLOY_FRONTLINE_EMPTY",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", no_unit)
		return no_unit

	var unit_id := _deploy_frontline[occupied_slot]
	_deploy_frontline[occupied_slot] = ""
	_deploy_bench.append(unit_id)
	_deploy_action_count += 1
	_deploy_last_action = "remove"

	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"slot": occupied_slot,
		"unit_id": unit_id,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	}
	_append_log("placeholder_op_applied", {
		"op": "deploy_remove",
		"source": source,
		"wave": wave_index,
		"slot": occupied_slot,
		"unit_id": unit_id,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	})
	return accepted

func try_deploy_swap_placeholder(source: String = "ui") -> Dictionary:
	if current_state != STATE_DEPLOY:
		var rejected := {
			"ok": false,
			"error_code": "DEPLOY_SWAP_DISABLED_BY_PHASE",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", rejected)
		return rejected

	if _deploy_frontline.size() < 2 or _deploy_frontline[0].is_empty() or _deploy_frontline[1].is_empty():
		var invalid_swap := {
			"ok": false,
			"error_code": "DEPLOY_SWAP_NOT_READY",
			"state": current_state,
			"source": source,
		}
		_append_log("placeholder_op_rejected", invalid_swap)
		return invalid_swap

	var tmp := _deploy_frontline[0]
	_deploy_frontline[0] = _deploy_frontline[1]
	_deploy_frontline[1] = tmp
	_deploy_action_count += 1
	_deploy_last_action = "swap"

	var accepted := {
		"ok": true,
		"error_code": "",
		"state": current_state,
		"source": source,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	}
	_append_log("placeholder_op_applied", {
		"op": "deploy_swap",
		"source": source,
		"wave": wave_index,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
	})
	return accepted

func export_battle_key_events_top3() -> Dictionary:
	var top3 := get_battle_key_events_top3()
	var payload := {
		"schema": "s2_n1_battle_top3_v1",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"match_id": match_id,
		"wave": wave_index,
		"battle_result": String(_current_battle_summary.get("result", "")),
		"battle_duration_sec": float(_current_battle_summary.get("duration_sec", 0.0)),
		"top3_key_events": top3,
	}

	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(PLAYTEST_BATTLE_TOP3_LOG_PATH, FileAccess.WRITE)
	if file == null:
		var fail_result := {
			"ok": false,
			"path": PLAYTEST_BATTLE_TOP3_LOG_PATH,
			"top3_count": top3.size(),
			"error_code": "BATTLE_TOP3_EXPORT_OPEN_FAILED",
		}
		_append_log("battle_top3_export_failed", fail_result)
		return fail_result

	file.store_string(json_text)
	var ok_result := {
		"ok": true,
		"path": PLAYTEST_BATTLE_TOP3_LOG_PATH,
		"top3_count": top3.size(),
		"error_code": "",
	}
	_append_log("battle_top3_exported", ok_result)
	return ok_result

func get_remaining_sec() -> float:
	var limit := _get_state_duration(current_state)
	if limit <= 0.0:
		return 0.0
	return maxf(0.0, limit - state_elapsed_sec)

func is_terminal_state(state: String) -> bool:
	return state == STATE_GAME_WIN or state == STATE_GAME_OVER

func _handle_timeout_transition() -> void:
	match current_state:
		STATE_WAVE_PREPARE:
			_request_transition_internal(STATE_SHOP, "timeout_auto_forward", false)
		STATE_SHOP:
			_request_transition_internal(STATE_DEPLOY, "timeout_auto_confirm_shop", false)
		STATE_DEPLOY:
			_request_transition_internal(STATE_BATTLE, "timeout_auto_confirm_deploy", false)
		STATE_BATTLE:
			_request_transition_internal(STATE_RESOLVE, "battle_timeout", false)
		STATE_RESOLVE:
			_resolve_next_state("resolve_timeout")

func _resolve_next_state(reason: String) -> Dictionary:
	if player_hp <= 0:
		return _request_transition_internal(STATE_GAME_OVER, reason, false)
	if wave_index >= WAVE_COUNT:
		if _last_wave_won:
			return _request_transition_internal(STATE_GAME_WIN, reason, false)
		return _request_transition_internal(STATE_GAME_OVER, reason, false)
	wave_index += 1
	return _request_transition_internal(STATE_WAVE_PREPARE, reason, false)

func _request_transition_internal(target_state: String, reason: String, enforce_public_validation: bool) -> Dictionary:
	if not VALID_TRANSITIONS.has(current_state):
		return _build_result(false, "STATE_UNKNOWN", target_state, reason)

	if enforce_public_validation and not _can_transition_to(target_state):
		var reject_payload := {
			"from": current_state,
			"to": target_state,
			"reason": reason,
			"error_code": "ILLEGAL_TRANSITION",
		}
		_append_log("transition_rejected", reject_payload)
		return _build_result(false, "ILLEGAL_TRANSITION", target_state, reason)

	if not enforce_public_validation and not _can_transition_to(target_state):
		var internal_reject := {
			"from": current_state,
			"to": target_state,
			"reason": reason,
			"error_code": "INTERNAL_ILLEGAL_TRANSITION",
		}
		_append_log("transition_rejected", internal_reject)
		return _build_result(false, "INTERNAL_ILLEGAL_TRANSITION", target_state, reason)

	var previous_state := current_state
	current_state = target_state
	state_elapsed_sec = 0.0
	if current_state == STATE_WAVE_PREPARE:
		_prepare_current_wave_payload()
		_current_battle_summary = {}
		_last_resolve_summary = {}
		_shop_refresh_count = 0
		_shop_buy_count = 0
		_shop_gold_spent = 0
		if not _shop_locked:
			_shop_offer_id = _roll_shop_offer()
	if current_state == STATE_DEPLOY:
		_deploy_last_action = ""
		_deploy_frozen_snapshot = {}
	if current_state == STATE_BATTLE:
		_freeze_deploy_snapshot_for_battle(reason)
		_run_battle_settlement()
	if current_state == STATE_RESOLVE:
		_apply_resolve_flow()
	_append_log("state_changed", {
		"from": previous_state,
		"to": target_state,
		"reason": reason,
		"wave": wave_index,
		"wave_type": String(_current_wave_payload.get("wave_type", "")),
	})

	if is_terminal_state(current_state):
		if current_state == STATE_GAME_OVER:
			_failure_recap_card = _build_failure_recap_card()
			_append_log("failure_recap_ready", _failure_recap_card)
		else:
			_failure_recap_card = {}
		_apply_meta_settlement_on_terminal()
		_capture_recent_match_replay()
		_is_active = false

	return _build_result(true, "", target_state, reason)

func _can_transition_to(target_state: String) -> bool:
	var allowed: Array = VALID_TRANSITIONS.get(current_state, [])
	return allowed.has(target_state)

func _build_result(ok: bool, error_code: String, target_state: String, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"error_code": error_code,
		"state": current_state,
		"target_state": target_state,
		"wave": wave_index,
		"reason": reason,
	}

func _get_state_duration(state: String) -> float:
	return float(PHASE_DURATIONS.get(state, 0.0))

func _append_log(event_type: String, payload: Dictionary) -> void:
	_event_logs.append({
		"event_type": event_type,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"match_id": match_id,
		"wave": wave_index,
		"state": current_state,
		"payload": payload,
	})

func _prepare_current_wave_payload() -> void:
	if _wave_generator == null:
		_current_wave_payload = _build_emergency_wave_payload()
		_append_log("wave_payload_ready", {
			"used_fallback": true,
			"error_code": "WAVE_GENERATOR_MISSING",
			"wave_type": String(_current_wave_payload.get("wave_type", "")),
		})
		return

	var result: Dictionary = _wave_generator.generate_wave_payload(
		match_id,
		wave_index,
		_match_seed + wave_index,
		"mvp"
	)
	if result.get("ok", false):
		_current_wave_payload = result.get("wave_payload", {}).duplicate(true)
		_append_log("wave_payload_ready", {
			"used_fallback": bool(result.get("used_fallback", false)),
			"error_code": String(result.get("error_code", "")),
			"wave_type": String(_current_wave_payload.get("wave_type", "")),
			"enemy_count": Array(_current_wave_payload.get("enemy_roster", [])).size(),
		})
		return

	_current_wave_payload = _build_emergency_wave_payload()
	_append_log("wave_payload_ready", {
		"used_fallback": true,
		"error_code": String(result.get("error_code", "WAVE_PAYLOAD_FAILED")),
		"wave_type": String(_current_wave_payload.get("wave_type", "")),
	})

func _run_battle_settlement() -> void:
	var battle_context := _build_battle_context()
	if _battle_resolver == null:
		_current_battle_summary = {
			"result": "enemy",
			"duration_sec": 45.0,
			"ally_power_raw": 0.0,
			"ally_power_modifier": 0.0,
			"battle_context": battle_context,
			"error_code": "BATTLE_RESOLVER_MISSING",
		}
		_append_log("battle_finished", _current_battle_summary)
		return

	var result: Dictionary = _battle_resolver.resolve_battle(
		match_id,
		wave_index,
		_current_wave_payload,
		_match_seed + wave_index * 100,
		battle_context
	)
	if result.get("ok", false):
		_current_battle_summary = result.get("battle_summary", {}).duplicate(true)
		_append_log("battle_finished", _current_battle_summary)
		return

	_current_battle_summary = {
		"result": "enemy",
		"duration_sec": 45.0,
		"ally_power_raw": 0.0,
		"ally_power_modifier": 0.0,
		"battle_context": battle_context,
		"error_code": String(result.get("error_code", "BATTLE_FAILED")),
	}
	_append_log("battle_finished", _current_battle_summary)

func _build_battle_context() -> Dictionary:
	var frozen_frontline: Array = _deploy_frozen_snapshot.get("frontline", [])
	var frontline_count := 0
	for unit in frozen_frontline:
		if not String(unit).is_empty():
			frontline_count += 1
	return {
		"frontline_count": frontline_count,
		"frontline_slot_count": DEPLOY_FRONTLINE_SLOT_COUNT,
		"deploy_action_count": _deploy_action_count,
		"shop_buy_count": _shop_buy_count,
		"shop_refresh_count": _shop_refresh_count,
		"shop_gold_spent": _shop_gold_spent,
		"shop_locked": _shop_locked,
	}

func _build_emergency_wave_payload() -> Dictionary:
	var wave_type := "normal"
	if wave_index == 2:
		wave_type = "elite"
	elif wave_index >= 3:
		wave_type = "boss"
	return {
		"wave_index": wave_index,
		"wave_type": wave_type,
		"enemy_roster": [
			{"unit_id": "enemy_emergency_front", "power": 50, "hp": 140, "atk": 20, "defense": 12},
			{"unit_id": "enemy_emergency_back", "power": 45, "hp": 120, "atk": 22, "defense": 10},
		],
		"spawn_layout": [
			{"unit_id": "enemy_emergency_front", "row": 0, "col": 1},
			{"unit_id": "enemy_emergency_back", "row": 1, "col": 1},
		],
		"wave_modifiers": {"target_power": 120, "difficulty_tag": "emergency_fallback"},
		"wave_revision": 1,
		"seed": _match_seed + wave_index,
	}

func _apply_resolve_flow() -> void:
	var battle_result := String(_current_battle_summary.get("result", "enemy"))
	var is_win := battle_result == "ally"
	_last_wave_won = is_win

	var wave_type := String(_current_wave_payload.get("wave_type", "normal"))
	var gold_delta := _get_wave_gold_reward(wave_type) if is_win else 0
	var hp_delta := 0
	if not is_win:
		hp_delta = -_get_wave_hp_penalty(wave_index)

	player_gold = maxi(0, player_gold + gold_delta)
	player_hp = maxi(0, player_hp + hp_delta)
	_last_resolve_summary = {
		"wave": wave_index,
		"wave_type": wave_type,
		"is_win": is_win,
		"gold_delta": gold_delta,
		"hp_delta": hp_delta,
		"gold_after": player_gold,
		"hp_after": player_hp,
	}
	_append_log("resolve_applied", _last_resolve_summary)

func _get_wave_gold_reward(wave_type: String) -> int:
	if WAVE_GOLD_REWARD_BY_TYPE.has(wave_type):
		return int(WAVE_GOLD_REWARD_BY_TYPE[wave_type])
	if wave_index == 1:
		return 4
	if wave_index == 2:
		return 6
	return 9

func _get_wave_hp_penalty(index: int) -> int:
	if _wave_hp_penalty_by_index.has(index):
		return int(_wave_hp_penalty_by_index[index])
	return 5

func _load_match_balance_config() -> void:
	_shop_buy_cost = DEFAULT_SHOP_BUY_COST
	_shop_refresh_cost = DEFAULT_SHOP_REFRESH_COST
	_wave_hp_penalty_by_index = DEFAULT_WAVE_HP_PENALTY_BY_INDEX.duplicate(true)
	_balance_config_report = {
		"path": MATCH_BALANCE_CONFIG_PATH,
		"used_default": true,
		"error_code": "",
		"shop_buy_cost": _shop_buy_cost,
		"shop_refresh_cost": _shop_refresh_cost,
		"wave_hp_penalty_by_index": _wave_hp_penalty_by_index.duplicate(true),
	}

	if not FileAccess.file_exists(MATCH_BALANCE_CONFIG_PATH):
		_balance_config_report["error_code"] = "CONFIG_FILE_MISSING"
		return

	var file := FileAccess.open(MATCH_BALANCE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		_balance_config_report["error_code"] = "CONFIG_OPEN_FAILED"
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_balance_config_report["error_code"] = "CONFIG_PARSE_INVALID"
		return

	var config: Dictionary = parsed
	var cfg_shop_buy_cost := int(config.get("shop_buy_cost", DEFAULT_SHOP_BUY_COST))
	var cfg_shop_refresh_cost := int(config.get("shop_refresh_cost", DEFAULT_SHOP_REFRESH_COST))
	var penalties_variant: Variant = config.get("wave_hp_penalty_by_index", DEFAULT_WAVE_HP_PENALTY_BY_INDEX)

	if cfg_shop_buy_cost <= 0 or cfg_shop_buy_cost > 99:
		_balance_config_report["error_code"] = "SHOP_BUY_COST_OUT_OF_RANGE"
		return
	if cfg_shop_refresh_cost <= 0 or cfg_shop_refresh_cost > 99:
		_balance_config_report["error_code"] = "SHOP_REFRESH_COST_OUT_OF_RANGE"
		return
	if typeof(penalties_variant) != TYPE_DICTIONARY:
		_balance_config_report["error_code"] = "HP_PENALTY_INVALID_TYPE"
		return

	var penalties_raw: Dictionary = penalties_variant
	var penalties_validated: Dictionary = {}
	for key in penalties_raw.keys():
		var index := int(key)
		var value := int(penalties_raw.get(key, 0))
		if index <= 0 or value <= 0 or value > 99:
			_balance_config_report["error_code"] = "HP_PENALTY_INVALID_RANGE"
			return
		penalties_validated[index] = value

	if penalties_validated.is_empty():
		_balance_config_report["error_code"] = "HP_PENALTY_EMPTY"
		return

	_shop_buy_cost = cfg_shop_buy_cost
	_shop_refresh_cost = cfg_shop_refresh_cost
	_wave_hp_penalty_by_index = penalties_validated.duplicate(true)
	_balance_config_report = {
		"path": MATCH_BALANCE_CONFIG_PATH,
		"used_default": false,
		"error_code": "",
		"shop_buy_cost": _shop_buy_cost,
		"shop_refresh_cost": _shop_refresh_cost,
		"wave_hp_penalty_by_index": _wave_hp_penalty_by_index.duplicate(true),
	}

func _apply_meta_settlement_on_terminal() -> void:
	if _meta_settlement_applied:
		return
	if MetaRuntime == null:
		_meta_settlement_result = {
			"applied": false,
			"error_code": "META_RUNTIME_MISSING",
			"meta_point_delta": 0,
		}
		_append_log("meta_settlement_forward_failed", _meta_settlement_result)
		_meta_settlement_applied = true
		return

	var is_win := current_state == STATE_GAME_WIN
	var wave_cleared := wave_index if _last_wave_won else maxi(0, wave_index - 1)
	var result: Dictionary = MetaRuntime.apply_end_of_match_settlement(
		match_id,
		_meta_reward_revision,
		is_win,
		wave_cleared
	)
	_meta_settlement_result = result.duplicate(true)
	_append_log("meta_settlement_forwarded", {
		"is_win": is_win,
		"wave_cleared": wave_cleared,
		"meta_point_delta": int(result.get("meta_point_delta", 0)),
		"error_code": String(result.get("error_code", "")),
	})
	_meta_settlement_applied = true

func _roll_shop_offer() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash("shop:%s:%d:%d" % [match_id, wave_index, _shop_refresh_count])))
	if SHOP_OFFER_POOL.is_empty():
		return "unit_default"
	return String(SHOP_OFFER_POOL[rng.randi_range(0, SHOP_OFFER_POOL.size() - 1)])

func _reset_deploy_state() -> void:
	_deploy_frontline.clear()
	for _slot_idx in range(DEPLOY_FRONTLINE_SLOT_COUNT):
		_deploy_frontline.append("")
	_deploy_bench.clear()
	for unit in DEPLOY_INITIAL_BENCH:
		_deploy_bench.append(String(unit))
	_deploy_action_count = 0
	_deploy_last_action = ""
	_deploy_frozen_snapshot = {}

func _freeze_deploy_snapshot_for_battle(reason: String) -> void:
	_deploy_frozen_snapshot = {
		"wave": wave_index,
		"reason": reason,
		"frontline": _deploy_frontline.duplicate(),
		"bench": _deploy_bench.duplicate(),
		"action_count": _deploy_action_count,
		"last_action": _deploy_last_action,
	}
	_append_log("deploy_frozen_for_battle", _deploy_frozen_snapshot.duplicate(true))

func _build_failure_recap_card() -> Dictionary:
	var wave_type := String(_current_wave_payload.get("wave_type", "normal"))
	var battle_result := String(_current_battle_summary.get("result", "enemy"))
	var root_cause := "battle_loss"
	var summary := "本波战斗失利"

	if player_hp <= 0:
		root_cause = "hp_depleted"
		summary = "生命值归零"
	elif wave_type == "boss":
		root_cause = "boss_pressure"
		summary = "Boss 波次压力过高"
	elif battle_result != "ally":
		root_cause = "formation_or_power_gap"
		summary = "阵容强度或站位未通过检定"

	return {
		"failed_wave": wave_index,
		"wave_type": wave_type,
		"root_cause": root_cause,
		"summary": summary,
		"battle_result": battle_result,
	}

func _build_phase_timeline() -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for log_entry in _event_logs:
		var event_type := String(log_entry.get("event_type", ""))
		if event_type != "state_changed":
			continue
		var payload: Dictionary = log_entry.get("payload", {})
		timeline.append({
			"timestamp_unix": log_entry.get("timestamp_unix", 0),
			"wave": int(log_entry.get("wave", 0)),
			"from": String(payload.get("from", "")),
			"to": String(payload.get("to", "")),
			"reason": String(payload.get("reason", "")),
			"wave_type": String(payload.get("wave_type", "")),
		})
	return timeline

func _build_battle_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for log_entry in _event_logs:
		var event_type := String(log_entry.get("event_type", ""))
		if event_type != "battle_finished":
			continue
		var payload: Dictionary = log_entry.get("payload", {})
		summaries.append({
			"timestamp_unix": log_entry.get("timestamp_unix", 0),
			"wave": int(log_entry.get("wave", 0)),
			"result": String(payload.get("result", "")),
			"duration_sec": float(payload.get("duration_sec", 0.0)),
			"ally_power": float(payload.get("ally_power", 0.0)),
			"enemy_power": float(payload.get("enemy_power", 0.0)),
			"wave_type": String(payload.get("wave_type", "")),
		})
	return summaries

func _capture_recent_match_replay() -> void:
	_last_completed_replay = _build_recent_match_replay_payload().duplicate(true)
	_append_log("recent_replay_captured", {
		"timeline_count": Array(_last_completed_replay.get("timeline", [])).size(),
		"match_id": String(_last_completed_replay.get("match_id", "")),
	})

func _build_recent_match_replay_payload() -> Dictionary:
	if _event_logs.is_empty():
		return {}
	return {
		"schema": "s3_n1_recent_replay_v1",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"match_id": match_id,
		"result_state": current_state,
		"snapshot": get_state_snapshot(),
		"failure_recap_card": _failure_recap_card.duplicate(true),
		"timeline": _build_recent_replay_timeline(),
	}

func _build_recent_replay_timeline() -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for log_entry in _event_logs:
		var event_type := String(log_entry.get("event_type", ""))
		if event_type != "state_changed" and event_type != "battle_finished" and event_type != "resolve_applied":
			continue

		var payload: Dictionary = log_entry.get("payload", {})
		var summary := ""
		if event_type == "state_changed":
			summary = "%s -> %s (%s)" % [String(payload.get("from", "")), String(payload.get("to", "")), String(payload.get("reason", ""))]
		elif event_type == "battle_finished":
			summary = "battle=%s, dur=%.1fs" % [String(payload.get("result", "")), float(payload.get("duration_sec", 0.0))]
		elif event_type == "resolve_applied":
			summary = "resolve win=%s, Δgold=%+d, Δhp=%+d" % [
				"Y" if bool(payload.get("is_win", false)) else "N",
				int(payload.get("gold_delta", 0)),
				int(payload.get("hp_delta", 0)),
			]

		timeline.append({
			"timestamp_unix": log_entry.get("timestamp_unix", 0),
			"wave": int(log_entry.get("wave", 0)),
			"state": String(log_entry.get("state", "")),
			"event_type": event_type,
			"summary": summary,
		})
	return timeline

func _build_action_trace() -> Array[Dictionary]:
	var traces: Array[Dictionary] = []
	for log_entry in _event_logs:
		var event_type := String(log_entry.get("event_type", ""))
		if event_type != "placeholder_op_applied" and event_type != "placeholder_op_rejected":
			continue

		var payload: Dictionary = log_entry.get("payload", {})
		var op := String(payload.get("op", ""))
		var error_code := String(payload.get("error_code", ""))
		var domain := ""
		if op.begins_with("shop_") or error_code.begins_with("SHOP_"):
			domain = "shop"
		elif op.begins_with("deploy_") or error_code.begins_with("DEPLOY_"):
			domain = "deploy"
		if domain.is_empty():
			continue

		traces.append({
			"timestamp_unix": log_entry.get("timestamp_unix", 0),
			"wave": int(log_entry.get("wave", 0)),
			"state": String(log_entry.get("state", "")),
			"domain": domain,
			"status": "applied" if event_type == "placeholder_op_applied" else "rejected",
			"op": op if not op.is_empty() else _infer_op_from_error(error_code),
			"error_code": error_code,
			"source": String(payload.get("source", "")),
			"gold_after": int(payload.get("gold_after", -1)),
			"offer_id": String(payload.get("offer_id", "")),
			"refresh_count": int(payload.get("refresh_count", -1)),
			"slot": int(payload.get("slot", -1)),
			"unit_id": String(payload.get("unit_id", "")),
			"frontline": Array(payload.get("frontline", [])).duplicate(),
			"bench": Array(payload.get("bench", [])).duplicate(),
		})
	return traces

func _infer_op_from_error(error_code: String) -> String:
	if error_code.begins_with("SHOP_BUY") or error_code == "SHOP_GOLD_INSUFFICIENT":
		return "shop_buy"
	if error_code.begins_with("SHOP_REFRESH") or error_code == "SHOP_LOCKED":
		return "shop_refresh"
	if error_code.begins_with("SHOP_LOCK"):
		return "shop_lock_toggle"
	if error_code.begins_with("DEPLOY_PLACE") or error_code == "DEPLOY_FRONTLINE_FULL" or error_code == "DEPLOY_BENCH_EMPTY":
		return "deploy_place"
	if error_code.begins_with("DEPLOY_REMOVE") or error_code == "DEPLOY_FRONTLINE_EMPTY":
		return "deploy_remove"
	if error_code.begins_with("DEPLOY_SWAP"):
		return "deploy_swap"
	return "unknown"
