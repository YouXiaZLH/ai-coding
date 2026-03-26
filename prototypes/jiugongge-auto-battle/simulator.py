# PROTOTYPE - NOT FOR PRODUCTION
# Question: 九宫格站位是否能显著改变自动战斗胜率与战斗时长？
# Date: 2026-03-25

import random
import statistics
from dataclasses import dataclass, replace

TICK_SECONDS = 0.1
MAX_TICKS = 450  # 45s
SIM_ROUNDS = 500


@dataclass
class Unit:
    name: str
    team: str  # ally/enemy
    row: int
    col: int
    hp: float
    atk: float
    defense: float
    speed: float
    cooldown: float = 0.0

    @property
    def alive(self):
        return self.hp > 0


def dist(a: Unit, b: Unit) -> int:
    return abs(a.row - b.row) + abs(a.col - b.col)


def damage_taken_multiplier(target: Unit) -> float:
    if target.team == "ally":
        return 1.10 if target.row == 0 else (0.92 if target.row == 2 else 1.0)
    return 1.10 if target.row == 2 else (0.92 if target.row == 0 else 1.0)


def pick_target(attacker: Unit, candidates: list[Unit]) -> Unit:
    living = [u for u in candidates if u.alive]
    living.sort(key=lambda u: (dist(attacker, u), u.hp))
    return living[0]


def step_attack(attacker: Unit, targets: list[Unit], rng: random.Random) -> None:
    if not attacker.alive:
        return
    if not any(u.alive for u in targets):
        return
    attacker.cooldown -= TICK_SECONDS
    if attacker.cooldown > 0:
        return

    target = pick_target(attacker, targets)
    variance = rng.uniform(0.9, 1.1)
    raw = attacker.atk * variance
    mitigated = raw * (100 / (100 + target.defense))
    final = max(1.0, mitigated) * damage_taken_multiplier(target)
    target.hp -= final
    attacker.cooldown = max(0.2, 1.0 / attacker.speed)


def run_battle(ally_units: list[Unit], enemy_units: list[Unit], seed: int):
    rng = random.Random(seed)
    allies = [replace(u) for u in ally_units]
    enemies = [replace(u) for u in enemy_units]

    for tick in range(MAX_TICKS):
        if not any(u.alive for u in allies):
            return "enemy", tick * TICK_SECONDS, sum(max(0, u.hp) for u in enemies)
        if not any(u.alive for u in enemies):
            return "ally", tick * TICK_SECONDS, sum(max(0, u.hp) for u in allies)

        for u in allies:
            step_attack(u, enemies, rng)
        for u in enemies:
            step_attack(u, allies, rng)

    ally_power = sum(max(0, u.hp) for u in allies)
    enemy_power = sum(max(0, u.hp) for u in enemies)
    return ("ally" if ally_power > enemy_power else "enemy"), MAX_TICKS * TICK_SECONDS, max(ally_power, enemy_power)


def ally_formation_balanced() -> list[Unit]:
    return [
        Unit("A_front_1", "ally", 0, 1, 260, 34, 35, 1.00),
        Unit("A_front_2", "ally", 0, 2, 240, 30, 32, 1.05),
        Unit("A_mid", "ally", 1, 1, 210, 38, 20, 1.15),
        Unit("A_back_1", "ally", 2, 0, 180, 45, 14, 1.20),
        Unit("A_back_2", "ally", 2, 2, 170, 48, 12, 1.25),
    ]


def ally_formation_clumped_backline() -> list[Unit]:
    return [
        Unit("A_front_1", "ally", 1, 1, 260, 34, 35, 1.00),
        Unit("A_front_2", "ally", 1, 2, 240, 30, 32, 1.05),
        Unit("A_mid", "ally", 2, 1, 210, 38, 20, 1.15),
        Unit("A_back_1", "ally", 2, 0, 180, 45, 14, 1.20),
        Unit("A_back_2", "ally", 2, 2, 170, 48, 12, 1.25),
    ]


def enemy_formation_standard() -> list[Unit]:
    return [
        Unit("E_front_1", "enemy", 2, 1, 255, 33, 34, 1.00),
        Unit("E_front_2", "enemy", 2, 0, 235, 31, 30, 1.02),
        Unit("E_mid", "enemy", 1, 1, 220, 36, 22, 1.12),
        Unit("E_back_1", "enemy", 0, 1, 185, 44, 13, 1.22),
        Unit("E_back_2", "enemy", 0, 2, 175, 47, 12, 1.23),
    ]


def evaluate(name: str, allies_factory):
    wins = 0
    durations = []
    survivors = []
    for i in range(SIM_ROUNDS):
        winner, duration, survive_hp = run_battle(allies_factory(), enemy_formation_standard(), seed=1000 + i)
        wins += 1 if winner == "ally" else 0
        durations.append(duration)
        survivors.append(survive_hp)

    print(f"=== {name} ===")
    print(f"rounds={SIM_ROUNDS}")
    print(f"ally_win_rate={wins / SIM_ROUNDS:.3f}")
    print(f"avg_duration_sec={statistics.mean(durations):.2f}")
    print(f"avg_survivor_hp={statistics.mean(survivors):.1f}")
    print(f"p95_duration_sec={statistics.quantiles(durations, n=20)[18]:.2f}")
    print()


if __name__ == "__main__":
    evaluate("balanced_frontline", ally_formation_balanced)
    evaluate("clumped_backline", ally_formation_clumped_backline)
