"""
ECHO 3000-node Simulator v4 - K as Potential Conduction Efficiency

Scale: 3000 nodes, 200 rounds, 20 new nodes/round, 100 orchestrations/round
K mechanism (renamed from dCoefficient): weight multiplier on potential increase from orchestration
"""

import random
import math
from collections import defaultdict
import json
import time

SEED = 42
ROUNDS = 200
NODES = 3000
NEW_NODES_PER_ROUND = 20
ORCHESTRATIONS_PER_ROUND = 100

BASE_FEE_RATE = 0.01
BASE_INCOME_T1 = 1.0
BASE_INCOME_T2 = 0.5

MATTHEW_LOSS_PCT = 0.005
MATTHEW_GAIN_PCT = 0.01

K_WEIGHT_MULTIPLIER = {0: 0, 1: 10, 2: 20}

class Node:
    def __init__(self, node_id, tier=1, embedding_depth=0):
        self.id = node_id
        self.tier = tier
        self.embedding_depth = embedding_depth
        self.potential = 100.0 if tier == 1 else 50.0
        self.base_potential = self.potential
        self.cumulative_income = 0.0
        self.orchestration_edges = []
        self.creation_round = 0
        self.is_alive = True
        self.base_income_earned = 0.0

class ShiGraphSimulator3000V4:
    def __init__(self, k_coefficient=1, seed=42):
        self.k = k_coefficient
        self.weight_multiplier = K_WEIGHT_MULTIPLIER[k_coefficient]
        self.seed = seed
        random.seed(seed)
        self.nodes = {}
        self.next_node_id = 0
        self.round = 0
        self.gini_history = []
        self.shannon_history = []
        self.matthew_history = []
        self.new_node_survival = defaultdict(int)
        self._init_nodes()
        
    def _init_nodes(self):
        for i in range(NODES):
            tier = 1 if random.random() < 0.7 else 2
            depth = random.randint(0, 5)
            node = Node(i, tier=tier, embedding_depth=depth)
            node.creation_round = 0
            self.nodes[i] = node
            self.next_node_id = i + 1

    def _distribute_base_income(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        for node in alive_nodes:
            if node.tier == 1:
                node.cumulative_income += BASE_INCOME_T1
                node.base_income_earned += BASE_INCOME_T1
            else:
                node.cumulative_income += BASE_INCOME_T2
                node.base_income_earned += BASE_INCOME_T2
            
    def _add_new_nodes(self):
        for _ in range(NEW_NODES_PER_ROUND):
            node_id = self.next_node_id
            tier = 1 if random.random() < 0.7 else 2
            depth = random.randint(0, 2)
            node = Node(node_id, tier=tier, embedding_depth=depth)
            node.creation_round = self.round
            self.nodes[node_id] = node
            self.next_node_id += 1
            self.new_node_survival[node_id] = 0
            
    def _perform_orchestrations(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        if len(alive_nodes) < 2:
            return
            
        for _ in range(ORCHESTRATIONS_PER_ROUND):
            weights = [n.potential for n in alive_nodes]
            total = sum(weights)
            if total == 0:
                break
            r = random.uniform(0, total)
            cumulative = 0
            source = None
            for n in alive_nodes:
                cumulative += n.potential
                if r <= cumulative:
                    source = n
                    break
            if source is None:
                source = alive_nodes[-1]
            
            candidates = [n for n in alive_nodes if n.id != source.id]
            if not candidates:
                continue
            weights2 = [1.5 if n.tier != source.tier else 1.0 for n in candidates]
            total2 = sum(weights2)
            r2 = random.uniform(0, total2)
            cumulative2 = 0
            target = None
            for n, w in zip(candidates, weights2):
                cumulative2 += w
                if r2 <= cumulative2:
                    target = n
                    break
            if target is None:
                target = candidates[-1]
            
            fee = source.potential * BASE_FEE_RATE
            source.cumulative_income -= fee
            target.cumulative_income += fee
            source.orchestration_edges.append((target.id, 1.0, self.round))
            
            if self.weight_multiplier > 0:
                weight = 1.0
                potential_increase = weight * self.weight_multiplier
                target.base_potential += potential_increase
                target.potential += potential_increase
                
    def _update_potentials(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        total_income = sum(n.cumulative_income for n in alive_nodes)
        if total_income <= 0:
            return
            
        for node in alive_nodes:
            income_ratio = node.cumulative_income / total_income
            if income_ratio > 0.1:
                node.potential += node.potential * MATTHEW_GAIN_PCT
            elif income_ratio < 0.03:
                node.potential -= node.potential * MATTHEW_LOSS_PCT
            node.potential = max(node.potential, 1.0)
            
    def _check_node_survival(self):
        for node_id, rounds_survived in list(self.new_node_survival.items()):
            node = self.nodes[node_id]
            age = self.round - node.creation_round
            if age >= 50:
                if node.potential > 0 and node.is_alive:
                    self.new_node_survival[node_id] = 50
                else:
                    node.is_alive = False
                    self.new_node_survival[node_id] = age
                    
    def _calculate_metrics(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        if not alive_nodes:
            return
            
        incomes = [n.cumulative_income for n in alive_nodes]
        potentials = [n.potential for n in alive_nodes]
        
        gini = self._calculate_gini(incomes)
        self.gini_history.append(gini)
        
        shannon = self._calculate_shannon(potentials)
        self.shannon_history.append(shannon)
        
        matthew = self._calculate_matthew(potentials)
        self.matthew_history.append(matthew)
        
    def _calculate_gini(self, values):
        if not values or sum(values) <= 0:
            return 0.0
        sorted_values = sorted(values)
        n = len(sorted_values)
        cumsum = 0
        total = sum(sorted_values)
        for i, v in enumerate(sorted_values):
            cumsum += (i + 1) * v
        return (2 * cumsum) / (n * total) - (n + 1) / n
        
    def _calculate_shannon(self, values):
        if not values or sum(values) <= 0:
            return 0.0
        total = sum(values)
        proportions = [v / total for v in values if v > 0]
        return -sum(p * math.log(p) for p in proportions if p > 0)
        
    def _calculate_matthew(self, values):
        if not values or sum(values) == 0:
            return 0.0
        sorted_values = sorted(values, reverse=True)
        total = sum(values)
        top_10_count = max(1, len(sorted_values) // 10)
        return sum(sorted_values[:top_10_count]) / total
        
    def run(self):
        for round_num in range(ROUNDS):
            self.round = round_num
            self._distribute_base_income()
            self._add_new_nodes()
            self._perform_orchestrations()
            self._update_potentials()
            self._check_node_survival()
            
            if round_num % 10 == 0 or round_num == ROUNDS - 1:
                self._calculate_metrics()
                
        return self._get_results()
        
    def _get_results(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        survived = sum(1 for v in self.new_node_survival.values() if v >= 50)
        total_new = len(self.new_node_survival)
        survival_rate = survived / total_new if total_new > 0 else 0.0
        
        return {
            "k_coefficient": self.k,
            "rounds": ROUNDS,
            "final_node_count": len(alive_nodes),
            "total_nodes_created": self.next_node_id,
            "matthew_convergence": self.matthew_history[-1] if self.matthew_history else 0.0,
            "matthew_history": self.matthew_history,
            "gini_final": self.gini_history[-1] if self.gini_history else 0.0,
            "gini_history": self.gini_history,
            "shannon_final": self.shannon_history[-1] if self.shannon_history else 0.0,
            "shannon_history": self.shannon_history,
            "new_node_survival_rate_50r": survival_rate,
            "matthew_round_50": self.matthew_history[5] if len(self.matthew_history) > 5 else 0.0,
            "matthew_round_100": self.matthew_history[10] if len(self.matthew_history) > 10 else 0.0,
            "matthew_round_150": self.matthew_history[15] if len(self.matthew_history) > 15 else 0.0,
        }

if __name__ == '__main__':
    start = time.time()
    print(f"Starting 3000-node v4 simulation (K renamed)...")
    
    results = {}
    for k in [0, 1, 2]:
        print(f"\n{'='*60}")
        print(f"K={k} (potential weight multiplier={K_WEIGHT_MULTIPLIER[k]}x)")
        print(f"{'='*60}")
        
        sim = ShiGraphSimulator3000V4(k_coefficient=k, seed=42)
        result = sim.run()
        results[f"K_{k}"] = result
        
        print(f"Final nodes: {result['final_node_count']}")
        print(f"Matthew: {result['matthew_convergence']:.4f}")
        print(f"Gini: {result['gini_final']:.4f}")
        print(f"Shannon: {result['shannon_final']:.4f}")
        print(f"Survival: {result['new_node_survival_rate_50r']:.2%}")
    
    elapsed = time.time() - start
    print(f"\n{'='*60}")
    print(f"3000-NODE V4 RESULTS (runtime: {elapsed:.1f}s)")
    print(f"{'='*60}")
    for key, result in results.items():
        k = result['k_coefficient']
        matthew = result['matthew_convergence']
        in_target = 0.15 <= matthew <= 0.25
        print(f"K={k}: Matthew={matthew:.4f} {'✅' if in_target else '❌'}")
    
    k0 = results['K_0']['matthew_convergence']
    k2 = results['K_2']['matthew_convergence']
    print(f"\nK=0 vs K=2 difference: {abs(k0 - k2):.4f}")
    print(f"K sensitivity: {'✅ STRONG' if abs(k0 - k2) > 0.01 else '❌ WEAK'}")
    
    with open('/root/.openclaw/workspace/baseline_3000nodes_v4.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to baseline_3000nodes_v4.json")
