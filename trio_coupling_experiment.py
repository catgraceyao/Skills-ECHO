"""
ECHO 三参数耦合相图实验 v0.1
ξ (综合开放度) × β (边界约束系数) × ρ_topo (桥接密度)

网络模型: Watts-Strogatz 小世界网络 + 四权开放度 ξ 调控
"""

import numpy as np
import pandas as pd
import json
import time
from datetime import datetime

# ========== 固定参数 ==========
SEED = 42
ROUNDS = 200
N_NODES = 500  # 中等规模，平衡速度与精度
K_NEAREST = 4
DECAY_LAMBDA = 0.1
BRIDGE_BONUS = 0.15

np.random.seed(SEED)

# ========== ξ 档定义 ==========
# ξ = 0: 禁 (完全封闭，无编排边)
# ξ = 1: 己 (仅自引用)
# ξ = 2: 亲 (小范围编排)
# ξ = 3: 约 (社区内编排)
# ξ = 4: 法 (全开放)

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


def init_network(n, rho, xi):
    """初始化网络，ξ 控制开放度"""
    adj = create_ws_network(n, K_NEAREST, rho)
    
    # ξ 影响初始 stake 分布
    if xi == 0:  # 禁 — 均匀分布
        stakes = np.ones(n, dtype=np.float32)
    elif xi == 1:  # 己 — 轻微偏斜
        stakes = (np.random.pareto(3.0, n) + 1.0).astype(np.float32)
    elif xi == 2:  # 亲 — 中等偏斜
        stakes = (np.random.pareto(2.0, n) + 1.0).astype(np.float32)
    elif xi == 3:  # 约 — 显著偏斜
        stakes = (np.random.pareto(1.5, n) + 1.0).astype(np.float32)
    else:  # ξ = 4: 法 — 强偏斜
        stakes = (np.random.pareto(1.0, n) + 1.0).astype(np.float32)
    
    stakes = np.clip(stakes, 1.0, 100.0)
    potentials = np.log(1 + stakes).astype(np.float32)
    return adj, stakes, potentials


def calculate_potential(adj, stakes, potentials, weight_ratio, beta_ts, round_num, xi):
    """计算势位，ξ 影响编排行为"""
    n = len(potentials)
    decay = 1.0 / (1.0 + DECAY_LAMBDA * round_num)
    
    # 邻居势位和
    neighbor_sum = adj @ potentials
    topo = neighbor_sum * weight_ratio * decay
    
    # 经济信号
    economic = beta_ts * np.log(1 + stakes)
    
    # 桥接加成
    degrees = adj.sum(axis=1)
    bridge = BRIDGE_BONUS * degrees * potentials * decay / max(degrees.max(), 1.0)
    
    # ξ 影响新节点加入和编排强度
    xi_boost = 1.0 + 0.05 * xi  # ξ 越高，势位增长越快
    
    new_potentials = (topo + economic + bridge) * xi_boost
    
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
    """运行单组实验"""
    adj, stakes, potentials = init_network(n_nodes, rho_topo, xi)
    
    gini_history = []
    matthew_history = []
    shannon_history = []
    
    for r in range(rounds):
        # 每轮新增节点
        new_nodes = max(1, int(2 * (1 + 0.1 * xi)))
        for _ in range(new_nodes):
            if len(potentials) >= n_nodes * 2:
                break
            # 简化：随机连接到现有节点
            if len(potentials) > 0:
                target = np.random.randint(0, len(potentials))
                stakes = np.append(stakes, stakes[target] * 0.5)
                potentials = np.append(potentials, potentials[target] * 0.3)
                # 扩展 adj
                new_adj = np.zeros((len(potentials), len(potentials)), dtype=np.float32)
                new_adj[:adj.shape[0], :adj.shape[1]] = adj
                new_adj[-1, target] = 1.0
                new_adj[target, -1] = 1.0
                adj = new_adj
        
        # 势位更新
        weight_ratio = 2.0
        potentials = calculate_potential(adj, stakes, potentials, weight_ratio, beta, r, xi)
        
        # 记录指标
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
        'n_final': len(potentials)
    }


def main():
    # 参数网格
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
                    'n_final': result['n_final']
                })
    
    # 保存结果
    df = pd.DataFrame(results)
    df.to_csv('/root/.openclaw/workspace/trio_coupling_results.csv', index=False)
    print(f"\n结果已保存到 trio_coupling_results.csv")
    
    # 打印汇总表
    print("\n" + "="*60)
    print("三参数耦合结果汇总")
    print("="*60)
    for _, row in df.iterrows():
        print(f"ξ={int(row['xi'])}, β={row['beta']:.2f}, ρ={row['rho_topo']:.1f} | "
              f"Gini={row['gini_final']:.3f}, Matthew={row['matthew_final']:.2f}, "
              f"Shannon={row['shannon_final']:.2f}")
    
    # 推荐参数组合
    print("\n" + "="*60)
    print("推荐参数组合（Gini 0.10-0.20 区间，兼顾稳定性与多样性）")
    print("="*60)
    good = df[(df['gini_final'] >= 0.10) & (df['gini_final'] <= 0.20)]
    good = good.sort_values('gini_final')
    for _, row in good.head(10).iterrows():
        print(f"ξ={int(row['xi'])}, β={row['beta']:.2f}, ρ={row['rho_topo']:.1f} | "
              f"Gini={row['gini_final']:.3f}, Matthew={row['matthew_final']:.2f}, "
              f"Shannon={row['shannon_final']:.2f}")
    
    print(f"\n结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == '__main__':
    main()
