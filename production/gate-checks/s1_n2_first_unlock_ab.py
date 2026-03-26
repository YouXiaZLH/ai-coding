from __future__ import annotations

import json
import random
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ECONOMY_CONFIG_PATH = ROOT / "assets" / "data" / "meta" / "economy_config.json"
UNLOCK_CATALOG_PATH = ROOT / "assets" / "data" / "meta" / "unlock_catalog.json"
OUTPUT_REPORT_PATH = ROOT / "production" / "gate-checks" / "2026-03-25-s1-n2-first-unlock-ab.md"

SIM_RUNS = 3000
MATCH_WINDOWS = (2, 3)
SEED = 20260325

TARGET_RATE_AT_2 = 0.55
TARGET_RATE_AT_3 = 0.85
TARGET_AVG_MATCH = 2.35

WIN_RATE = 0.48
WAVE_MIN = 1
WAVE_MODE = 3
WAVE_MAX = 6


@dataclass(frozen=True)
class EconomyGroup:
    name: str
    reward_base: int
    reward_win_bonus: int
    reward_wave_bonus_per_wave: int
    unlock_costs: dict[str, int]


@dataclass(frozen=True)
class GroupResult:
    name: str
    reach_rate_2: float
    reach_rate_3: float
    avg_match_to_first_unlock: float
    expected_points_after_2: float
    expected_points_after_3: float


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_baseline_group() -> EconomyGroup:
    economy = _load_json(ECONOMY_CONFIG_PATH)
    catalog = _load_json(UNLOCK_CATALOG_PATH)

    reward = economy.get("reward", {})
    baseline_costs: dict[str, int] = {}
    for item in catalog.get("items", []):
        unlock_id = str(item.get("unlock_id", "")).strip()
        if unlock_id:
            baseline_costs[unlock_id] = int(item.get("cost", 0))

    overrides = economy.get("unlock_cost_overrides", {})
    for unlock_id, override_cost in overrides.items():
        baseline_costs[str(unlock_id)] = int(override_cost)

    return EconomyGroup(
        name="A_baseline",
        reward_base=int(reward.get("base", 10)),
        reward_win_bonus=int(reward.get("win_bonus", 5)),
        reward_wave_bonus_per_wave=int(reward.get("wave_bonus_per_wave", 1)),
        unlock_costs=baseline_costs,
    )


def _derive_groups(baseline: EconomyGroup) -> list[EconomyGroup]:
    unlock_ids = sorted(baseline.unlock_costs.keys())
    if len(unlock_ids) == 0:
        unlock_ids = ["default_unlock"]

    def _cost_map(primary: int, secondary: int) -> dict[str, int]:
        costs: dict[str, int] = {}
        for i, unlock_id in enumerate(unlock_ids):
            costs[unlock_id] = primary if i == 0 else secondary
        return costs

    group_a = EconomyGroup(
        name="A_baseline",
        reward_base=8,
        reward_win_bonus=4,
        reward_wave_bonus_per_wave=1,
        unlock_costs=_cost_map(12, 10),
    )
    group_b = EconomyGroup(
        name="B_conservative",
        reward_base=7,
        reward_win_bonus=3,
        reward_wave_bonus_per_wave=1,
        unlock_costs=_cost_map(13, 11),
    )
    group_c = EconomyGroup(
        name="C_aggressive",
        reward_base=9,
        reward_win_bonus=5,
        reward_wave_bonus_per_wave=2,
        unlock_costs=_cost_map(11, 9),
    )
    return [group_a, group_b, group_c]


def _sample_match_reward(rng: random.Random, group: EconomyGroup) -> int:
    is_win = rng.random() < WIN_RATE
    wave_cleared = int(round(rng.triangular(WAVE_MIN, WAVE_MAX, WAVE_MODE)))
    wave_cleared = max(0, wave_cleared)

    base = max(0, group.reward_base)
    win_bonus = group.reward_win_bonus if is_win else 0
    wave_bonus = wave_cleared * max(0, group.reward_wave_bonus_per_wave)
    return base + win_bonus + wave_bonus


def _simulate_group(group: EconomyGroup, runs: int, seed: int) -> GroupResult:
    rng = random.Random(seed)
    unlock_threshold = min(group.unlock_costs.values()) if group.unlock_costs else 999999

    reached_by_2 = 0
    reached_by_3 = 0
    reached_match_sum = 0.0
    reached_count = 0
    points_after_2_sum = 0.0
    points_after_3_sum = 0.0

    for _ in range(runs):
        meta_points = 0
        first_unlock_match = 0

        for match_idx in range(1, 4):
            meta_points += _sample_match_reward(rng, group)
            if match_idx == 2:
                points_after_2_sum += meta_points
            if match_idx == 3:
                points_after_3_sum += meta_points

            if first_unlock_match == 0 and meta_points >= unlock_threshold:
                first_unlock_match = match_idx

        if first_unlock_match != 0 and first_unlock_match <= 2:
            reached_by_2 += 1
        if first_unlock_match != 0 and first_unlock_match <= 3:
            reached_by_3 += 1
            reached_match_sum += first_unlock_match
            reached_count += 1

    avg_match = reached_match_sum / reached_count if reached_count > 0 else 0.0
    return GroupResult(
        name=group.name,
        reach_rate_2=reached_by_2 / runs,
        reach_rate_3=reached_by_3 / runs,
        avg_match_to_first_unlock=avg_match,
        expected_points_after_2=points_after_2_sum / runs,
        expected_points_after_3=points_after_3_sum / runs,
    )


def _score_result(result: GroupResult) -> float:
    return (
        abs(result.reach_rate_2 - TARGET_RATE_AT_2)
        + abs(result.reach_rate_3 - TARGET_RATE_AT_3)
        + 0.2 * abs(result.avg_match_to_first_unlock - TARGET_AVG_MATCH)
    )


def _to_report(groups: list[EconomyGroup], results: list[GroupResult], recommended: GroupResult) -> str:
    group_map = {g.name: g for g in groups}

    lines: list[str] = []
    lines.append("# S1-N2 快速A/B结果（2-3局首解锁达成率）")
    lines.append("")
    lines.append(f"- 生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"- 样本量: 每组 {SIM_RUNS} 局模拟")
    lines.append(f"- 对局窗口: {MATCH_WINDOWS[0]} 局与 {MATCH_WINDOWS[1]} 局")
    lines.append(f"- 假设: win_rate={WIN_RATE:.2f}, wave~triangular({WAVE_MIN},{WAVE_MODE},{WAVE_MAX})")
    lines.append("")
    lines.append("## 参数组")
    lines.append("")
    lines.append("| Group | base | win_bonus | wave_bonus_per_wave | min_unlock_cost |")
    lines.append("|---|---:|---:|---:|---:|")
    for g in groups:
        lines.append(
            f"| {g.name} | {g.reward_base} | {g.reward_win_bonus} | {g.reward_wave_bonus_per_wave} | {min(g.unlock_costs.values())} |"
        )

    lines.append("")
    lines.append("## 达成率")
    lines.append("")
    lines.append("| Group | reach<=2 | reach<=3 | avg_match_first_unlock | exp_points_after_2 | exp_points_after_3 |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for r in results:
        lines.append(
            f"| {r.name} | {r.reach_rate_2:.3f} | {r.reach_rate_3:.3f} | {r.avg_match_to_first_unlock:.3f} | {r.expected_points_after_2:.2f} | {r.expected_points_after_3:.2f} |"
        )

    recommended_group = group_map[recommended.name]
    lines.append("")
    lines.append("## 建议默认参数")
    lines.append("")
    lines.append(f"- 推荐组: **{recommended.name}**")
    lines.append(
        "- 推荐理由: 该组在 2-3 局窗口的首解锁达成率最接近目标区间（兼顾不过松与不过紧）。"
    )
    lines.append("- 建议配置:")
    lines.append("```json")
    lines.append(
        json.dumps(
            {
                "reward": {
                    "base": recommended_group.reward_base,
                    "win_bonus": recommended_group.reward_win_bonus,
                    "wave_bonus_per_wave": recommended_group.reward_wave_bonus_per_wave,
                },
                "unlock_cost_overrides": recommended_group.unlock_costs,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    lines.append("```")

    return "\n".join(lines) + "\n"


def main() -> None:
    baseline = _load_baseline_group()
    groups = _derive_groups(baseline)

    results = [
        _simulate_group(group=group, runs=SIM_RUNS, seed=SEED + idx * 100)
        for idx, group in enumerate(groups)
    ]
    recommended = min(results, key=_score_result)

    report = _to_report(groups=groups, results=results, recommended=recommended)
    OUTPUT_REPORT_PATH.write_text(report, encoding="utf-8")

    print("S1-N2 A/B simulation finished")
    print(f"report: {OUTPUT_REPORT_PATH}")
    print(f"recommended: {recommended.name}")


if __name__ == "__main__":
    main()
