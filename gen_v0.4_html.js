const fs = require('fs');
const marked = require('marked');

const md = fs.readFileSync('docs/echo-contract-interface-v0.4-draft.md', 'utf8');
const htmlContent = marked.parse(md);

const template = fs.readFileSync('echo_contract.html', 'utf8');
const styleMatch = template.match(/<style>[\s\S]*?<\/style>/);
const style = styleMatch ? styleMatch[0] : '';

const newHtml = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>ECHO 协议 v0.4 合约接口正式版</title>
<meta name="deployed" content="github-pages">
${style}
</head>
<body>

<h1>ECHO 协议 v0.4 合约接口正式版</h1>

<div class="meta">
<strong>作者</strong>：猫先森（Cat） | <strong>日期</strong>：2026-05-23 | <strong>状态</strong>：Final v0.4<br>
<strong>审阅记录</strong>：基于 v0.3 遗留问题和社区反馈，18 项核心修正全部落实<br>
<strong>文档大小</strong>：47KB | <strong>总行数</strong>：1640 行
</div>

<div class="review-map">
<strong>v0.4 核心变更速览</strong>：DAO_MIN_MEMBERS 5→11 | TOPUP定价锚定（3天公示期+TWAP） | 快速通道分级（severity 4→24h冷却/5→多签立即执行） | 势位权重50:50动态 | Agent陪审团接口 | 信誉分双轨 | 自适应阈值（Tukey fences） | 退出gas兜底池 | 反证质押 0.05 ETH
</div>

${htmlContent}

</body>
</html>`;

fs.writeFileSync('echo_contract_v0.4.html', newHtml);
console.log('v0.4 HTML generated: ' + newHtml.length + ' chars');
