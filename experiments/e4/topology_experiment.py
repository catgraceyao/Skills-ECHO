"""
ECHO Topology Emergence Experiment
Scan ρ_topo (Watts-Strogatz rewiring probability) across different values
and measure network properties vs Gini coefficient.

Parameters:
- ρ_topo: 0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0
- N: network size (100, 500, 1000)
- k: nearest neighbors (4)
- rounds: 200
- seed: 42

Metrics:
- Gini coefficient of degree distribution
- Clustering coefficient
- Characteristic path length
- Bridge density (inter-community edges)
- Correlation in-degree vs out-degree
"""

import numpy as np
import networkx as nx
from collections import defaultdict
import json
import csv
from datetime import datetime

# ============================================
# CONFIGURATION
# ============================================
SEED = 42
np.random.seed(SEED)

RHO_TOPO_VALUES = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0]
NETWORK_SIZES = [100, 500, 1000]
K_NEAREST = 4
ROUNDS = 200

# Shi-Graph engine parameters (from v0.2)
BRIDGE_BONUS = 1.5

# ============================================
# NETWORK GENERATION
# ============================================
def generate_ws_network(n, k, p, seed=None):
    """Generate Watts-Strogatz small-world network."""
    return nx.watts_strogatz_graph(n, k, p, seed=seed)

def calculate_gini(degrees):
    """Calculate Gini coefficient from degree sequence."""
    n = len(degrees)
    if n == 0:
        return 0.0
    degrees = np.array(sorted(degrees))
    cumsum = np.cumsum(degrees)
    return (2 * np.sum((np.arange(1, n + 1) * degrees))) / (n * cumsum[-1]) - (n + 1) / n

def calculate_bridge_density(G):
    """Calculate bridge density using connected components as communities."""
    if G.number_of_edges() == 0:
        return 0.0
    
    partition = {}
    for i, comp in enumerate(nx.connected_components(G.to_undirected())):
        for node in comp:
            partition[node] = i
    
    inter_edges = 0
    for u, v in G.edges():
        if partition.get(u, -1) != partition.get(v, -1):
            inter_edges += 1
    
    return inter_edges / G.number_of_edges()

def simulate_shi_graph_evolution(G, rounds=200):
    """
    Simulate Shi-Graph evolution on the given topology.
    Returns time series of Gini and other metrics.
    """
    n = G.number_of_nodes()
    phi = np.ones(n) * 0.1
    
    metrics = {
        'gini': [],
        'max_phi': [],
        'min_phi': [],
        'mean_phi': [],
        'std_phi': [],
        'bridge_density': [],
        'clustering': [],
        'path_length': [],
    }
    
    for t in range(rounds):
        new_phi = phi.copy()
        
        for node in G.nodes():
            neighbors = list(G.neighbors(node))
            if not neighbors:
                continue
            
            outflow = phi[node] * 0.1
            
            for neighbor in neighbors:
                new_phi[neighbor] += (outflow / len(neighbors)) * BRIDGE_BONUS
            
            new_phi[node] -= outflow
        
        decay_factor = 0.99
        new_phi *= decay_factor
        
        usage_nodes = np.random.choice(n, size=max(1, n // 10), replace=False)
        new_phi[usage_nodes] += np.random.exponential(0.5, size=len(usage_nodes))
        
        phi = new_phi
        
        metrics['gini'].append(calculate_gini(phi.tolist()))
        metrics['max_phi'].append(float(np.max(phi)))
        metrics['min_phi'].append(float(np.min(phi)))
        metrics['mean_phi'].append(float(np.mean(phi)))
        metrics['std_phi'].append(float(np.std(phi)))
        
        if t % 10 == 0 or t == rounds - 1:
            metrics['bridge_density'].append(calculate_bridge_density(G))
            metrics['clustering'].append(nx.average_clustering(G.to_undirected()))
            
            try:
                if nx.is_connected(G.to_undirected()):
                    metrics['path_length'].append(nx.average_shortest_path_length(G.to_undirected()))
                else:
                    metrics['path_length'].append(float('inf'))
            except:
                metrics['path_length'].append(float('inf'))
        else:
            if len(metrics['bridge_density']) > 0:
                metrics['bridge_density'].append(metrics['bridge_density'][-1])
                metrics['clustering'].append(metrics['clustering'][-1])
                metrics['path_length'].append(metrics['path_length'][-1])
            else:
                metrics['bridge_density'].append(0)
                metrics['clustering'].append(0)
                metrics['path_length'].append(0)
    
    return metrics, phi

# ============================================
# MAIN EXPERIMENT
# ============================================
def run_experiment():
    results = []
    
    print("=" * 80)
    print("ECHO Topology Emergence Experiment")
    print(f"Date: {datetime.now().isoformat()}")
    print("=" * 80)
    
    for n in NETWORK_SIZES:
        for rho_topo in RHO_TOPO_VALUES:
            print(f"\n[Running] N={n}, rho_topo={rho_topo}")
            
            G = generate_ws_network(n, K_NEAREST, rho_topo, seed=SEED)
            metrics, final_phi = simulate_shi_graph_evolution(G, rounds=ROUNDS)
            
            final_gini = metrics['gini'][-1]
            initial_gini = metrics['gini'][0]
            
            clustering = nx.average_clustering(G.to_undirected())
            try:
                if nx.is_connected(G.to_undirected()):
                    path_length = nx.average_shortest_path_length(G.to_undirected())
                else:
                    path_length = float('inf')
            except:
                path_length = float('inf')
            
            bridge_density = calculate_bridge_density(G)
            
            result = {
                'n': n,
                'rho_topo': rho_topo,
                'k': K_NEAREST,
                'rounds': ROUNDS,
                'seed': SEED,
                'initial_gini': round(initial_gini, 4),
                'final_gini': round(final_gini, 4),
                'gini_change': round(final_gini - initial_gini, 4),
                'clustering_coeff': round(clustering, 4),
                'path_length': round(path_length, 4) if path_length != float('inf') else 'inf',
                'bridge_density': round(bridge_density, 4),
                'final_max_phi': round(float(np.max(final_phi)), 4),
                'final_mean_phi': round(float(np.mean(final_phi)), 4),
                'final_std_phi': round(float(np.std(final_phi)), 4),
            }
            
            results.append(result)
            
            print(f"  Initial Gini: {initial_gini:.4f}")
            print(f"  Final Gini:   {final_gini:.4f}")
            print(f"  Clustering:   {clustering:.4f}")
            print(f"  Path Length:  {path_length:.4f}" if path_length != float('inf') else "  Path Length:  inf")
            print(f"  Bridge Dens:  {bridge_density:.4f}")
    
    output_file = 'topology_emergence_results.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
    
    print(f"\n{'=' * 80}")
    print(f"Results saved to: {output_file}")
    print(f"Total experiments: {len(results)}")
    print("=" * 80)
    
    print("\nSummary Table:")
    print(f"{'N':>5} | {'rho_t':>5} | {'Gini0':>7} | {'GiniF':>7} | {'dGini':>7} | {'CC':>6} | {'PL':>6} | {'Bridge':>6}")
    print("-" * 75)
    for r in results:
        pl = f"{r['path_length']:.1f}" if isinstance(r['path_length'], float) else r['path_length']
        print(f"{r['n']:>5} | {r['rho_topo']:>5.1f} | {r['initial_gini']:>7.4f} | {r['final_gini']:>7.4f} | {r['gini_change']:>7.4f} | {r['clustering_coeff']:>6.3f} | {pl:>6} | {r['bridge_density']:>6.3f}")
    
    return results

if __name__ == '__main__':
    results = run_experiment()
    
    with open('topology_emergence_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\nJSON results saved to: topology_emergence_results.json")
