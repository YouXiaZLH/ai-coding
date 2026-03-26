# S1-N2 快速A/B结果（2-3局首解锁达成率）

- 生成时间: 2026-03-25 17:11:51
- 样本量: 每组 3000 局模拟
- 对局窗口: 2 局与 3 局
- 假设: win_rate=0.48, wave~triangular(1,3,6)

## 参数组

| Group | base | win_bonus | wave_bonus_per_wave | min_unlock_cost |
|---|---:|---:|---:|---:|
| A_baseline | 8 | 4 | 1 | 10 |
| B_conservative | 7 | 3 | 1 | 11 |
| C_aggressive | 9 | 5 | 2 | 9 |

## 达成率

| Group | reach<=2 | reach<=3 | avg_match_first_unlock | exp_points_after_2 | exp_points_after_3 |
|---|---:|---:|---:|---:|---:|
| A_baseline | 1.000 | 1.000 | 1.015 | 26.48 | 39.68 |
| B_conservative | 1.000 | 1.000 | 1.282 | 23.60 | 35.39 |
| C_aggressive | 1.000 | 1.000 | 1.000 | 36.09 | 54.25 |

## 建议默认参数

- 推荐组: **B_conservative**
- 推荐理由: 该组在 2-3 局窗口的首解锁达成率最接近目标区间（兼顾不过松与不过紧）。
- 建议配置:
```json
{
  "reward": {
    "base": 7,
    "win_bonus": 3,
    "wave_bonus_per_wave": 1
  },
  "unlock_cost_overrides": {
    "cosmetic_banner_lv1": 13,
    "hint_opening_tactics": 11
  }
}
```
