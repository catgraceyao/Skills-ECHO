#!/usr/bin/env python3
"""
为 X7 PDE 交叉验证生成 phi_t 向量 + 邻接矩阵
ρ=0.25 和 ρ=0.45，seed=0
轮次：0, 10, 50, 100, 150, 200
"""

import numpy as np, csv, os, json

OUTPUT_DIR = "outputs/v15.2_simulation"
os.makedirs(OUTPUT_DIR, exist_ok=True)

N, K, MAX_R = 1000, 8, 200
LAMBDA, D, KAPPA, DT, HOLD = 0.02, 0.03, 0.001, 1.0, 0.01

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


def run_with_snapshots(rho, seed, snapshot_rounds):
    rng = np.random.default_rng(seed)
    adj = ws(N, K, rho, rng)
    deg = adj.sum(1); deg[deg == 0] = 1; inv = 1 / deg
    stake = rng.pareto(2.0, N) + 1.0; stake /= stake.mean()
    phi = np.ones(N)
    
    snapshots = {}  # round -> phi vector
    snapshots[0] = phi.copy()
    
    for t in range(1, MAX_R + 1):
        nsum = adj @ phi
        diff = -D * phi + D * nsum * inv
        decay = -LAMBDA * phi
        src = np.zeros(N)
        for _, p, w in EVENTS:
            if rng.random() < p:
                nodes = rng.choice(N, size=max(1, int(N * 0.3)), replace=False)
                src[nodes] += w * stake[nodes]
        phi = phi + DT * (diff + decay + src + HOLD * phi + KAPPA * nsum)
        phi = np.maximum(phi, 0)
        
        if t in snapshot_rounds:
            snapshots[t] = phi.copy()
    
    return adj, snapshots


def main():
    snapshot_rounds = {0, 10, 50, 100, 150, 200}
    
    for rho in [0.25, 0.45]:
        print(f"Running ρ={rho}, seed=0...")
        adj, snapshots = run_with_snapshots(rho, seed=0, snapshot_rounds=snapshot_rounds)
        
        # Save adjacency matrix (sparse format)
        edges = []
        for i in range(N):
            for j in range(i+1, N):
                if adj[i, j] > 0:
                    edges.append((i, j, float(adj[i, j])))
        
        adj_file = os.path.join(OUTPUT_DIR, f"adj_matrix_rho{rho}_seed0.json")
        with open(adj_file, 'w') as f:
            json.dump({
                "n": N, "k": K, "rho": rho, "seed": 0,
                "num_edges": len(edges),
                "edges": edges[:100] + ["... truncated, total=" + str(len(edges))]
            }, f, indent=2)
        
        # Save full edges as CSV for X7
        edge_file = os.path.join(OUTPUT_DIR, f"adj_edges_rho{rho}_seed0.csv")
        with open(edge_file, 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['i', 'j', 'weight'])
            for i, j, weight in edges:
                w.writerow([i, j, weight])
        
        # Save phi snapshots
        phi_file = os.path.join(OUTPUT_DIR, f"phi_snapshots_rho{rho}_seed0.csv")
        with open(phi_file, 'w', newline='') as f:
            w = csv.writer(f)
            header = ['round'] + [f'phi_{i}' for i in range(N)]
            w.writerow(header)
            for rnd in sorted(snapshots.keys()):
                row = [rnd] + snapshots[rnd].tolist()
                w.writerow(row)
        
        print(f"  Saved: {adj_file} ({len(edges)} edges)")
        print(f"  Saved: {edge_file}")
        print(f"  Saved: {phi_file} ({len(snapshots)} snapshots)")
    
    print("\n=== DONE ===")


if __name__ == "__main__":
    main()
