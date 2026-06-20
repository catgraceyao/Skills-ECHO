#!/usr/bin/env python3
"""
ρ 密集扫描 — ZK/PDE 攻关任务
补全 v0.1 数据缺口：ρ=0.15/0.25/0.35/0.45
10 seeds × 1000 轮，与现有 v0.1 参数保持一致
"""

import numpy as np, csv, os, time

OUTPUT_DIR = "outputs/v15.2_simulation"
os.makedirs(OUTPUT_DIR, exist_ok=True)

N, K, MAX_R, CONV_W, CONV_T = 1000, 8, 1000, 50, 0.01
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


def gini(v):
    v = np.sort(v); n = v.size
    return float((2 * np.sum(np.arange(1, n + 1) * v) / (n * np.sum(v)) - (n + 1) / n)) if v.max() > 0 else 0.0


def run(rho, seed=42):
    rng = np.random.default_rng(seed)
    adj = ws(N, K, rho, rng)
    deg = adj.sum(1); deg[deg == 0] = 1; inv = 1 / deg
    stake = rng.pareto(2.0, N) + 1.0; stake /= stake.mean()
    phi = np.ones(N); gh = []; conv = False; cround = None
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
        gh.append(gini(phi))
        if t >= CONV_W and not conv:
            if max(gh[-CONV_W:]) - min(gh[-CONV_W:]) < CONV_T:
                conv = True; cround = t
    return {"rho": rho, "fg": gh[-1], "gstd": float(np.std(gh[-CONV_W:])),
            "conv": conv, "cr": cround, "gh": gh}


def main():
    rho_targets = [0.15, 0.25, 0.35, 0.45]
    seeds = list(range(0, 10))
    
    out_file = os.path.join(OUTPUT_DIR, "rho_dense_scan_20260620.csv")
    
    with open(out_file, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["rho", "seed", "gini", "gini_std", "conv", "round", "timestamp"])
        
        for rho in rho_targets:
            print(f"\n=== ρ={rho:.2f} ===")
            for seed in seeds:
                start = time.time()
                r = run(rho, seed)
                elapsed = time.time() - start
                print(f"  seed={seed} Gini={r['fg']:.4f} conv={r['conv']} ({elapsed:.1f}s)")
                w.writerow([r["rho"], seed, r["fg"], r["gstd"], r["conv"], r["cr"], time.strftime("%Y-%m-%d %H:%M:%S")])
                f.flush()
    
    print(f"\n=== DONE ===")
    print(f"Output: {out_file}")
    
    # Summary
    with open(out_file, "r") as f:
        reader = csv.DictReader(f)
        data = list(reader)
    
    rho_groups = {}
    for row in data:
        rho_val = float(row['rho'])
        if rho_val not in rho_groups:
            rho_groups[rho_val] = []
        rho_groups[rho_val].append(float(row['gini']))
    
    print("\nMean Gini per rho:")
    for rho_val in sorted(rho_groups.keys()):
        mean_g = sum(rho_groups[rho_val]) / len(rho_groups[rho_val])
        std_g = np.std(rho_groups[rho_val])
        print(f"  ρ={rho_val:.2f}: {mean_g:.4f} ± {std_g:.4f}")


if __name__ == "__main__":
    main()
