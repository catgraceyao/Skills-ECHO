# 2:1 Weight Ratio Theory — ECHO v0.1 Hypothesis Document

**Version**: v0.1  
**Status**: Theoretical Hypothesis / Not Validated in v0.1  
**Date**: 2026-06-14  
**Author**: X7 (theoretical framework), Cat.zhou (validation planning)  

---

## 1. Hypothesis Statement

In the ECHO Shi-Graph engine, **inbound-to-outbound edge weight ratio of 2:1** produces optimal position distribution characteristics:

- **T1 (Top tier) position ≈ 2× T2 (Second tier)**
- **T2:T3:T4 ratio ≈ 1.84:1.83:1.81** (near-flat, with slight T1 dominance)
- This ratio emerges from the **stake-weighted initial position assignment** combined with **diffusion dynamics**

---

## 2. Theoretical Basis

### 2.1 Why 2:1?

The 2:1 ratio is proposed based on:

1. **Network science intuition**: In directed networks where "being pointed to" (inbound) is more valuable than "pointing out" (outbound), a moderate asymmetry prevents complete flattening while avoiding extreme concentration.

2. **Creator economy observation**: Early creators with higher stakes (more "skin in the game") should have proportionally more influence, but not so much that latecomers cannot compete.

3. **Stability criterion**: The ratio should be large enough to create tier differentiation, small enough to not collapse into winner-take-all.

### 2.2 Expected Mechanism

```
High-stake creator (stake = 10 ETH)
  → phi_initial = log(1 + 10) = 2.40
  → Higher initial position
  → More inbound edges attracted
  → Position accumulates faster than outbound
  → Maintains 2:1 advantage over median creator
```

---

## 3. Why v0.1 Did NOT Validate This

### 3.1 v0.1 Model Limitations

| Aspect | v0.1 Reality | What 2:1 Needs |
|--------|-------------|----------------|
| phi_init | 1.0 (uniform for all nodes) | log(1 + stake_i) (stake-dependent) |
| Stake effect | Only affects event source terms | Affects initial position directly |
| Diffusion | D=0.03 dominates quickly | D must be calibrated to preserve initial asymmetry |
| Result | T1:T2:T3:T4 ≈ 2.00:1.84:1.83:1.81 (flat) | T1 ≈ 2× T2, clear tier separation |

### 3.2 Root Cause

With **uniform phi_init = 1.0**, all nodes start equal. The small differences introduced by stake (via event source terms) are rapidly averaged out by:
- HOLD (0.01 per round)
- Diffusion D (0.03)
- Event injection λ (0.02)

These three forces act as **equalizers**, washing out initial stake differences within ~50 rounds.

### 3.3 What Would Validate 2:1

To observe the 2:1 ratio, the model needs:

1. **Non-uniform initial position**: phi_initial = f(stake) where f is monotonic and sub-linear (e.g., log(1 + stake))
2. **Calibrated diffusion**: D low enough that initial asymmetry persists, high enough that dead nodes don't hold position forever
3. **Time to observe**: 100+ rounds for tier structure to stabilize

---

## 4. v0.2 Validation Plan

### 4.1 Modified Parameters

| Parameter | v0.1 Value | v0.2 Proposed | Rationale |
|-----------|-----------|---------------|-----------|
| phi_init | 1.0 (uniform) | log(1 + stake_i) | Stake → position mapping |
| stake distribution | Pareto(γ=2.0) | Same | Realistic creator wealth distribution |
| D | 0.03 | 0.03 (or lower) | Preserve initial asymmetry |
| κ | 0.001 | 0.001 | Same position hold |
| λ | 0.02 | 0.02 | Same event injection |

### 4.2 Success Criteria

- **Tier ratio**: T1:T2:T3:T4 = 2.0:1.0:0.8:0.6 (or similar, with T1 clearly dominant)
- **Gini range**: Gini between 0.35–0.45 (more stratified than v0.1's 0.044)
- **Stability**: Ratio persists for 100+ rounds after initial transient
- **Robustness**: Consistent across ρ values (0.30–0.55)

### 4.3 Failure Modes

- **Diffusion too strong**: Even log(1 + stake) differences get averaged out → ratio doesn't emerge
- **Diffusion too weak**: High-stake nodes lock in position permanently → Gini > 0.5, unfair
- **Stake distribution too extreme**: Pareto(γ=2) might produce too few high-stake nodes → T1 too small

---

## 5. Related Literature

### 5.1 Network Science
- **Watts-Strogatz model**: ρ controls small-world transition; position dynamics add non-linear layer
- **Preferential attachment**: High-stake nodes attract more edges; but ECHO adds diffusion counterbalance
- **Rich-club phenomenon**: High-degree nodes interconnect; 2:1 ratio might prevent excessive rich-club dominance

### 5.2 Economics
- **Pareto principle**: 80/20 distribution natural in creator economies; 2:1 is milder than Pareto
- **Gini coefficient**: 0.35–0.45 is "moderate inequality" — healthy for incentives without being unfair
- **Wealth condensation**: Too much asymmetry → wealth freezes; too little → no incentive gradient

### 5.3 Ecology
- **Trophic cascades**: Top predators (T1) control ecosystem; removing them causes collapse
- **Keystone species**: Small number of high-stake nodes stabilize the network
- **Biodiversity**: Flat distribution (Gini < 0.2) = monoculture; too stratified (Gini > 0.5) = fragile

---

## 6. Open Questions

1. **Is 2:1 the right number?** Could be 1.5:1 or 3:1 depending on creator economy norms. Needs empirical calibration.

2. **Does ρ affect the ratio?** In v0.1, ρ changes Gini but not tier ratio (because phi_init uniform). In v0.2, ρ might interact with stake→phi mapping.

3. **What about dynamic stakes?** Real creators add/remove stake over time. Static model is first approximation.

4. **Can the ratio be gamed?** If creators know T1 gets 2× position, they might collude to artificially inflate stakes.

---

## 7. Conclusion

The 2:1 weight ratio is a **theoretically motivated hypothesis** for ECHO's tier structure. It is:
- ✅ Grounded in network science and creator economy intuition
- ❌ **Not validated** by v0.1 simulations (uniform phi_init prevents ratio emergence)
- 🔄 **Scheduled for v0.2 validation** with stake-dependent initial position

**v0.1 contribution**: Established that topology (ρ) affects position distribution uniformity. This is the foundation upon which v0.2 will add stake asymmetry.

---

*Document prepared by X7 and Cat.zhou. For questions, contact the ECHO Agent team.*
