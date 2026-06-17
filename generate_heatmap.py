#!/usr/bin/env python3
"""
ECHO 三参数耦合相图 —— ξ-ρ 热力图（Gini 颜色映射）
ξ（综合开放度）× ρ_topo（桥接密度）平面，颜色 = Gini 系数
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans', 'Arial Unicode MS']
matplotlib.rcParams['axes.unicode_minus'] = False

# 读取数据
df = pd.read_csv('/root/.openclaw/workspace/trio_coupling_results_v2.csv')

# 筛选 β=0.10（推荐值）做热力图
df_beta = df[df['beta'] == 0.10].copy()

# 透视表：行=ξ，列=ρ_topo，值=Gini
pivot = df_beta.pivot(index='xi', columns='rho_topo', values='gini_final')

# 确保行列顺序
xi_labels = [0, 1, 2, 3, 4]
rho_labels = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0]
pivot = pivot.reindex(index=xi_labels, columns=rho_labels)

# 中文标签
xi_labels_cn = ['禁\n(ξ=0)', '己\n(ξ=1)', '亲\n(ξ=2)', '约\n(ξ=3)', '法\n(ξ=4)']
rho_labels_cn = ['0.0', '0.1', '0.2', '0.3', '0.5', '0.8', '1.0']

fig, ax = plt.subplots(figsize=(10, 6))

# 热力图：颜色越暖（红）Gini越高，越冷（蓝绿）Gini越低
im = ax.imshow(pivot.values, cmap='RdYlGn_r', aspect='auto', vmin=0.08, vmax=0.28)

# 设置刻度
ax.set_xticks(np.arange(len(rho_labels)))
ax.set_yticks(np.arange(len(xi_labels)))
ax.set_xticklabels(rho_labels_cn, fontsize=11)
ax.set_yticklabels(xi_labels_cn, fontsize=11)

# 坐标轴标签
ax.set_xlabel('桥接密度 ρ_topo', fontsize=13, fontweight='bold')
ax.set_ylabel('综合开放度 ξ', fontsize=13, fontweight='bold')
ax.set_title('ECHO 三参数耦合相图\nξ-ρ 平面 × Gini 系数（β=0.10）', fontsize=14, fontweight='bold', pad=15)

# 在每个格子里标注数值
for i in range(len(xi_labels)):
    for j in range(len(rho_labels)):
        val = pivot.values[i, j]
        if not np.isnan(val):
            # 根据背景色亮度决定文字颜色
            color = 'white' if val > 0.18 else 'black'
            ax.text(j, i, f'{val:.3f}', ha='center', va='center', fontsize=10, color=color, fontweight='bold')

# 标注推荐组合点：ξ=4, ρ=0.2 → Gini=0.105
# 在图中标记为星号
rec_xi_idx = 4   # ξ=4
rec_rho_idx = 2  # ρ=0.2
ax.plot(rec_rho_idx, rec_xi_idx, marker='*', markersize=20, color='cyan', markeredgecolor='black', markeredgewidth=1.5, zorder=10)
ax.annotate('推荐\nξ=4, ρ=0.2\nGini=0.105', xy=(rec_rho_idx, rec_xi_idx), xytext=(rec_rho_idx+1.5, rec_xi_idx-0.5),
            fontsize=10, color='cyan', fontweight='bold',
            arrowprops=dict(arrowstyle='->', color='cyan', lw=1.5),
            bbox=dict(boxstyle='round,pad=0.3', facecolor='black', edgecolor='cyan', alpha=0.8))

# 添加哪吒拍板参数点：ξ=2, β=0.01, ρ=0.5 → Gini=0.133
nezha_xi_idx = 2   # ξ=2
nezha_rho_idx = 4  # ρ=0.5
ax.plot(nezha_rho_idx, nezha_xi_idx, marker='D', markersize=12, color='gold', markeredgecolor='black', markeredgewidth=1.5, zorder=10)
ax.annotate('哪吒拍板\nξ=2, ρ=0.5', xy=(nezha_rho_idx, nezha_xi_idx), xytext=(nezha_rho_idx+1.2, nezha_xi_idx+0.5),
            fontsize=9, color='gold', fontweight='bold',
            arrowprops=dict(arrowstyle='->', color='gold', lw=1.5),
            bbox=dict(boxstyle='round,pad=0.3', facecolor='black', edgecolor='gold', alpha=0.8))

# 色条
cbar = plt.colorbar(im, ax=ax, shrink=0.8, pad=0.02)
cbar.set_label('Gini 系数（越低越平等）', fontsize=11, fontweight='bold')
cbar.ax.tick_params(labelsize=10)

# 添加图例说明
legend_text = (
    '● 青色 ★ = 推荐参数（Gini 最低且稳定）\n'
    '● 金色 ◆ = 哪吒拍板参数\n'
    '● 颜色：红=不平等高，绿=不平等低'
)
ax.text(1.02, -0.18, legend_text, transform=ax.transAxes, fontsize=9,
        verticalalignment='top', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

plt.tight_layout()
plt.savefig('/root/.openclaw/workspace/reports/e4_trio_heatmap.png', dpi=200, bbox_inches='tight', facecolor='white')
plt.savefig('/root/.openclaw/workspace/reports/e4_trio_heatmap.svg', bbox_inches='tight', facecolor='white')
print("热力图已保存：")
print("  - reports/e4_trio_heatmap.png")
print("  - reports/e4_trio_heatmap.svg")

# 同时生成三个 β 值对比图
fig2, axes = plt.subplots(1, 3, figsize=(18, 5))
betas = [0.01, 0.10, 1.00]
beta_labels = ['β=0.01（默认）', 'β=0.10（推荐）', 'β=1.00']

for ax_idx, (beta, blabel) in enumerate(zip(betas, beta_labels)):
    df_b = df[df['beta'] == beta].copy()
    pivot_b = df_b.pivot(index='xi', columns='rho_topo', values='gini_final')
    pivot_b = pivot_b.reindex(index=xi_labels, columns=rho_labels)
    
    im2 = axes[ax_idx].imshow(pivot_b.values, cmap='RdYlGn_r', aspect='auto', vmin=0.08, vmax=0.28)
    axes[ax_idx].set_xticks(np.arange(len(rho_labels)))
    axes[ax_idx].set_yticks(np.arange(len(xi_labels)))
    axes[ax_idx].set_xticklabels(rho_labels_cn, fontsize=10)
    if ax_idx == 0:
        axes[ax_idx].set_yticklabels(xi_labels_cn, fontsize=10)
    else:
        axes[ax_idx].set_yticklabels([])
    axes[ax_idx].set_xlabel('桥接密度 ρ_topo', fontsize=11)
    axes[ax_idx].set_title(blabel, fontsize=12, fontweight='bold')
    
    for i in range(len(xi_labels)):
        for j in range(len(rho_labels)):
            val = pivot_b.values[i, j]
            if not np.isnan(val):
                color = 'white' if val > 0.18 else 'black'
                axes[ax_idx].text(j, i, f'{val:.3f}', ha='center', va='center', fontsize=9, color=color, fontweight='bold')
    
    if beta == 0.10:
        axes[ax_idx].plot(2, 4, marker='*', markersize=18, color='cyan', markeredgecolor='black', markeredgewidth=1.5, zorder=10)

fig2.suptitle('ECHO 三参数耦合 — β 对比', fontsize=14, fontweight='bold', y=1.02)
fig2.colorbar(im2, ax=axes, shrink=0.8, label='Gini 系数')
plt.tight_layout()
plt.savefig('/root/.openclaw/workspace/reports/e4_trio_heatmap_beta_compare.png', dpi=200, bbox_inches='tight', facecolor='white')
print("  - reports/e4_trio_heatmap_beta_compare.png")

print("\n✅ 全部完成")
