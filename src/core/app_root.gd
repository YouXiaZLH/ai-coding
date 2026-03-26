extends Control

const META_SCENE_PATH := "res://scenes/MetaUnlockPlaceholder.tscn"
const MatchStateMachine := preload("res://src/core/match_state_machine.gd")

@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var state_label: Label = $CenterContainer/VBoxContainer/StateLabel
@onready var timer_label: Label = $CenterContainer/VBoxContainer/TimerLabel
@onready var wave_label: Label = $CenterContainer/VBoxContainer/WaveLabel
@onready var battle_label: Label = $CenterContainer/VBoxContainer/BattleLabel
@onready var battle_top3_label: Label = $CenterContainer/VBoxContainer/BattleTop3Label
@onready var resource_label: Label = $CenterContainer/VBoxContainer/ResourceLabel
@onready var settlement_label: Label = $CenterContainer/VBoxContainer/SettlementLabel
@onready var recap_card_label: Label = $CenterContainer/VBoxContainer/RecapCardLabel
@onready var resolve_panel_label: Label = $CenterContainer/VBoxContainer/ResolvePanelLabel
@onready var replay_summary_label: Label = $CenterContainer/VBoxContainer/ReplaySummaryLabel
@onready var shop_info_label: Label = $CenterContainer/VBoxContainer/ShopInfoLabel
@onready var deploy_info_label: Label = $CenterContainer/VBoxContainer/DeployInfoLabel
@onready var hud_label: Label = $CenterContainer/VBoxContainer/HudLabel
@onready var toast_label: Label = $CenterContainer/VBoxContainer/ToastLabel
@onready var state_action_label: Label = $CenterContainer/VBoxContainer/StateActionLabel
@onready var start_match_button: Button = $CenterContainer/VBoxContainer/StartMatchButton
@onready var confirm_state_button: Button = $CenterContainer/VBoxContainer/ConfirmStateButton
@onready var toggle_debug_view_button: Button = $CenterContainer/VBoxContainer/ToggleDebugViewButton
@onready var invalid_jump_button: Button = $CenterContainer/VBoxContainer/InvalidJumpButton
@onready var shop_write_button: Button = $CenterContainer/VBoxContainer/ShopWriteButton
@onready var shop_refresh_button: Button = $CenterContainer/VBoxContainer/ShopRefreshButton
@onready var shop_lock_button: Button = $CenterContainer/VBoxContainer/ShopLockButton
@onready var deploy_write_button: Button = $CenterContainer/VBoxContainer/DeployWriteButton
@onready var deploy_remove_button: Button = $CenterContainer/VBoxContainer/DeployRemoveButton
@onready var deploy_swap_button: Button = $CenterContainer/VBoxContainer/DeploySwapButton
@onready var export_match_log_button: Button = $CenterContainer/VBoxContainer/ExportMatchLogButton
@onready var export_battle_top3_button: Button = $CenterContainer/VBoxContainer/ExportBattleTop3Button
@onready var replay_recent_button: Button = $CenterContainer/VBoxContainer/ReplayRecentButton
@onready var enter_button: Button = $CenterContainer/VBoxContainer/EnterButton

var _state_machine: RefCounted
var _match_seq: int = 1
var _toast_left_sec: float = 0.0
var _debug_view_enabled: bool = false

func _ready() -> void:
	_ensure_input_map()
	_state_machine = MatchStateMachine.new()
	status_label.text = "当前状态：主界面占位 | 局外点数：%d" % MetaRuntime.get_meta_point()
	state_action_label.text = "S2-M1：状态机未启动"
	start_match_button.pressed.connect(_on_start_match_button_pressed)
	confirm_state_button.pressed.connect(_on_confirm_state_button_pressed)
	toggle_debug_view_button.pressed.connect(_on_toggle_debug_view_button_pressed)
	invalid_jump_button.pressed.connect(_on_invalid_jump_button_pressed)
	shop_write_button.pressed.connect(_on_shop_write_button_pressed)
	shop_refresh_button.pressed.connect(_on_shop_refresh_button_pressed)
	shop_lock_button.pressed.connect(_on_shop_lock_button_pressed)
	deploy_write_button.pressed.connect(_on_deploy_write_button_pressed)
	deploy_remove_button.pressed.connect(_on_deploy_remove_button_pressed)
	deploy_swap_button.pressed.connect(_on_deploy_swap_button_pressed)
	export_match_log_button.pressed.connect(_on_export_match_log_button_pressed)
	export_battle_top3_button.pressed.connect(_on_export_battle_top3_button_pressed)
	replay_recent_button.pressed.connect(_on_replay_recent_button_pressed)
	enter_button.pressed.connect(_on_enter_button_pressed)
	_refresh_status_view()

func _process(delta: float) -> void:
	if _state_machine != null:
		_state_machine.tick(delta)
	status_label.text = "当前状态：主界面占位 | 局外点数：%d" % MetaRuntime.get_meta_point()
	if _toast_left_sec > 0.0:
		_toast_left_sec = maxf(0.0, _toast_left_sec - delta)
		if _toast_left_sec <= 0.0:
			toast_label.visible = false
	_refresh_status_view()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("meta_open_unlock"):
		_open_meta_unlock()
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_1:
			_attempt_shop_buy("shortcut")
		elif key_event.keycode == KEY_2:
			_attempt_deploy_place("shortcut")
		elif key_event.keycode == KEY_3:
			_attempt_shop_refresh("shortcut")
		elif key_event.keycode == KEY_4:
			_attempt_deploy_swap("shortcut")

func _on_enter_button_pressed() -> void:
	_open_meta_unlock()

func _on_start_match_button_pressed() -> void:
	var match_id := "demo_match_%03d" % _match_seq
	_match_seq += 1
	var result: Dictionary = _state_machine.start_match(match_id)
	if result.get("ok", false):
		state_action_label.text = "状态机启动成功：%s" % match_id
	else:
		state_action_label.text = "启动失败：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))

func _on_confirm_state_button_pressed() -> void:
	var result: Dictionary = _state_machine.confirm_current_state()
	if result.get("ok", false):
		state_action_label.text = "已确认并推进状态"
	else:
		state_action_label.text = "确认失败：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))

func _on_invalid_jump_button_pressed() -> void:
	var result: Dictionary = _state_machine.request_transition("RESOLVE", "debug_invalid_jump")
	if result.get("ok", false):
		state_action_label.text = "已跳转到 %s" % String(result.get("state", ""))
	else:
		state_action_label.text = "非法跳转已拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))

func _on_toggle_debug_view_button_pressed() -> void:
	_debug_view_enabled = not _debug_view_enabled
	toggle_debug_view_button.text = "隐藏调试信息" if _debug_view_enabled else "显示调试信息"
	_show_toast("调试信息：%s" % ("开启" if _debug_view_enabled else "关闭"))

func _on_shop_write_button_pressed() -> void:
	_attempt_shop_buy("button")

func _on_shop_refresh_button_pressed() -> void:
	_attempt_shop_refresh("button")

func _on_shop_lock_button_pressed() -> void:
	_attempt_shop_lock_toggle("button")

func _on_deploy_write_button_pressed() -> void:
	_attempt_deploy_place("button")

func _on_deploy_remove_button_pressed() -> void:
	_attempt_deploy_remove("button")

func _on_deploy_swap_button_pressed() -> void:
	_attempt_deploy_swap("button")

func _on_export_match_log_button_pressed() -> void:
	if _state_machine == null:
		state_action_label.text = "状态机未初始化，无法导出日志"
		return
	var export_result: Dictionary = _state_machine.export_playtest_match_log()
	if export_result.get("ok", false):
		state_action_label.text = "日志已导出：phase=%d, battle=%d, action=%d" % [
			int(export_result.get("phase_count", 0)),
			int(export_result.get("battle_count", 0)),
			int(export_result.get("action_trace_count", 0)),
		]
	else:
		state_action_label.text = "导出失败：%s" % String(export_result.get("error_code", "EXPORT_FAILED"))

func _on_export_battle_top3_button_pressed() -> void:
	if _state_machine == null:
		state_action_label.text = "状态机未初始化，无法导出 Top3"
		return
	var export_result: Dictionary = _state_machine.export_battle_key_events_top3()
	if export_result.get("ok", false):
		state_action_label.text = "Top3 已导出：count=%d" % int(export_result.get("top3_count", 0))
	else:
		state_action_label.text = "Top3 导出失败：%s" % String(export_result.get("error_code", "EXPORT_FAILED"))

func _on_replay_recent_button_pressed() -> void:
	if _state_machine == null:
		state_action_label.text = "状态机未初始化，无法回放"
		return
	var replay: Dictionary = _state_machine.get_recent_match_replay()
	if replay.is_empty():
		replay_summary_label.text = "最近一局回放：暂无可回放数据"
		state_action_label.text = "回放失败：暂无最近一局"
		return

	var timeline: Array = replay.get("timeline", [])
	var lines: Array[String] = []
	for idx in range(mini(6, timeline.size())):
		var item: Dictionary = timeline[idx]
		lines.append("[%d] W%d %s" % [idx + 1, int(item.get("wave", 0)), String(item.get("summary", ""))])
	replay_summary_label.text = "最近一局回放：%s\n%s" % [
		String(replay.get("match_id", "")),
		"\n".join(lines),
	]

	var export_result: Dictionary = _state_machine.export_recent_match_replay()
	if export_result.get("ok", false):
		state_action_label.text = "最近一局回放已导出：timeline=%d" % int(export_result.get("timeline_count", 0))
	else:
		state_action_label.text = "回放导出失败：%s" % String(export_result.get("error_code", "EXPORT_FAILED"))

func _open_meta_unlock() -> void:
	get_tree().change_scene_to_file(META_SCENE_PATH)

func _ensure_input_map() -> void:
	if not InputMap.has_action("meta_open_unlock"):
		InputMap.add_action("meta_open_unlock")
	var open_event := InputEventKey.new()
	open_event.keycode = KEY_O
	if not InputMap.action_has_event("meta_open_unlock", open_event):
		InputMap.action_add_event("meta_open_unlock", open_event)

func _refresh_status_view() -> void:
	if _state_machine == null:
		state_label.text = "状态机：未初始化"
		timer_label.text = "剩余时间：--"
		wave_label.text = "波次载荷：--"
		battle_label.text = "战斗摘要：--"
		battle_top3_label.text = "战斗关键事件 Top3：--"
		resource_label.text = "局内资源：--"
		settlement_label.text = "局外结算：--"
		recap_card_label.text = "失败复盘卡：--"
		resolve_panel_label.text = "RESOLVE 面板：--"
		replay_summary_label.text = "最近一局回放：--"
		shop_info_label.text = "商店信息：--"
		deploy_info_label.text = "布阵信息：--"
		hud_label.text = "HUD：Wave -- | Gold -- | HP -- | Timer --"
		toast_label.visible = false
		confirm_state_button.disabled = true
		toggle_debug_view_button.disabled = true
		invalid_jump_button.disabled = true
		shop_write_button.disabled = true
		deploy_write_button.disabled = true
		return

	toggle_debug_view_button.disabled = false
	toggle_debug_view_button.text = "隐藏调试信息" if _debug_view_enabled else "显示调试信息"

	var snapshot: Dictionary = _state_machine.get_state_snapshot()
	var state := String(snapshot.get("state", "BOOT"))
	var wave := int(snapshot.get("wave", 1))
	var wave_type := String(snapshot.get("wave_type", ""))
	var enemy_count := int(snapshot.get("enemy_count", 0))
	var battle_result := String(snapshot.get("battle_result", ""))
	var battle_duration := float(snapshot.get("battle_duration_sec", 0.0))
	var battle_ally_power_raw := float(snapshot.get("battle_ally_power_raw", 0.0))
	var battle_ally_power_modifier := float(snapshot.get("battle_ally_power_modifier", 0.0))
	var battle_frontline_count := int(snapshot.get("battle_frontline_count", 0))
	var battle_shop_buy_count := int(snapshot.get("battle_shop_buy_count", 0))
	var battle_shop_refresh_count := int(snapshot.get("battle_shop_refresh_count", 0))
	var battle_top3: Array[String] = _state_machine.get_battle_key_events_top3()
	var player_hp := int(snapshot.get("player_hp", 0))
	var player_gold := int(snapshot.get("player_gold", 0))
	var resolve_gold_delta := int(snapshot.get("resolve_gold_delta", 0))
	var resolve_hp_delta := int(snapshot.get("resolve_hp_delta", 0))
	var resolve_is_win := bool(snapshot.get("resolve_is_win", false))
	var resolve_wave_type := String(snapshot.get("resolve_wave_type", ""))
	var resolve_gold_after := int(snapshot.get("resolve_gold_after", player_gold))
	var resolve_hp_after := int(snapshot.get("resolve_hp_after", player_hp))
	var meta_point_delta := int(snapshot.get("meta_point_delta", 0))
	var shop_locked := bool(snapshot.get("shop_locked", false))
	var shop_refresh_count := int(snapshot.get("shop_refresh_count", 0))
	var shop_offer_id := String(snapshot.get("shop_offer_id", ""))
	var shop_buy_cost := int(snapshot.get("shop_buy_cost", 0))
	var shop_refresh_cost := int(snapshot.get("shop_refresh_cost", 0))
	var shop_last_action := String(snapshot.get("shop_last_action", ""))
	var deploy_frontline_text := String(snapshot.get("deploy_frontline_text", ""))
	var deploy_bench_text := String(snapshot.get("deploy_bench_text", ""))
	var deploy_action_count := int(snapshot.get("deploy_action_count", 0))
	var deploy_last_action := String(snapshot.get("deploy_last_action", ""))
	var deploy_frozen_frontline_text := String(snapshot.get("deploy_frozen_frontline_text", ""))
	var recap_card: Dictionary = _state_machine.get_failure_recap_card()
	state_label.text = "状态机：%s | Wave %d" % [state, wave]
	timer_label.text = "阶段剩余：%.1f 秒" % float(_state_machine.get_remaining_sec())
	wave_label.text = "波次载荷：%s | 敌方单位:%d" % [wave_type, enemy_count]
	hud_label.text = "HUD：Wave %d(%s) | Gold %d | HP %d | Timer %.1fs" % [wave, wave_type, player_gold, player_hp, float(_state_machine.get_remaining_sec())]
	if battle_result.is_empty():
		battle_label.text = "战斗摘要：等待 BATTLE 阶段结算"
	else:
		battle_label.text = "战斗摘要：结果=%s | 时长=%.1fs | ally_raw=%.1f(mod=%.1f) | ctx(front=%d,buy=%d,refresh=%d)" % [
			battle_result,
			battle_duration,
			battle_ally_power_raw,
			battle_ally_power_modifier,
			battle_frontline_count,
			battle_shop_buy_count,
			battle_shop_refresh_count,
		]
	battle_top3_label.text = "战斗关键事件 Top3：%s" % (" | ".join(battle_top3) if not battle_top3.is_empty() else "--")
	resource_label.text = "局内资源：Gold=%d (Δ%d) | HP=%d (Δ%d)" % [player_gold, resolve_gold_delta, player_hp, resolve_hp_delta]
	settlement_label.text = "局外结算：meta_point_delta=%d" % meta_point_delta
	shop_info_label.text = "商店信息：offer=%s | lock=%s | refresh=%d | buy=%d refresh=%d | last=%s" % [shop_offer_id, "ON" if shop_locked else "OFF", shop_refresh_count, shop_buy_cost, shop_refresh_cost, shop_last_action]
	deploy_info_label.text = "布阵信息：front=%s | bench=%s | action=%d/%s | frozen=%s" % [deploy_frontline_text, deploy_bench_text, deploy_action_count, deploy_last_action, deploy_frozen_frontline_text]
	var recap_summary := "--"
	if recap_card.is_empty():
		recap_card_label.text = "失败复盘卡：--"
	else:
		recap_summary = "wave=%d(%s),cause=%s" % [
			int(recap_card.get("failed_wave", 0)),
			String(recap_card.get("wave_type", "")),
			String(recap_card.get("root_cause", "")),
		]
		recap_card_label.text = "失败复盘卡：Wave %d(%s) | 主因=%s" % [
			int(recap_card.get("failed_wave", 0)),
			String(recap_card.get("wave_type", "")),
			String(recap_card.get("root_cause", "")),
		]

	if state == "RESOLVE" or state == "GAME_WIN" or state == "GAME_OVER":
		resolve_panel_label.text = "RESOLVE 面板：result=%s(%s) | Δgold=%+d -> %d | Δhp=%+d -> %d | meta=%+d | recap=%s" % [
			"WIN" if resolve_is_win else "LOSE",
			resolve_wave_type,
			resolve_gold_delta,
			resolve_gold_after,
			resolve_hp_delta,
			resolve_hp_after,
			meta_point_delta,
			recap_summary,
		]
	else:
		resolve_panel_label.text = "RESOLVE 面板：等待 RESOLVE 阶段"

	if state != "BOOT":
		var replay_snapshot: Dictionary = _state_machine.get_recent_match_replay()
		if replay_snapshot.is_empty():
			replay_summary_label.text = "最近一局回放：暂无"
		else:
			var replay_timeline: Array = replay_snapshot.get("timeline", [])
			replay_summary_label.text = "最近一局回放：match=%s | timeline=%d" % [
				String(replay_snapshot.get("match_id", "")),
				replay_timeline.size(),
			]

	var allow_confirm := state == "SHOP" or state == "DEPLOY" or state == "BATTLE" or state == "RESOLVE"
	var allow_shop_write := state == "SHOP"
	var allow_deploy_write := state == "DEPLOY"
	confirm_state_button.disabled = not allow_confirm
	invalid_jump_button.disabled = not _debug_view_enabled
	shop_write_button.disabled = not allow_shop_write
	shop_refresh_button.disabled = not allow_shop_write
	shop_lock_button.disabled = not allow_shop_write
	deploy_write_button.disabled = not allow_deploy_write
	deploy_remove_button.disabled = not allow_deploy_write
	deploy_swap_button.disabled = not allow_deploy_write
	replay_recent_button.disabled = _state_machine.get_recent_match_replay().is_empty() and _debug_view_enabled

	battle_top3_label.visible = _debug_view_enabled
	shop_info_label.visible = _debug_view_enabled
	deploy_info_label.visible = _debug_view_enabled
	replay_summary_label.visible = _debug_view_enabled
	state_action_label.visible = _debug_view_enabled
	invalid_jump_button.visible = _debug_view_enabled
	export_match_log_button.visible = _debug_view_enabled
	export_battle_top3_button.visible = _debug_view_enabled
	replay_recent_button.visible = _debug_view_enabled

func _attempt_shop_buy(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.try_shop_buy_placeholder(source)
	if result.get("ok", false):
		state_action_label.text = "商店买入成功：gold=%d" % int(result.get("gold_after", 0))
		_show_toast("商店买入占位操作成功")
	else:
		state_action_label.text = "商店买入被拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("商店买入失败：阶段不匹配或金币不足")

func _attempt_shop_refresh(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.try_shop_refresh_placeholder(source)
	if result.get("ok", false):
		state_action_label.text = "商店刷新成功：offer=%s" % String(result.get("offer_id", ""))
		_show_toast("商店刷新成功")
	else:
		state_action_label.text = "商店刷新被拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("商店刷新失败：阶段不匹配/金币不足/商店锁定")

func _attempt_shop_lock_toggle(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.toggle_shop_lock_placeholder(source)
	if result.get("ok", false):
		var lock_on := bool(result.get("locked", false))
		state_action_label.text = "商店锁定切换：%s" % ("ON" if lock_on else "OFF")
		_show_toast("商店锁定已%s" % ("开启" if lock_on else "关闭"))
	else:
		state_action_label.text = "商店锁定切换失败：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("非法操作：仅 SHOP 阶段可切换锁定")

func _attempt_deploy_place(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.try_deploy_place_placeholder(source)
	if result.get("ok", false):
		state_action_label.text = "上阵成功：slot=%d unit=%s" % [int(result.get("slot", -1)), String(result.get("unit_id", ""))]
		_show_toast("DEPLOY 上阵成功")
	else:
		state_action_label.text = "上阵被拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("DEPLOY 上阵失败：阶段不匹配/前排已满/候补为空")

func _attempt_deploy_remove(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.try_deploy_remove_placeholder(source)
	if result.get("ok", false):
		state_action_label.text = "下阵成功：slot=%d unit=%s" % [int(result.get("slot", -1)), String(result.get("unit_id", ""))]
		_show_toast("DEPLOY 下阵成功")
	else:
		state_action_label.text = "下阵被拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("DEPLOY 下阵失败：阶段不匹配或前排为空")

func _attempt_deploy_swap(source: String) -> void:
	if _state_machine == null:
		_show_toast("状态机未初始化")
		return
	var result: Dictionary = _state_machine.try_deploy_swap_placeholder(source)
	if result.get("ok", false):
		state_action_label.text = "换位成功：frontline=%s" % String(snapshot_to_frontline_text(result))
		_show_toast("DEPLOY 换位成功")
	else:
		state_action_label.text = "换位被拒绝：%s" % String(result.get("error_code", "UNKNOWN_ERROR"))
		_show_toast("DEPLOY 换位失败：需要前两位均已上阵")

func snapshot_to_frontline_text(result: Dictionary) -> String:
	var frontline: Array = result.get("frontline", [])
	return "|".join(frontline)

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	_toast_left_sec = 1.5
