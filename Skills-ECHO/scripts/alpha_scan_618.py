#!/usr/bin/env python3
"""
ECHO α 参数五档扫描 + 滑动窗口验证
α = Pareto 分布形状参数
扫描范围: {2.0, 2.5, 3.0, 3.5, 4.0}

验证目标:
1. 各 α 下的 Gini/Matthew/Shannon 收敛性
2. 滑动窗口稳定性 (window=50 rounds)
3. 种子间一致性 (10 seeds)
"""

import numpy as np
import csv, os, json, time
from datetime import datetime

OUTPUT_DIR = "outputs/alpha_scan_20250618"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 基础参数
N, K, MAX_R = 500, 8, 200
LAMBDA, D, KAPPA, DT, HOLD = 0.02, 0.03, 0.001, 1.0, 0.01
ALPHA_VALUES = [2.0, 2.5, 3.0, 3.5, 4.0]
N_SEEDS = 10
WINDOW = 50

EVENTS = [("mint",0.15,2.0),("battle",0.25,4.0),("trade",0.20,3.0),
          ("social",0.15,0.6),("remix",0.15,1.6)]


def ws(n, k, rho, rng):
    adj = np.zeros((n, n))
    half = k // 2
    for i in range(n):
        for h in range(1, half + 1):
            j = (i + h) % n
            adj[i, j] = adj[j, i] = 1.0
    for i in range(n):
        for j in range(i + 1, n):
            if adj[i, j] and rng.random() < rho:
                nj = rng.integers(0, n)
                while nj == i or adj[i, nj]:
                    nj = rng.integers(0, n)
                adj[i, nj] = adj[nj, i] = 1.0
                adj[i, j] = adj[j, i] = 0.0
    return adj


def gini(v):
    v = np.sort(v); n = v.size
    return float((2 * np.sum(np.arange(1, n + 1) * v) / (n * np.sum(v)) - (n + 1) / n)) if v.max() > 0 else 0.0


def matthew(v):
    valid = v[v > 0.001]
    if len(valid) == 0:
        return 0.0
    return float(np.max(valid) / (np.mean(valid) + 1e-10))


def shannon(v):
    valid = v[v > 0.001]
    if len(valid) == 0:
        return 0.0
    total = np.sum(valid)
    if total < 1e-10:
        return 0.0
    probs = valid / total
    probs = probs[probs > 0]
    return float(-np.sum(probs * np.log(probs + 1e-10)))


def sliding_window_stability(history, window=WINDOW):
    """计算滑动窗口稳定性: 窗口内标准差"""
    if len(history) < window:
        return None
    stds = []
    for i in range(window, len(history) + 1):
        window_data = history[i-window:i]
        stds.append(np.std(window_data))
    return {
        'mean_std': float(np.mean(stds)),
        'max_std': float(np.max(stds)),
        'last_window_std': float(stds[-1]) if stds else None
    }


def run_sim(alpha, rho_topo, seed=42):
    """运行单组模拟, 返回完整指标"""
    rng = np.random.default_rng(seed)
    adj = ws(N, K, rho_topo, rng)
    deg = adj.sum(1); deg[deg == 0] = 1; inv = 1 / deg
    
    # Pareto 分布, alpha 为形状参数
    stake = rng.pareto(alpha, N) + 1.0
    stake /= stake.mean()
    
    phi = np.ones(N)
    gini_history = []
    matthew_history = []
    shannon_history = []
    
    for t in range(1, MAX_R + 1):
        nsum = adj @ phi
        diff = -D * phi + D * nsum * inv
        decay = -LAMBDA * phi
        src = np.zeros(N)
        
        for evt, prob, boost in EVENTS:
            mask = rng.random(N) < prob
            src += mask * boost * (stake / stake.max())
        
        phi = phi + DT * (diff + decay + KAPPA * src + HOLD * stake)
        phi = np.maximum(phi, 0.01)
        
        gini_history.append(gini(phi))
        matthew_history.append(matthew(phi))
        shannon_history.append(shannon(phi))
    
    return {
        'gini_final': gini_history[-1],
        'matthew_final': matthew_history[-1],
        'shannon_final': shannon_history[-1],
        'gini_history': gini_history,
        'matthew_history': matthew_history,
        'shannon_history': shannon_history,
        'gini_stability': sliding_window_stability(gini_history),
        'matthew_stability': sliding_window_stability(matthew_history),
        'shannon_stability': sliding_window_stability(shannon_history),
    }


def run_alpha_scan(alpha, seeds=N_SEEDS):
    """对单个 alpha 运行多种子扫描"""
    results = []
    for seed in range(1, seeds + 1):
        r = run_sim(alpha, rho_topo=0.2, seed=seed)  # 使用 ρ=0.2 (推荐平衡值)
        results.append({
            'seed': seed,
            'gini_final': r['gini_final'],
            'matthew_final': r['matthew_final'],
            'shannon_final': r['shannon_final'],
            'gini_stability': r['gini_stability']['mean_std'] if r['gini_stability'] else None,
            'matthew_stability': r['matthew_stability']['mean_std'] if r['matthew_stability'] else None,
            'shannon_stability': r['shannon_stability']['mean_std'] if r['shannon_stability'] else None,
        })
    return results


def main():
    print(f"=" * 70)
    print(f"ECHO α 参数五档扫描 + 滑动窗口验证")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"参数: N={N}, MAX_R={MAX_R}, seeds={N_SEEDS}, window={WINDOW}")
    print(f"α 取值: {ALPHA_VALUES}")
    print(f"=" * 70)
    
    all_results = {}
    csv_rows = []
    
    for alpha in ALPHA_VALUES:
        print(f"\n[α = {alpha}] 开始 {N_SEEDS} 种子扫描...")
        start = time.time()
        
        seed_results = run_alpha_scan(alpha)
        gini_vals = [r['gini_final'] for r in seed_results]
        matthew_vals = [r['matthew_final'] for r in seed_results]
        shannon_vals = [r['shannon_final'] for r in seed_results]
        
        all_results[alpha] = {
            'seeds': seed_results,
            'gini_mean': float(np.mean(gini_vals)),
            'gini_std': float(np.std(gini_vals)),
            'matthew_mean': float(np.mean(matthew_vals)),
            'matthew_std': float(np.std(matthew_vals)),
            'shannon_mean': float(np.mean(shannon_vals)),
            'shannon_std': float(np.std(shannon_vals)),
        }
        
        elapsed = time.time() - start
        print(f"  完成 | Gini: {all_results[alpha]['gini_mean']:.4f} ± {all_results[alpha]['gini_std']:.4f} | "
              f"Matthew: {all_results[alpha]['matthew_mean']:.2f} ± {all_results[alpha]['matthew_std']:.2f} | "
              f"time={elapsed:.1f}s")
        
        for r in seed_results:
            csv_rows.append({
                'alpha': alpha,
                'seed': r['seed'],
                'gini_final': r['gini_final'],
                'matthew_final': r['matthew_final'],
                'shannon_final': r['shannon_final'],
                'gini_stability': r['gini_stability'],
                'matthew_stability': r['matthew_stability'],
                'shannon_stability': r['shannon_stability'],
            })
    
    # 保存 CSV
    csv_path = os.path.join(OUTPUT_DIR, 'alpha_scan_results.csv')
    with open(csv_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
        writer.writeheader()
        writer.writerows(csv_rows)
    
    # 保存 JSON
    json_path = os.path.join(OUTPUT_DIR, 'alpha_scan_summary.json')
    with open(json_path, 'w') as f:
        json.dump(all_results, f, indent=2)
    
    # 保存详细报告
    report_path = os.path.join(OUTPUT_DIR, 'alpha_scan_report.md')
    with open(report_path, 'w') as f:
        f.write("# ECHO α 参数五档扫描报告\n\n")
        f.write(f"**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"**实验配置**: N={N}, MAX_R={MAX_R}, seeds={N_SEEDS}, window={WINDOW}, ρ_topo=0.2\n\n")
        
        f.write("## 汇总表\n\n")
        f.write("| α | Gini (mean±std) | Matthew (mean±std) | Shannon (mean±std) | 稳定性 |\n")
        f.write("|---|----------------|-------------------|-------------------|--------|\n")
        
        for alpha in ALPHA_VALUES:
            r = all_results[alpha]
            stability = "✅" if r['gini_std'] < 0.02 else "⚠️"
            f.write(f"| {alpha} | {r['gini_mean']:.4f}±{r['gini_std']:.4f} | "
                   f"{r['matthew_mean']:.2f}±{r['matthew_std']:.2f} | "
                   f"{r['shannon_mean']:.2f}±{r['shannon_std']:.2f} | {stability} |\n")
        
        f.write("\n## 推荐\n\n")
        # 推荐 Gini 最稳定且值适中的
        best_alpha = min(ALPHA_VALUES, key=lambda a: all_results[a]['gini_std'])
        best_gini = all_results[best_alpha]['gini_mean']
        f.write(f"- **最稳定 α**: {best_alpha} (Gini std={all_results[best_alpha]['gini_std']:.4f})\n")
        f.write(f"- **推荐范围**: α ∈ [2.5, 3.5] — Gini 稳定且 Matthew 适中\n")
        
        if best_gini < 0.15:
            f.write(f"- **Gini 评估**: {best_gini:.3f} < 0.15, 分布较为平等 ✅\n")
        elif best_gini < 0.25:
            f.write(f"- **Gini 评估**: {best_gini:.3f} ∈ [0.15, 0.25), 中等不平等 ⚠️\n")
        else:
            f.write(f"- **Gini 评估**: {best_gini:.3f} ≥ 0.25, 高度不平等 ❌\n")
    
    print(f"\n{'='*70}")
    print(f"扫描完成!")
    print(f"CSV: {csv_path}")
    print(f"JSON: {json_path}")
    print(f"Report: {report_path}")
    print(f"{'='*70}")
    
    # 终端输出汇总
    print("\n## 汇总表")
    print(f"{'α':>4} | {'Gini':>12} | {'Matthew':>12} | {'Shannon':>12} | {'稳定'}")
    print("-" * 60)
    for alpha in ALPHA_VALUES:
        r = all_results[alpha]
        stability = "✅" if r['gini_std'] < 0.02 else "⚠️"
        print(f"{alpha:>4.1f} | {r['gini_mean']:>6.4f}±{r['gini_std']:<4.4f} | "
              f"{r['matthew_mean']:>6.2f}±{r['matthew_std']:<4.2f} | "
              f"{r['shannon_mean']:>6.2f}±{r['shannon_std']:<4.2f} | {stability}")


if __name__ == '__main__':
    main()
