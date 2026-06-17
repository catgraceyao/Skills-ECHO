"""
ECHO 三参数耦合相图实验 v0.2（修正版）
ξ (综合开放度) × β (边界约束系数) × ρ_topo (桥接密度)

修正：ξ 控制编排均匀度，不是势位放大器
"""

import numpy as np
import pandas as pd
import json
import time
from datetime import datetime

SEED = 42
ROUNDS = 200
N_NODES = 500
K_NEAREST = 4
DECAY_LAMBDA = 0.1
BRIDGE_BONUS = 0.15

np.random.seed(SEED)


def create_ws_network(n, k, rho):
    adj = np.zeros((n, n), dtype=np.float32)
    half_k = k // 2
    for i in range(n):
        for j in range(1, half_k + 1):
            right = (i + j) % n
            left = (i - j + n) % n
            adj[i, right] = 1.0
            adj[i, left] = 1.0
    
    edges_to_rewire = []
    for i in range(n):
        for j in range(i+1, n):
            if adj[i, j] > 0:
                edges_to_rewire.append((i, j))
    
    for i, j in edges_to_rewire:
        if np.random.random() < rho:
            adj[i, j] = 0.0
            adj[j, i] = 0.0
            candidates = [x for x in range(n) if x != i and adj[i, x] == 0]
            if candidates:
                new_target = np.random.choice(candidates)
                adj[i, new_target] = 1.0
                adj[new_target, i] = 1.0
    
    return adj


def init_network(n, rho):
    """初始化网络，统一用 pareto 2.0"""
    adj = create_ws_network(n, K_NEAREST, rho)
    stakes = (np.random.pareto(2.0, n) + 1.0).astype(np.float32)
    stakes = np.clip(stakes, 1.0, 100.0)
    potentials = np.log(1 + stakes).astype(np.float32)
    return adj, stakes, potentials


def calculate_potential(adj, stakes, potentials, weight_ratio, beta_ts, round_num, xi):
    """计算势位
    ξ 控制编排均匀度:
    - ξ=0: 只连接势位最高的 top 节点（精英封闭）
    - ξ=4: 均匀连接所有节点（全开放）
    """
    n = len(potentials)
    decay = 1.0 / (1.0 + DECAY_LAMBDA * round_num)
    
    # ξ 影响邻居选择: 高 ξ = 更均匀的编排
    # 通过调整邻居权重实现
    if xi == 0:
        # 只保留势位 top 30% 的邻居连接
        threshold = np.percentile(potentials, 70)
        neighbor_weights = (potentials >= threshold).astype(np.float32)
    elif xi == 1:
        threshold = np.percentile(potentials, 50)
        neighbor_weights = (potentials >= threshold).astype(np.float32) + 0.3
    elif xi == 2:
        neighbor_weights = np.ones(n, dtype=np.float32)
    elif xi == 3:
        # 优先低势位节点（扶弱）
        neighbor_weights = 1.0 / (potentials + 1.0)
    else:  # xi == 4
        # 强扶弱 + 桥接优先
        neighbor_weights = 2.0 / (potentials + 1.0)
    
    # 邻居势位加权和
    weighted_neighbors = adj * neighbor_weights[np.newaxis, :]
    neighbor_sum = weighted_neighbors @ potentials
    topo = neighbor_sum * weight_ratio * decay
    
    # 经济信号
    economic = beta_ts * np.log(1 + stakes)
    
    # 桥接加成
    degrees = adj.sum(axis=1)
    bridge = BRIDGE_BONUS * degrees * potentials * decay / max(degrees.max(), 1.0)
    
    new_potentials = topo + economic + bridge
    
    max_p = new_potentials.max()
    if max_p > 1000.0:
        new_potentials = new_potentials / max_p * 1000.0
    
    new_potentials = np.maximum(new_potentials, 0.0)
    return new_potentials


def calculate_gini(potentials):
    valid = potentials[potentials > 0.001]
    if len(valid) == 0:
        return 0.0
    n = len(valid)
    sorted_vals = np.sort(valid)
    gini = (2 * np.sum((np.arange(1, n+1) - (n+1)/2) * sorted_vals)) / (n * np.sum(sorted_vals))
    return max(0.0, gini)


def calculate_matthew(potentials):
    valid = potentials[potentials > 0.001]
    if len(valid) == 0:
        return 0.0
    return float(np.max(valid) / (np.mean(valid) + 1e-10))


def calculate_shannon(potentials):
    valid = potentials[potentials > 0.001]
    if len(valid) == 0:
        return 0.0
    total = np.sum(valid)
    if total < 1e-10:
        return 0.0
    probs = valid / total
    probs = probs[probs > 0]
    return float(-np.sum(probs * np.log(probs + 1e-10)))


def run_experiment(xi, beta, rho_topo, n_nodes=N_NODES, rounds=ROUNDS):
    adj, stakes, potentials = init_network(n_nodes, rho_topo)
    
    gini_history = []
    matthew_history = []
    shannon_history = []
    
    for r in range(rounds):
        # 势位更新
        weight_ratio = 2.0
        potentials = calculate_potential(adj, stakes, potentials, weight_ratio, beta, r, xi)
        
        gini_history.append(calculate_gini(potentials))
        matthew_history.append(calculate_matthew(potentials))
        shannon_history.append(calculate_shannon(potentials))
    
    return {
        'gini_final': gini_history[-1],
        'matthew_final': matthew_history[-1],
        'shannon_final': shannon_history[-1],
        'gini_history': gini_history,
        'matthew_history': matthew_history,
        'shannon_history': shannon_history,
    }


def main():
    xi_values = [0, 1, 2, 3, 4]
    beta_values = [0.01, 0.1, 1.0]
    rho_values = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0]
    
    total = len(xi_values) * len(beta_values) * len(rho_values)
    print(f"总实验数: {total}")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    results = []
    count = 0
    
    for xi in xi_values:
        for beta in beta_values:
            for rho in rho_values:
                count += 1
                print(f"[{count}/{total}] ξ={xi}, β={beta}, ρ={rho} ... ", end="", flush=True)
                start = time.time()
                
                result = run_experiment(xi, beta, rho)
                
                elapsed = time.time() - start
                print(f"Gini={result['gini_final']:.3f}, Matthew={result['matthew_final']:.2f}, "
                      f"Shannon={result['shannon_final']:.2f}, time={elapsed:.1f}s")
                
                results.append({
                    'xi': xi,
                    'beta': beta,
                    'rho_topo': rho,
                    'gini_final': result['gini_final'],
                    'matthew_final': result['matthew_final'],
                    'shannon_final': result['shannon_final'],
                })
    
    df = pd.DataFrame(results)
    df.to_csv('/root/.openclaw/workspace/trio_coupling_results_v2.csv', index=False)
    print(f"\n结果已保存到 trio_coupling_results_v2.csv")
    
    print("\n" + "="*60)
    print("三参数耦合结果汇总 (修正版)")
    print("="*60)
    for _, row in df.iterrows():
        print(f"ξ={int(row['xi'])}, β={row['beta']:.2f}, ρ={row['rho_topo']:.1f} | "
              f"Gini={row['gini_final']:.3f}, Matthew={row['matthew_final']:.2f}, "
              f"Shannon={row['shannon_final']:.2f}")
    
    print("\n" + "="*60)
    print("推荐参数组合（Gini 0.10-0.20 区间）")
    print("="*60)
    good = df[(df['gini_final'] >= 0.10) & (df['gini_final'] <= 0.20)]
    good = good.sort_values('gini_final')
    if len(good) > 0:
        for _, row in good.head(10).iterrows():
            print(f"ξ={int(row['xi'])}, β={row['beta']:.2f}, ρ={row['rho_topo']:.1f} | "
                  f"Gini={row['gini_final']:.3f}, Matthew={row['matthew_final']:.2f}, "
                  f"Shannon={row['shannon_final']:.2f}")
    else:
        print("无推荐组合。Gini 范围需调整。")
        # 输出最低 Gini 的组合
        best = df.sort_values('gini_final').head(5)
        print("\n最低 Gini 组合:")
        for _, row in best.iterrows():
            print(f"ξ={int(row['xi'])}, β={row['beta']:.2f}, ρ={row['rho_topo']:.1f} | "
                  f"Gini={row['gini_final']:.3f}, Matthew={row['matthew_final']:.2f}, "
                  f"Shannon={row['shannon_final']:.2f}")
    
    print(f"\n结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == '__main__':
    main()
