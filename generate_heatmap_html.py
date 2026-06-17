#!/usr/bin/env python3
"""
ECHO 三参数耦合相图 —— ξ-ρ 热力图（HTML 版本）
无需 matplotlib，纯 Python + HTML/CSS 生成
"""

import pandas as pd
import numpy as np

# 读取数据
df = pd.read_csv('/root/.openclaw/workspace/trio_coupling_results_v2.csv')

# 筛选 β=0.10
df_beta = df[df['beta'] == 0.10].copy()
pivot = df_beta.pivot(index='xi', columns='rho_topo', values='gini_final')

xi_labels = [0, 1, 2, 3, 4]
rho_labels = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8, 1.0]
pivot = pivot.reindex(index=xi_labels, columns=rho_labels)

xi_names = ['禁 (ξ=0)', '己 (ξ=1)', '亲 (ξ=2)', '约 (ξ=3)', '法 (ξ=4)']

# 颜色映射函数：Gini 0.08->0.28，映射到颜色
def gini_to_color(gini):
    """Gini 越低越绿，越高越红"""
    t = (gini - 0.08) / (0.28 - 0.08)  # 归一化到 0-1
    t = max(0, min(1, t))
    # RdYlGn_r: 红(高) -> 黄 -> 绿(低)
    if t < 0.5:
        # 绿到黄
        r = int(255 * (t * 2))
        g = 200 + int(55 * (1 - t * 2))
        b = int(50 * (1 - t * 2))
    else:
        # 黄到红
        r = 255
        g = int(200 * (1 - (t - 0.5) * 2))
        b = int(50 * (1 - (t - 0.5) * 2))
    return f"#{r:02x}{g:02x}{b:02x}"

def text_color(gini):
    """根据背景色亮度选择文字颜色"""
    return "white" if gini > 0.18 else "black"

# 生成 HTML
html = """<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>ECHO 三参数耦合相图 — ξ-ρ 热力图</title>
<style>
body { font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif; margin: 40px; background: #fafafa; }
h1 { text-align: center; color: #2d3436; }
h2 { text-align: center; color: #636e72; font-weight: normal; margin-top: -10px; }
.heatmap { margin: 30px auto; border-collapse: collapse; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
.heatmap th, .heatmap td { width: 90px; height: 60px; text-align: center; font-size: 14px; border: 1px solid #ddd; }
.heatmap th { background: #2d3436; color: white; font-weight: bold; }
.heatmap .row-label { background: #636e72; color: white; font-weight: bold; width: 80px; }
.heatmap td { font-weight: bold; position: relative; }
.recommended { border: 3px solid cyan !important; box-shadow: 0 0 10px cyan; }
.nezha { border: 3px solid gold !important; }
.star { position: absolute; top: 2px; right: 2px; font-size: 16px; color: cyan; text-shadow: 0 0 3px black; }
.diamond { position: absolute; top: 2px; left: 2px; font-size: 14px; color: gold; text-shadow: 0 0 3px black; }
.legend { margin: 20px auto; padding: 15px; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); max-width: 600px; }
.legend-item { display: inline-block; margin: 5px 15px; }
.legend-color { display: inline-block; width: 20px; height: 20px; border-radius: 3px; vertical-align: middle; margin-right: 5px; border: 1px solid #ccc; }
.summary { margin: 20px auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); max-width: 700px; }
.summary h3 { margin-top: 0; color: #2d3436; }
</style>
</head>
<body>
<h1>🌡️ ECHO 三参数耦合相图</h1>
<h2>ξ（综合开放度）× ρ_topo（桥接密度）平面 × Gini 系数（β=0.10）</h2>

<table class="heatmap">
<tr>
<th>ξ \ ρ</th>
"""

for r in rho_labels:
    html += f'<th>{r}</th>'
html += '</tr>\n'

for i, xi in enumerate(xi_labels):
    html += f'<tr><td class="row-label">{xi_names[i]}</td>'
    for j, rho in enumerate(rho_labels):
        gini = pivot.values[i, j]
        color = gini_to_color(gini)
        txt_color = text_color(gini)
        classes = []
        markers = ""
        
        # 推荐点：ξ=4, ρ=0.2
        if xi == 4 and abs(rho - 0.2) < 0.01:
            classes.append('recommended')
            markers += '<span class="star">★</span>'
        
        # 哪吒拍板点：ξ=2, ρ=0.5
        if xi == 2 and abs(rho - 0.5) < 0.01:
            classes.append('nezha')
            markers += '<span class="diamond">◆</span>'
        
        cls = ' '.join(classes) if classes else ''
        html += f'<td style="background-color: {color}; color: {txt_color};" class="{cls}">{gini:.3f}{markers}</td>'
    html += '</tr>\n'

html += """
</table>

<div class="legend">
<strong>📊 图例</strong><br>
<span class="legend-item"><span class="legend-color" style="background: #00ff66;"></span> Gini &lt; 0.12（高度平等）</span>
<span class="legend-item"><span class="legend-color" style="background: #ccff66;"></span> Gini 0.12-0.18（中等）</span>
<span class="legend-item"><span class="legend-color" style="background: #ffcc00;"></span> Gini 0.18-0.22（偏高）</span>
<span class="legend-item"><span class="legend-color" style="background: #ff3300;"></span> Gini &gt; 0.22（高度不平等）</span><br>
<span class="legend-item">★ 青色 = 推荐参数（ξ=4, ρ=0.2, Gini=0.105）</span>
<span class="legend-item">◆ 金色 = 哪吒拍板参数（ξ=2, ρ=0.5, Gini=0.133）</span>
</div>

<div class="summary">
<h3>📋 核心结论</h3>
<ul>
<li><strong>ξ 主导效应</strong>：ξ 从 0（禁）到 4（法），Gini 从 0.27 降到 0.08。开放度是势位分布的第一决定因素。</li>
<li><strong>ρ_topo 辅助效应</strong>：高 ξ（全开放）时，高桥接密度会导致 Gini 反弹。ξ=4, ρ=1.0 时 Gini 回升至 0.195。</li>
<li><strong>β 不敏感</strong>：β=0.01/0.1/1.0 在相同 (ξ, ρ) 下 Gini 差异通常 &lt;0.02。维持默认值 0.01 合理。</li>
<li><strong>推荐参数</strong>：ξ=4, β=0.10, ρ_topo=0.2 → Gini=0.105, Matthew=1.93。全开放 + 适度约束 + 低桥接，兼顾平等与稳定。</li>
</ul>
<p><em>数据来源：105 组三参数耦合实验（ξ 5×β 3×ρ_topo 7），N=500，200 轮，Watts-Strogatz 网络</em></p>
</div>

</body>
</html>
"""

with open('/root/.openclaw/workspace/reports/e4_trio_heatmap.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("✅ 热力图 HTML 已保存：reports/e4_trio_heatmap.html")

# 同时生成一个纯文本版热力图用于群聊粘贴
text_heatmap = "ECHO 三参数耦合相图（β=0.10）\n"
text_heatmap += "=" * 70 + "\n"
text_heatmap += "ξ \\ ρ     0.0    0.1    0.2    0.3    0.5    0.8    1.0\n"
text_heatmap += "-" * 70 + "\n"

for i, xi in enumerate(xi_labels):
    row = f"{xi_names[i]:8}"
    for j, rho in enumerate(rho_labels):
        gini = pivot.values[i, j]
        marker = ""
        if xi == 4 and abs(rho - 0.2) < 0.01:
            marker = " ★"
        elif xi == 2 and abs(rho - 0.5) < 0.01:
            marker = " ◆"
        row += f" {gini:.3f}{marker:2}"
    text_heatmap += row + "\n"

text_heatmap += "-" * 70 + "\n"
text_heatmap += "★ = 推荐（ξ=4, ρ=0.2, Gini=0.105）\n"
text_heatmap += "◆ = 哪吒拍板（ξ=2, ρ=0.5, Gini=0.133）\n"

with open('/root/.openclaw/workspace/reports/e4_trio_heatmap.txt', 'w', encoding='utf-8') as f:
    f.write(text_heatmap)

print("✅ 纯文本版已保存：reports/e4_trio_heatmap.txt")
print("\n热力图预览（β=0.10）：")
print(text_heatmap)
