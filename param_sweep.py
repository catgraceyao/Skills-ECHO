"""
Quick parameter sweep to find baseline Matthew ~0.15-0.25
Try weaker Matthew effect parameters
"""

import random
import math
from collections import defaultdict

SEED = 42
ROUNDS = 200
NODES = 300
NEW_NODES_PER_ROUND = 2
ORCHESTRATIONS_PER_ROUND = 10
BASE_FEE_RATE = 0.01
BASE_INCOME_T1 = 1.0
BASE_INCOME_T2 = 0.5

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

def run_simulation(gain_pct, loss_pct, seed=42):
    random.seed(seed)
    nodes = {}
    next_node_id = 0
    matthew_history = []
    
    # Init
    for i in range(NODES):
        tier = 1 if random.random() < 0.7 else 2
        depth = random.randint(0, 5)
        node = Node(i, tier=tier, embedding_depth=depth)
        node.creation_round = 0
        nodes[i] = node
        next_node_id = i + 1
    
    for round_num in range(ROUNDS):
        # Base income
        alive_nodes = [n for n in nodes.values() if n.is_alive]
        for node in alive_nodes:
            if node.tier == 1:
                node.cumulative_income += BASE_INCOME_T1
                node.base_income_earned += BASE_INCOME_T1
            else:
                node.cumulative_income += BASE_INCOME_T2
                node.base_income_earned += BASE_INCOME_T2
        
        # Add new nodes
        for _ in range(NEW_NODES_PER_ROUND):
            node_id = next_node_id
            tier = 1 if random.random() < 0.7 else 2
            depth = random.randint(0, 2)
            node = Node(node_id, tier=tier, embedding_depth=depth)
            node.creation_round = round_num
            nodes[node_id] = node
            next_node_id += 1
        
        # Orchestrations
        alive_nodes = [n for n in nodes.values() if n.is_alive]
        for _ in range(ORCHESTRATIONS_PER_ROUND):
            if len(alive_nodes) < 2:
                break
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
        
        # Update potentials (Matthew effect)
        alive_nodes = [n for n in nodes.values() if n.is_alive]
        total_income = sum(n.cumulative_income for n in alive_nodes)
        if total_income > 0:
            for node in alive_nodes:
                income_ratio = node.cumulative_income / total_income
                if income_ratio > 0.1:
                    node.potential += node.potential * income_ratio * gain_pct
                elif income_ratio < 0.03:
                    node.potential -= node.potential * loss_pct
                node.potential = max(node.potential, 1.0)
        
        # Metrics every 10 rounds
        if round_num % 10 == 0 or round_num == ROUNDS - 1:
            alive = [n for n in nodes.values() if n.is_alive]
            if alive:
                potentials = [n.potential for n in alive]
                sorted_p = sorted(potentials, reverse=True)
                total_p = sum(potentials)
                top_10_count = max(1, len(sorted_p) // 10)
                matthew = sum(sorted_p[:top_10_count]) / total_p if total_p > 0 else 0.0
                matthew_history.append(matthew)
    
    return matthew_history[-1] if matthew_history else 0.0

# Parameter sweep
gain_values = [0.005, 0.01, 0.02, 0.03, 0.05]
loss_values = [0.001, 0.005, 0.01, 0.02]

print("Parameter sweep: gain_pct (top 10%) vs loss_pct (bottom 30%)")
print(f"{'='*60}")
print(f"{'gain':>6} {'loss':>6} {'Matthew':>8} {'Status':>10}")
print(f"{'-'*60}")

for gain in gain_values:
    for loss in loss_values:
        matthew = run_simulation(gain, loss, seed=42)
        status = "✅" if 0.15 <= matthew <= 0.25 else "❌"
        print(f"{gain:>6.1%} {loss:>6.1%} {matthew:>8.4f} {status:>10}")

print(f"{'='*60}")
print("Target: Matthew 0.15-0.25")
