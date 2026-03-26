extends RefCounted

func resolve_battle(match_id: String, wave_index: int, wave_payload: Dictionary, match_seed: int, battle_context: Dictionary = {}) -> Dictionary:
	var enemy_roster: Array = wave_payload.get("enemy_roster", [])
	var ally_power_data := _calc_ally_power(wave_index, battle_context)
	var ally_power := float(ally_power_data.get("raw", 0.0))
	var ally_modifier := float(ally_power_data.get("modifier", 0.0))
	var enemy_power := _calc_enemy_power(enemy_roster, wave_index)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(hash("%s:%d:%d" % [match_id, wave_index, match_seed])))
	var ally_roll := 0.92 + rng.randf() * 0.20
	var enemy_roll := 0.92 + rng.randf() * 0.20
	var ally_score := ally_power * ally_roll
	var enemy_score := enemy_power * enemy_roll

	var winner := "ally" if ally_score >= enemy_score else "enemy"
	var ratio := 1.0
	if enemy_score > 0.0:
		ratio = ally_score / enemy_score
	var duration_sec := clampf(30.0 - (ratio - 1.0) * 8.0 + rng.randf_range(-2.0, 2.0), 12.0, 45.0)

	var summary := {
		"result": winner,
		"duration_sec": snappedf(duration_sec, 0.1),
		"ally_power_raw": snappedf(ally_power, 0.1),
		"ally_power_modifier": snappedf(ally_modifier, 0.1),
		"ally_power": snappedf(ally_score, 0.1),
		"enemy_power": snappedf(enemy_score, 0.1),
		"seed": match_seed,
		"wave_index": wave_index,
		"wave_type": String(wave_payload.get("wave_type", "normal")),
		"battle_context": battle_context.duplicate(true),
		"key_events": _build_key_events(winner, wave_index, wave_payload, battle_context),
	}

	return {
		"ok": true,
		"error_code": "",
		"battle_summary": summary,
	}

func _calc_ally_power(wave_index: int, battle_context: Dictionary) -> Dictionary:
	var base := 145.0
	var raw := base + float(wave_index - 1) * 22.0
	var frontline_count := int(battle_context.get("frontline_count", 0))
	var frontline_slot_count := int(battle_context.get("frontline_slot_count", 3))
	var deploy_action_count := int(battle_context.get("deploy_action_count", 0))
	var shop_buy_count := int(battle_context.get("shop_buy_count", 0))
	var shop_refresh_count := int(battle_context.get("shop_refresh_count", 0))

	var modifier := 0.0
	modifier += float(frontline_count) * 18.0
	if frontline_count >= frontline_slot_count:
		modifier += 20.0
	else:
		modifier -= float(maxi(0, frontline_slot_count - frontline_count)) * 10.0
	modifier += float(mini(8, deploy_action_count)) * 1.5
	modifier += float(shop_buy_count) * 10.0
	modifier += float(maxi(0, shop_refresh_count - 1)) * 2.0

	raw = maxf(1.0, raw + modifier)
	return {
		"raw": raw,
		"modifier": modifier,
	}

func _calc_enemy_power(enemy_roster: Array, wave_index: int) -> float:
	if enemy_roster.is_empty():
		return 120.0 + float(wave_index - 1) * 35.0

	var total := 0.0
	for item in enemy_roster:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = item
		if unit.has("power"):
			total += float(unit.get("power", 0))
		else:
			total += float(unit.get("hp", 0)) * 0.15 + float(unit.get("atk", 0)) * 1.2 + float(unit.get("defense", 0)) * 0.8
	return maxf(1.0, total)

func _build_key_events(winner: String, wave_index: int, wave_payload: Dictionary, battle_context: Dictionary) -> Array[String]:
	var wave_type := String(wave_payload.get("wave_type", "normal"))
	var events: Array[String] = []

	# Engagement
	events.append("wave_%d_%s_engaged" % [wave_index, wave_type])

	# Deploy context
	var frontline_count := int(battle_context.get("frontline_count", 0))
	var shop_buy_count := int(battle_context.get("shop_buy_count", 0))
	if frontline_count >= 3:
		events.append("deploy_frontline_full")
	elif frontline_count <= 1:
		events.append("deploy_frontline_thin")
	if shop_buy_count >= 2:
		events.append("shop_reinforce_multiple")

	# Hit events — always present
	if winner == "ally":
		events.append("ally_first_strike")
		events.append("critical_hit_ally")
	else:
		events.append("enemy_first_strike")
		events.append("critical_hit_enemy")

	# Skill events
	if wave_type == "boss":
		events.append("skill_boss_mechanic")
		events.append("skill_activated_ally")
	elif wave_type == "elite":
		events.append("skill_activated_ally")
		events.append("skill_activated_enemy")
	else:
		if frontline_count >= 2:
			events.append("skill_activated_ally")

	# Synergy / bonding
	var deploy_action_count := int(battle_context.get("deploy_action_count", 0))
	if shop_buy_count >= 3 and frontline_count >= 2:
		events.append("synergy_4_activated")
	elif shop_buy_count >= 2 or frontline_count >= 2:
		events.append("synergy_2_activated")
	if deploy_action_count >= 4 and shop_buy_count >= 2:
		events.append("bonding_chain_triggered")

	# Kill / outcome events
	if winner == "ally":
		events.append("kill_confirmed_ally")
		events.append("ally_frontline_holds")
		events.append("enemy_core_unit_defeated")
	else:
		events.append("kill_confirmed_enemy")
		events.append("enemy_pressure_overwhelms")
		events.append("ally_backline_collapses")

	return events

