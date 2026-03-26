extends Control

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DEMO_MATCH_ID := "demo_match_001"
const DEMO_REWARD_REVISION := 1
const DEMO_PLAYER_ID := "local_player"
const DEMO_UNLOCK_ID := "hint_opening_tactics"
const DEMO_UNLOCK_ID_2 := "cosmetic_banner_lv1"

var _unlock_request_seq: int = 1
var _last_settlement_delta: int = 0

@onready var content_label: Label = $CenterContainer/VBoxContainer/ContentLabel
@onready var guide_label: Label = $CenterContainer/VBoxContainer/GuideLabel
@onready var meta_point_label: Label = $CenterContainer/VBoxContainer/MetaPointLabel
@onready var s4m3_pipeline_label: Label = $CenterContainer/VBoxContainer/S4M3PipelineLabel
@onready var settle_button: Button = $CenterContainer/VBoxContainer/SettleButton
@onready var unlock_status_label: Label = $CenterContainer/VBoxContainer/UnlockStatusLabel
@onready var unlock_button: Button = $CenterContainer/VBoxContainer/UnlockButton
@onready var unlock_status_label_2: Label = $CenterContainer/VBoxContainer/UnlockStatusLabel2
@onready var unlock_button_2: Button = $CenterContainer/VBoxContainer/UnlockButton2
@onready var save_button: Button = $CenterContainer/VBoxContainer/SaveButton
@onready var reload_button: Button = $CenterContainer/VBoxContainer/ReloadButton
@onready var export_log_button: Button = $CenterContainer/VBoxContainer/ExportLogButton
@onready var result_label: Label = $CenterContainer/VBoxContainer/ResultLabel
@onready var log_label: Label = $CenterContainer/VBoxContainer/LogLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	_ensure_input_map()
	content_label.text = "在这里使用本局点数解锁局外内容（不影响战斗数值）"
	settle_button.pressed.connect(_on_settle_button_pressed)
	unlock_button.pressed.connect(_on_unlock_button_pressed)
	unlock_button_2.pressed.connect(_on_unlock_button_2_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	reload_button.pressed.connect(_on_reload_button_pressed)
	export_log_button.pressed.connect(_on_export_log_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	_refresh_view()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("meta_back"):
		_go_back()

func _on_back_button_pressed() -> void:
	_go_back()

func _on_settle_button_pressed() -> void:
	var settlement_result := MetaRuntime.apply_end_of_match_settlement(
		DEMO_MATCH_ID,
		DEMO_REWARD_REVISION,
		true,
		3
	)
	if settlement_result.get("idempotent", false):
		result_label.text = "本局奖励已领取，未重复发放"
	elif not settlement_result.get("applied", false):
		result_label.text = "结算失败（已回滚）：%s" % String(settlement_result.get("error_code", "SETTLE_FAILED"))
	else:
		_last_settlement_delta = int(settlement_result.get("meta_point_delta", 0))
		result_label.text = "结算成功：+%d 点 | 当前 %d 点" % [
			_last_settlement_delta,
			int(settlement_result.get("meta_point_after", MetaRuntime.get_meta_point())),
		]
	_refresh_view()

func _on_unlock_button_pressed() -> void:
	_attempt_unlock(DEMO_UNLOCK_ID, "开局战术提示")

func _on_unlock_button_2_pressed() -> void:
	_attempt_unlock(DEMO_UNLOCK_ID_2, "军演旗帜外观")

func _attempt_unlock(unlock_id: String, display_name: String) -> void:
	var unlock_result := MetaRuntime.unlock_item(DEMO_PLAYER_ID, unlock_id, _unlock_request_seq, false)
	_unlock_request_seq += 1
	if unlock_result.get("applied", false):
		MetaRuntime.mark_first_unlock_guide_seen()
		var cost_spent := absi(int(unlock_result.get("meta_point_delta", 0)))
		var remaining := int(unlock_result.get("meta_point_after", MetaRuntime.get_meta_point()))
		result_label.text = "解锁成功：%s | 消耗 %d 点 | 剩余 %d 点" % [display_name, cost_spent, remaining]
	elif unlock_result.get("rolled_back", false):
		result_label.text = "解锁失败（已回滚）：%s | %s" % [display_name, String(unlock_result.get("error_code", ""))]
	elif unlock_result.get("idempotent", false):
		result_label.text = "已解锁：%s" % display_name
	else:
		var error_code := String(unlock_result.get("error_code", "UNKNOWN_ERROR"))
		if error_code == "INSUFFICIENT_META_POINT":
			var cost_needed := MetaRuntime.get_unlock_cost(unlock_id)
			result_label.text = "点数不足：%s | 需要 %d 点，当前 %d 点" % [display_name, cost_needed, MetaRuntime.get_meta_point()]
		else:
			result_label.text = "解锁失败：%s | %s" % [display_name, error_code]
	_refresh_view()

func _on_save_button_pressed() -> void:
	var save_result := MetaRuntime.persist_meta_progress()
	if save_result.get("ok", false):
		result_label.text = "进度已保存"
	else:
		result_label.text = "保存失败：%s" % String(save_result.get("error_code", "SAVE_FAILED"))
	_refresh_view()

func _on_reload_button_pressed() -> void:
	var load_result := MetaRuntime.reload_meta_progress()
	if load_result.get("ok", false):
		if load_result.get("used_fallback", false):
			result_label.text = "已重载（使用默认存档）"
		else:
			result_label.text = "已从本地存档重载"
	else:
		result_label.text = "重载失败（已降级）：%s" % String(load_result.get("error_code", "LOAD_FAILED"))
	_refresh_view()

func _on_export_log_button_pressed() -> void:
	var export_result := MetaRuntime.export_playtest_unlock_logs()
	if export_result.get("ok", false):
		result_label.text = "已导出诊断日志（%d 条）" % int(export_result.get("exported_count", 0))
	else:
		result_label.text = "导出失败：%s" % String(export_result.get("error_code", "EXPORT_FAILED"))
	_refresh_view()

func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _ensure_input_map() -> void:
	if not InputMap.has_action("meta_back"):
		InputMap.add_action("meta_back")
	var back_event := InputEventKey.new()
	back_event.keycode = KEY_ESCAPE
	if not InputMap.action_has_event("meta_back", back_event):
		InputMap.action_add_event("meta_back", back_event)

func _refresh_view() -> void:
	meta_point_label.text = "当前局外点数：%d" % MetaRuntime.get_meta_point()
	guide_label.text = _build_guide_text()
	guide_label.visible = not guide_label.text.is_empty()
	unlock_status_label.text = _build_unlock_line(DEMO_UNLOCK_ID, "开局战术提示")
	unlock_status_label_2.text = _build_unlock_line(DEMO_UNLOCK_ID_2, "军演旗帜外观")
	var s1 := MetaRuntime.get_unlock_item_status(DEMO_UNLOCK_ID)
	var s2 := MetaRuntime.get_unlock_item_status(DEMO_UNLOCK_ID_2)
	unlock_button.disabled = bool(s1.get("already_unlocked", false)) or not bool(s1.get("can_afford", false))
	unlock_button.text = "解锁：开局战术提示（%d 点）" % maxi(0, int(s1.get("cost", 0)))
	unlock_button_2.disabled = bool(s2.get("already_unlocked", false)) or not bool(s2.get("can_afford", false))
	unlock_button_2.text = "解锁：军演旗帜外观（%d 点）" % maxi(0, int(s2.get("cost", 0)))
	var affordable_count: int = 0
	if bool(s1.get("can_afford", false)) and not bool(s1.get("already_unlocked", false)):
		affordable_count += 1
	if bool(s2.get("can_afford", false)) and not bool(s2.get("already_unlocked", false)):
		affordable_count += 1
	if _last_settlement_delta > 0:
		s4m3_pipeline_label.text = "本场结算 +%d 点 → 当前 %d 点 | 可解锁 %d 项" % [
			_last_settlement_delta, MetaRuntime.get_meta_point(), affordable_count]
	else:
		s4m3_pipeline_label.text = "结算状态：未领取本局点数 | 当前 %d 点 | 可解锁 %d 项" % [
			MetaRuntime.get_meta_point(), affordable_count]
	var logs: Array[Dictionary] = MetaRuntime.get_recent_logs(3)
	var lines: Array[String] = []
	for log_entry in logs:
		lines.append("%s" % String(log_entry.get("event_type", "unknown")))
	log_label.text = "最近日志：\n%s" % "\n".join(lines)

func _build_unlock_line(unlock_id: String, display_name: String) -> String:
	var status_dict := MetaRuntime.get_unlock_item_status(unlock_id)
	var level := int(status_dict.get("level", 0))
	var cost := int(status_dict.get("cost", 0))
	var can_afford := bool(status_dict.get("can_afford", false))
	var status: String
	if level >= 1:
		status = "已解锁"
	elif can_afford:
		status = "可解锁 ✓"
	else:
		status = "点数不足 ✗"
	var new_tag := "【NEW】" if level < 1 else ""
	return "%s%s | 消耗:%d | 状态:%s" % [new_tag, display_name, cost, status]

func _build_guide_text() -> String:
	if MetaRuntime.is_first_unlock_guide_seen():
		return ""
	return "首次解锁引导：先领取结算点数，再点击带【NEW】标记的项目进行解锁。"
