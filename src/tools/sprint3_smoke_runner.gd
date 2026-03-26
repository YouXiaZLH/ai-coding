extends Node

const MatchStateMachine := preload("res://src/core/match_state_machine.gd")
const REPORT_PATH := "res://production/gate-checks/2026-03-26-sprint-003-smoke-run-02.json"

var _cases: Array[Dictionary] = []

func _ready() -> void:
	var machine := MatchStateMachine.new()
	_run_smoke(machine)
	_emit_report()
	get_tree().quit()

func _run_smoke(machine: RefCounted) -> void:
	var start_result: Dictionary = machine.start_match("sprint3_smoke_run02")
	_push_case("S3-SMOKE-01", bool(start_result.get("ok", false)), "状态机启动")

	machine.request_transition("SHOP", "smoke_enter_shop")
	var snapshot_before_buy: Dictionary = machine.get_state_snapshot()
	var buy_result: Dictionary = machine.try_shop_buy_placeholder("smoke")
	var snapshot_after_buy: Dictionary = machine.get_state_snapshot()
	var buy_ok := bool(buy_result.get("ok", false)) and int(snapshot_after_buy.get("player_gold", 0)) < int(snapshot_before_buy.get("player_gold", 0))
	_push_case("S3-SMOKE-02", buy_ok, "SHOP 买入")

	var refresh_result: Dictionary = machine.try_shop_refresh_placeholder("smoke")
	_push_case("S3-SMOKE-03", bool(refresh_result.get("ok", false)), "SHOP 刷新")

	var lock_on: Dictionary = machine.toggle_shop_lock_placeholder("smoke")
	var locked_refresh: Dictionary = machine.try_shop_refresh_placeholder("smoke")
	var lock_off: Dictionary = machine.toggle_shop_lock_placeholder("smoke")
	var unlocked_refresh: Dictionary = machine.try_shop_refresh_placeholder("smoke")
	var lock_case_ok := bool(lock_on.get("ok", false)) and not bool(locked_refresh.get("ok", true)) and String(locked_refresh.get("error_code", "")) == "SHOP_LOCKED" and bool(lock_off.get("ok", false)) and bool(unlocked_refresh.get("ok", false))
	_push_case("S3-SMOKE-04", lock_case_ok, "SHOP 锁定/解锁")

	machine.confirm_current_state()
	var illegal_shop: Dictionary = machine.try_shop_buy_placeholder("smoke")
	_push_case("S3-SMOKE-05", not bool(illegal_shop.get("ok", true)), "SHOP 非法阶段拒绝")

	var deploy_place: Dictionary = machine.try_deploy_place_placeholder("smoke")
	_push_case("S3-SMOKE-06", bool(deploy_place.get("ok", false)), "DEPLOY 上阵")

	var deploy_remove: Dictionary = machine.try_deploy_remove_placeholder("smoke")
	_push_case("S3-SMOKE-07", bool(deploy_remove.get("ok", false)), "DEPLOY 下阵")

	machine.try_deploy_place_placeholder("smoke")
	machine.try_deploy_place_placeholder("smoke")
	var deploy_swap: Dictionary = machine.try_deploy_swap_placeholder("smoke")
	_push_case("S3-SMOKE-08", bool(deploy_swap.get("ok", false)), "DEPLOY 换位")

	machine.confirm_current_state()
	var illegal_deploy: Dictionary = machine.try_deploy_place_placeholder("smoke")
	_push_case("S3-SMOKE-09", not bool(illegal_deploy.get("ok", true)), "DEPLOY 非法阶段拒绝")

	var battle_snapshot: Dictionary = machine.get_state_snapshot()
	var battle_ok := not String(battle_snapshot.get("battle_result", "")).is_empty() and battle_snapshot.has("battle_frontline_count") and battle_snapshot.has("battle_shop_buy_count")
	_push_case("S3-SMOKE-10", battle_ok, "BATTLE 上下文生效")

	machine.confirm_current_state()
	var resolve_snapshot: Dictionary = machine.get_state_snapshot()
	var resolve_ok := resolve_snapshot.has("resolve_gold_delta") and resolve_snapshot.has("resolve_hp_delta") and resolve_snapshot.has("resolve_gold_after") and resolve_snapshot.has("resolve_hp_after")
	_push_case("S3-SMOKE-11", resolve_ok, "BATTLE->RESOLVE 资源结算")

	var resolve_panel_ok := resolve_snapshot.has("resolve_is_win") and not String(resolve_snapshot.get("resolve_wave_type", "")).is_empty()
	_push_case("S3-SMOKE-12", resolve_panel_ok, "RESOLVE 面板字段可读")

	var machine_fail := MatchStateMachine.new()
	machine_fail.start_match("sprint3_smoke_run02_fail")
	machine_fail.request_transition("SHOP", "smoke_enter_shop")
	machine_fail.confirm_current_state()
	machine_fail.confirm_current_state()
	machine_fail.confirm_current_state()
	machine_fail.player_hp = 0
	machine_fail.confirm_current_state()
	var recap: Dictionary = machine_fail.get_failure_recap_card()
	_push_case("S3-SMOKE-13", not recap.is_empty(), "失败复盘卡生成")

	var export_match: Dictionary = machine.export_playtest_match_log()
	var export_top3: Dictionary = machine.export_battle_key_events_top3()
	var export_ok := bool(export_match.get("ok", false)) and bool(export_top3.get("ok", false))
	_push_case("S3-SMOKE-14", export_ok, "日志导出")

func _push_case(case_id: String, passed: bool, note: String) -> void:
	_cases.append({
		"id": case_id,
		"passed": passed,
		"note": note,
	})

func _emit_report() -> void:
	var passed := 0
	for case_item in _cases:
		if bool(case_item.get("passed", false)):
			passed += 1
	var report := {
		"schema": "s3_smoke_run02_v1",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"total": _cases.size(),
		"passed": passed,
		"failed": _cases.size() - passed,
		"cases": _cases,
	}

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))

	print("S3_SMOKE_RUN02_SUMMARY=" + JSON.stringify(report))
