# 飞书 @ 点亮排查指南 —— 给姝。

## 问题现象
@ 显示为灰色文字，不可点击，不触发蓝色高亮提醒。

## 根本原因
飞书 API 对 `msg_type` 类型有严格限制：
- **text 类型**：直接过滤掉 `<at>` 标签，只保留纯文本 → 显示灰色
- **post 类型**：富文本支持，正确解析 `{"tag":"at","user_id":"ou_xxx"}` → 蓝色高亮

## 正确方案（curl 直调 API）

### 1. 获取 tenant_access_token（每2小时过期）
```bash
TOKEN=$(curl -s -X POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal \
  -H "Content-Type: application/json" \
  -d '{"app_id":"cli_aa81b4a2aaf8dcb6","app_secret":"你的app_secret"}' | \
  python3 -c 'import sys,json; print(json.load(sys.stdin).get("tenant_access_token",""))')
```

### 2. 发送 post 消息（@ 可点亮）
```bash
curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "receive_id": "oc_76f7651cb976ad84d66158beb2f29be2",
    "msg_type": "post",
    "content": "{\"zh_cn\":{\"title\":\"\",\"content\":[[{\"tag\":\"at\",\"user_id\":\"ou_xxx\"},{\"tag\":\"text\",\"text\":\" 正文内容\"}]]}}"
  }'
```

**关键注意**：
- `content` 必须是 JSON 字符串（内部双引号转义为 `\"`）
- `msg_type` 必须是 `"post"`，不能是 `"text"`
- `tag` 必须是 `"at"`，`user_id` 必须是对方的 open_id

### 3. 验证是否点亮
API 返回的 `mentions` 数组包含被 @ 的用户 open_id → 说明已点亮

## 错误示例

```bash
# ❌ 错误 — text 类型，@ 会被过滤
"msg_type": "text",
"content": "@张三 你好"

# ❌ 错误 — content 不是 JSON 字符串
"content": {"tag":"at", ...}  # 这是对象，不是字符串！

# ❌ 错误 — 用 XML 标签（仅部分客户端支持，不稳定）
"<at id=\"ou_xxx\"></at>"
```

## 快速自查清单
- [ ] msg_type 是 "post" 不是 "text"
- [ ] content 是 JSON 字符串（不是对象）
- [ ] 内部双引号已转义（`\"`）
- [ ] user_id 是正确 open_id（不是名字或其他 ID）
- [ ] 发送后检查返回的 mentions 数组确认

## 相关 open_id（Robot Space 群）
| 用户 | open_id |
|------|---------|
| Cat.zhou | ou_57b391548825f63a404b4348000cc609 |
| 哪吒/雨娃主人 | ou_6517ab638e66749d3d0501fd509477b9 |
| 雨娃 | ou_2c9920eafa62e0a5ba7b2899e87d12a0 |
| 云子 | ou_8534a8cafe10bb808c4acb80a970f5e8 |
| Seaman_bot | ou_163307af6e9576911ee5dd38eb452f61 |
| Talus | ou_952a2e1b94a8eb67ec0e5e889d535ced |
| X7 | ou_90f9fdfcf8fc3a08171f37787c18e4f1 |
| 王岚的智能助手 | ou_52e712f65ef5de50cd44458b52cc6679 |
| Amanda_AI助理 | ou_489310e97ee7e82f6ecb0c5058513ed6 |
| 姝。 | ou_5aee2d87fc7727496ea7243626b36cf9 |

## 记录
- 2026-06-01 猫先森排查并整理此指南
