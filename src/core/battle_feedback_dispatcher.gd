extends RefCounted

# S4-M4: Battle Feedback Dispatcher
# Converts raw key_event strings + battle summary into structured, prioritised
# feedback items. Supports degraded-mode (low-performance) where non-critical
# items are dropped so the log stays readable without flooding.

const SCHEMA := "s4_m4_battle_feedback_v1"

const PRIORITY_CRITICAL := 0
const PRIORITY_HIGH     := 1
const PRIORITY_NORMAL   := 2
const PRIORITY_LOW      := 3

# Default config — can be overridden via dispatch(config:)
const DEFAULT_MAX_ITEMS_NORMAL   := 8
const DEFAULT_MAX_ITEMS_DEGRADED := 4

# Mapping: event_key -> {feedback_type, priority, display_text, degradable}
# feedback_type: "hit" | "skill" | "kill" | "synergy" | "outcome" | "info"
const EVENT_METADATA := {
	# engagement / info
	"wave_1_normal_engaged":   {"type": "info",    "priority": PRIORITY_NORMAL,   "text": "第 1 波：普通战场接敌",       "degradable": true},
	"wave_2_normal_engaged":   {"type": "info",    "priority": PRIORITY_NORMAL,   "text": "第 2 波：普通战场接敌",       "degradable": true},
	"wave_3_normal_engaged":   {"type": "info",    "priority": PRIORITY_NORMAL,   "text": "第 3 波：普通战场接敌",       "degradable": true},
	"wave_1_elite_engaged":    {"type": "info",    "priority": PRIORITY_HIGH,     "text": "第 1 波：精英战场接敌",       "degradable": false},
	"wave_2_elite_engaged":    {"type": "info",    "priority": PRIORITY_HIGH,     "text": "第 2 波：精英战场接敌",       "degradable": false},
	"wave_3_elite_engaged":    {"type": "info",    "priority": PRIORITY_HIGH,     "text": "第 3 波：精英战场接敌",       "degradable": false},
	"wave_1_boss_engaged":     {"type": "info",    "priority": PRIORITY_CRITICAL, "text": "第 1 波：BOSS 接敌",         "degradable": false},
	"wave_2_boss_engaged":     {"type": "info",    "priority": PRIORITY_CRITICAL, "text": "第 2 波：BOSS 接敌",         "degradable": false},
	"wave_3_boss_engaged":     {"type": "info",    "priority": PRIORITY_CRITICAL, "text": "第 3 波：BOSS 接敌",         "degradable": false},
	# deploy / context
	"deploy_frontline_full":   {"type": "info",    "priority": PRIORITY_HIGH,     "text": "前排满编作战",               "degradable": false},
	"deploy_frontline_thin":   {"type": "info",    "priority": PRIORITY_HIGH,     "text": "前排兵力不足（≤1人）",       "degradable": false},
	"shop_reinforce_multiple": {"type": "info",    "priority": PRIORITY_NORMAL,   "text": "多次补充兵力",               "degradable": true},
	# hit events
	"ally_first_strike":       {"type": "hit",     "priority": PRIORITY_HIGH,     "text": "我方先手命中",               "degradable": false},
	"enemy_first_strike":      {"type": "hit",     "priority": PRIORITY_HIGH,     "text": "敌方先手命中",               "degradable": false},
	"critical_hit_ally":       {"type": "hit",     "priority": PRIORITY_HIGH,     "text": "我方暴击！",                 "degradable": false},
	"critical_hit_enemy":      {"type": "hit",     "priority": PRIORITY_NORMAL,   "text": "敌方暴击",                   "degradable": true},
	# skill events
	"skill_activated_ally":    {"type": "skill",   "priority": PRIORITY_HIGH,     "text": "我方技能发动",               "degradable": false},
	"skill_activated_enemy":   {"type": "skill",   "priority": PRIORITY_NORMAL,   "text": "敌方技能发动",               "degradable": true},
	"skill_boss_mechanic":     {"type": "skill",   "priority": PRIORITY_CRITICAL, "text": "BOSS 特殊机制触发",           "degradable": false},
	# kill / turn events
	"kill_confirmed_ally":     {"type": "kill",    "priority": PRIORITY_HIGH,     "text": "我方击杀确认",               "degradable": false},
	"kill_confirmed_enemy":    {"type": "kill",    "priority": PRIORITY_CRITICAL, "text": "我方被击杀",                 "degradable": false},
	"enemy_core_unit_defeated":{"type": "kill",    "priority": PRIORITY_CRITICAL, "text": "敌方核心单位被击败",         "degradable": false},
	"ally_backline_collapses": {"type": "kill",    "priority": PRIORITY_CRITICAL, "text": "我方后排崩溃",               "degradable": false},
	# synergy / bonding
	"synergy_2_activated":     {"type": "synergy", "priority": PRIORITY_HIGH,     "text": "羁绊（2件）激活",           "degradable": false},
	"synergy_4_activated":     {"type": "synergy", "priority": PRIORITY_CRITICAL, "text": "羁绊（4件）激活",           "degradable": false},
	"bonding_chain_triggered": {"type": "synergy", "priority": PRIORITY_HIGH,     "text": "联锁共鸣触发",               "degradable": false},
	# outcome
	"ally_frontline_holds":    {"type": "outcome", "priority": PRIORITY_CRITICAL, "text": "我方前排守住",               "degradable": false},
	"enemy_pressure_overwhelms":{"type":"outcome", "priority": PRIORITY_CRITICAL, "text": "敌方压力淹没防线",           "degradable": false},
}

func dispatch(key_events: Array, battle_summary: Dictionary, config: Dictionary = {}) -> Dictionary:
	var degraded_mode: bool = bool(config.get("degraded_mode", false))
	var max_normal: int = int(config.get("max_items_normal", DEFAULT_MAX_ITEMS_NORMAL))
	var max_degraded: int = int(config.get("max_items_degraded", DEFAULT_MAX_ITEMS_DEGRADED))
	var max_items: int = max_degraded if degraded_mode else max_normal

	var all_items: Array[Dictionary] = []
	var unknown_events: Array[String] = []

	for raw_event in key_events:
		var event_key := String(raw_event)
		if EVENT_METADATA.has(event_key):
			var meta: Dictionary = EVENT_METADATA[event_key]
			all_items.append({
				"event_key": event_key,
				"feedback_type": String(meta.get("type", "info")),
				"priority": int(meta.get("priority", PRIORITY_NORMAL)),
				"display_text": String(meta.get("text", event_key)),
				"degradable": bool(meta.get("degradable", true)),
				"dropped": false,
			})
		else:
			unknown_events.append(event_key)
			all_items.append({
				"event_key": event_key,
				"feedback_type": "info",
				"priority": PRIORITY_LOW,
				"display_text": event_key,
				"degradable": true,
				"dropped": false,
			})

	# Sort: lower priority number = higher importance (stable sort preserving order)
	all_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 3)) < int(b.get("priority", 3))
	)

	# Apply degradation: mark degradable items as dropped if over capacity
	var kept: Array[Dictionary] = []
	var dropped_count: int = 0
	for item in all_items:
		if kept.size() >= max_items:
			if bool(item.get("degradable", true)):
				var dropped_copy := item.duplicate(true)
				dropped_copy["dropped"] = true
				kept.append(dropped_copy)
				dropped_count += 1
			else:
				kept.append(item)
		else:
			kept.append(item)

	var dispatched_visible: Array[Dictionary] = []
	for item in kept:
		if not bool(item.get("dropped", false)):
			dispatched_visible.append(item)

	return {
		"schema": SCHEMA,
		"dispatched_at_unix": Time.get_unix_time_from_system(),
		"degraded_mode": degraded_mode,
		"total_events": all_items.size(),
		"visible_count": dispatched_visible.size(),
		"dropped_count": dropped_count,
		"unknown_event_count": unknown_events.size(),
		"items": kept,
		"visible_items": dispatched_visible,
		"wave_index": int(battle_summary.get("wave_index", 0)),
		"wave_type": String(battle_summary.get("wave_type", "")),
		"battle_result": String(battle_summary.get("result", "")),
	}
