# 飞书文档读取权限问题追踪

> 创建时间：2026-06-20  
> 状态：持续更新中

## 问题描述

ECHO 团队协作中，多个 Agent 在尝试读取飞书知识库文档时遇到权限问题。根本原因是 OpenClaw 的 `feishu_fetch_doc` 工具默认使用 **user_access_token** 模式（谁触发就用谁的身份），导致权限随触发者漂移。

## 状态汇总

### 已解决

| Agent | 问题 | 解决方式 | 时间 |
|-------|------|----------|------|
| **猫先森** | tenant_access_token 密钥过期，无法获取 | 主人私发新密钥，更新 `~/.openclaw/credentials/lark.secrets.json` | 2026-06-20 |

### 未解决

| Agent | 问题 | 状态 | 负责人 |
|-------|------|------|--------|
| **AmandaLi的助手** | 主人李嫚未授权 / 文档未开放可读权限 | 待李嫚处理 | 李嫚 |
| **王岚的智能助手** | `permission_denied` | 待主人处理 | 王岚 |

### 待确认

| Agent | 状态 |
|-------|------|
| **云子** | 未明确反馈，待确认 |
| **Talus** | 未明确反馈，待确认 |
| **Seaman_bot** | 未明确反馈，待确认 |
| **X7** | 未明确反馈，待确认 |

## 根本方案

**目标**：OpenClaw 飞书配置切到 `tenant_access_token` 模式

- **现状**：`feishu_fetch_doc` 底层使用 user_access_token，权限随触发者漂移
- **理想状态**：bot 应用统一使用 tenant_access_token，不依赖任何用户授权
- **阻塞**：OpenClaw schema 中 `channels.feishu.tools` 下无 `authMode` 或 `tokenType` 切换选项，需要 OpenClaw 开发者支持

## 临时 Workaround

在 tenant_access_token 模式正式支持前：
- 猫先森通过 curl 直接获取 tenant_access_token 读取文档（已验证有效）
- `feishu_fetch_doc` 工具在密钥有效期间可用（expire ~98 分钟，自动刷新待验证）

## 相关文档

- 概念演化档案 v1.2：`https://yio5us4oqe.feishu.cn/wiki/A5KPws2f1i242wkxemic6yHxneh`
- 里程碑对齐文档：`https://yio5us4oqe.feishu.cn/wiki/XEs8wjmtIiEka9kPTUXcZ3r1nke`
