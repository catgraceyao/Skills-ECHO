"""
ECHO 300-node Simulator - D Coefficient Sensitivity Test (v3 - D=conduction efficiency)
Seed=42, 200 rounds, D=0/1/2 three groups

Key change: D coefficient affects potential CONDUCTION efficiency, not fee
- D=0 (Disabled): orchestrations do NOT transfer potential (conduction=0)
- D=1 (Standard): standard potential transfer (conduction=1.0)
- D=2 (Doubled): doubled potential transfer (conduction=2.0)
"""

import random
import math
from collections import defaultdict
import json

# Configuration
SEED = 42
ROUNDS = 200
NODES = 300
NEW_NODES_PER_ROUND = 2
ORCHESTRATIONS_PER_ROUND = 10

# D coefficient settings - affects conduction efficiency
D_DISABLED = 0    # D=0: no potential conduction
D_STANDARD = 1    # D=1: standard conduction (1.0x)
D_DOUBLED = 2     # D=2: doubled conduction (2.0x)

CONDUCTION_MULTIPLIER = {0: 0.0, 1: 1.0, 2: 2.0}

BASE_FEE_RATE = 0.01  # 1% base fee (for income transfer)
BASE_INCOME_T1 = 1.0   # Base income per round for Tier 1
BASE_INCOME_T2 = 0.5   # Base income per round for Tier 2

# Shi-Graph structural parameters
DECAY_RATE_BPS = 100  # 1% decay per round
EMBEDDING_DEPTH_FACTOR = 0.3
BRIDGE_BOOST_BPS = 500  # 5% boost for cross-community bridge

class Node:
    def __init__(self, node_id, tier=1, embedding_depth=0):
        self.id = node_id
        self.tier = tier
        self.embedding_depth = embedding_depth
        self.potential = 100.0 if tier == 1 else 50.0
        self.cumulative_income = 0.0
        self.orchestration_edges = []
        self.creation_round = 0
        self.is_alive = True
        self.base_income_earned = 0.0
        
    def get_decayed_potential(self, current_round):
        age = current_round - self.creation_round
        decay = (1 - DECAY_RATE_BPS / 10000) ** age
        return self.potential * decay
    
    def get_effective_potential(self, current_round, graph):
        base = self.get_decayed_potential(current_round)
        depth_multiplier = 1 + (self.embedding_depth * EMBEDDING_DEPTH_FACTOR)
        bridge_count = sum(1 for e in self.orchestration_edges 
                          if graph[e[0]].tier != self.tier)
        bridge_boost = 1 + (bridge_count * BRIDGE_BOOST_BPS / 10000)
        return base * depth_multiplier * bridge_boost

class ShiGraphSimulator:
    def __init__(self, d_coefficient, seed=42):
        self.d = d_coefficient
        self.conduction = CONDUCTION_MULTIPLIER[d_coefficient]
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
            source = self._weighted_select(alive_nodes, key=lambda n: n.potential)
            
            candidates = [n for n in alive_nodes if n.id != source.id]
            if not candidates:
                continue
                
            target = self._weighted_select(candidates, 
                key=lambda n: 1.5 if n.tier != source.tier else 1.0)
            
            weight = self._calculate_edge_weight(source, target)
            source.orchestration_edges.append((target.id, weight, self.round))
            
            # Income transfer (fee) - always happens regardless of D
            fee = source.potential * BASE_FEE_RATE
            source.cumulative_income -= fee
            target.cumulative_income += fee
            
            # Potential conduction based on D coefficient
            # D=0: no conduction, D=1: standard, D=2: doubled
            if self.conduction > 0:
                conduction_amount = fee * self.conduction * 0.5  # 50% of fee goes to potential
                target.potential += conduction_amount
                
    def _weighted_select(self, items, key):
        weights = [key(item) for item in items]
        total = sum(weights)
        if total == 0:
            return random.choice(items)
        r = random.uniform(0, total)
        cumulative = 0
        for item, w in zip(items, weights):
            cumulative += w
            if r <= cumulative:
                return item
        return items[-1]
        
    def _calculate_edge_weight(self, source, target):
        ratio = source.potential / (target.potential + 1)
        return min(ratio, 5.0)
        
    def _update_potentials(self):
        alive_nodes = [n for n in self.nodes.values() if n.is_alive]
        
        total_income = sum(n.cumulative_income for n in alive_nodes)
        if total_income <= 0:
            return
            
        for node in alive_nodes:
            income_ratio = node.cumulative_income / total_income
            
            if income_ratio > 0.1:
                node.potential += node.potential * income_ratio * 0.05
            elif income_ratio < 0.03:
                node.potential -= node.potential * 0.01
                
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
        top_10_share = sum(sorted_values[:top_10_count]) / total
        
        return top_10_share
        
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
            "d_coefficient": self.d,
            "conduction_multiplier": self.conduction,
            "seed": self.seed,
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


def main():
    results = {}
    
    for d in [D_DISABLED, D_STANDARD, D_DOUBLED]:
        print(f"\n{'='*60}")
        print(f"Running D={d} ({['Disabled', 'Standard', 'Doubled'][d]})")
        print(f"Conduction multiplier: {CONDUCTION_MULTIPLIER[d]}x")
        print(f"{'='*60}")
        
        sim = ShiGraphSimulator(d_coefficient=d, seed=SEED)
        result = sim.run()
        results[f"D_{d}"] = result
        
        print(f"Final node count: {result['final_node_count']}")
        print(f"Matthew convergence (final): {result['matthew_convergence']:.4f}")
        print(f"Gini coefficient (final): {result['gini_final']:.4f}")
        print(f"Shannon index (final): {result['shannon_final']:.4f}")
        print(f"New node survival rate (50r): {result['new_node_survival_rate_50r']:.2%}")
        print(f"Matthew R50: {result['matthew_round_50']:.4f}")
        print(f"Matthew R100: {result['matthew_round_100']:.4f}")
        print(f"Matthew R150: {result['matthew_round_150']:.4f}")
        
    with open('/root/.openclaw/workspace/d_coefficient_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
        
    print(f"\n{'='*60}")
    print("COMPARISON SUMMARY")
    print(f"{'='*60}")
    
    for key, result in results.items():
        d = result['d_coefficient']
        label = ['Disabled', 'Standard', 'Doubled'][d]
        print(f"\nD={d} ({label}, conduction={result['conduction_multiplier']}x):")
        print(f"  Matthew: {result['matthew_convergence']:.4f} (target: 0.15-0.25)")
        print(f"  Gini: {result['gini_final']:.4f}")
        print(f"  Shannon: {result['shannon_final']:.4f}")
        print(f"  Survival: {result['new_node_survival_rate_50r']:.2%}")
        
    print(f"\n{'='*60}")
    print("TARGET CHECK: Matthew 0.15-0.25")
    print(f"{'='*60}")
    for key, result in results.items():
        d = result['d_coefficient']
        label = ['Disabled', 'Standard', 'Doubled'][d]
        matthew = result['matthew_convergence']
        in_target = 0.15 <= matthew <= 0.25
        print(f"D={d} ({label}): {matthew:.4f} {'✅' if in_target else '❌'}")
        

if __name__ == '__main__':
    main()
