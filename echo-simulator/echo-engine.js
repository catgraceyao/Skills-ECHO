// ═══════════════════════════════════════════════════════════
// 模块 6: 规则市场引擎 RuleMarketEngine
// ═══════════════════════════════════════════════════════════

/**
 * 规则市场引擎 — 管理规则模板、应用、推荐
 * 模板 = 配置预设 + 分润规则 + 档位约束
 */
class RuleMarketEngine {
  constructor() {
    /** @type {Map<string, Object>} 规则模板库：templateId → template */
    this.templates = new Map();
    /** @type {Map<string, string[]>} 资产类型 → 推荐模板ID列表 */
    this.recommendations = new Map();
    /** 版本计数器 */
    this.versionCounter = 0;
  }

  /**
   * 创建规则模板
   * @param {Object} config — 档位配置 { permissions: { use, spread, remix, profit } }
   * @param {Object} rules — 分润规则 { eventRates, split, parentShare }
   * @param {number} price — 模板价格（使用模板需支付）
   * @param {Object} meta — 元信息 { name, description, tags, assetType }
   * @returns {string} templateId
   */
  createTemplate(config, rules, price, meta = {}) {
    this.versionCounter++;
    const template = {
      id: `tpl-${this.versionCounter}`,
      config: deepClone(config),
      rules: deepClone(rules),
      price: price,
      meta: { ...meta, createdAt: now() },
      version: this.versionCounter,
    };

    // 验证模板逻辑自洽性
    const validation = this.validateTemplate(template);
    if (!validation.valid) {
      throw new Error(`模板创建失败: ${validation.reason}`);
    }

    this.templates.set(template.id, template);

    // 更新推荐索引
    if (meta.assetType) {
      if (!this.recommendations.has(meta.assetType)) {
        this.recommendations.set(meta.assetType, []);
      }
      this.recommendations.get(meta.assetType).push(template.id);
    }

    return template.id;
  }

  /**
   * 应用模板到资产
   * 遵循元规则：配置即承诺、衍生即继承
   * @param {Object} asset — 资产对象
   * @param {string} templateId
   * @returns {{asset: Object, applied: boolean, changes: string[]}}
   */
  applyTemplate(asset, templateId) {
    const tpl = this.templates.get(templateId);
    if (!tpl) {
      return { asset: deepClone(asset), applied: false, changes: ['模板不存在'] };
    }

    const newAsset = deepClone(asset);
    const changes = [];

    // 应用档位配置
    if (tpl.config.permissions) {
      newAsset.permissions = { ...newAsset.permissions, ...tpl.config.permissions };
      changes.push('应用档位配置');
    }

    // 应用分润规则
    if (tpl.rules) {
      newAsset.revenueRules = { ...newAsset.revenueRules, templateId, ...tpl.rules };
      changes.push('应用分润规则');
    }

    // 记录应用历史（版本即历史）
    if (!newAsset.templateHistory) newAsset.templateHistory = [];
    newAsset.templateHistory.push({
      templateId,
      version: tpl.version,
      appliedAt: now(),
    });

    return { asset: newAsset, applied: true, changes };
  }

  /**
   * 验证模板逻辑自洽性
   * @param {Object} template
   * @returns {{valid: boolean, reason: string|null}}
   */
  validateTemplate(template) {
    const { config, rules } = template;

    // 1. 检查档位组合合法性
    if (config.permissions) {
      for (const [power, mask] of Object.entries(config.permissions)) {
        if (!isGearComboValid(mask)) {
          return { valid: false, reason: `${power} 档位组合非法` };
        }
      }
    }

    // 2. 检查分润规则合理性
    if (rules.eventRates) {
      for (const [event, rate] of Object.entries(rules.eventRates)) {
        if (rate < 0 || rate > 1) {
          return { valid: false, reason: `${event} 分润率 ${rate} 超出 [0,1]` };
        }
      }
    }

    // 3. 检查是否至少有一个开放权力（否则无意义）
    const allNone = Object.values(config.permissions || {}).every(m => m === GEAR.NONE);
    if (allNone) {
      return { valid: false, reason: '模板无任何开放权力' };
    }

    // 4. 检查益权是否与分润规则一致
    if (config.permissions && config.permissions.profit === GEAR.NONE && rules.eventRates) {
      const hasProfit = Object.values(rules.eventRates).some(r => r > 0);
      if (hasProfit) {
        return { valid: false, reason: '益权禁止但配置了分润规则' };
      }
    }

    return { valid: true, reason: null };
  }

  /**
   * 获取推荐模板
   * @param {string} assetType — 资产类型（如 'music', 'image', 'code'）
   * @returns {Array<Object>}
   */
  getRecommendedTemplates(assetType) {
    const ids = this.recommendations.get(assetType) || [];
    return ids.map(id => this.templates.get(id)).filter(Boolean);
  }

  /**
   * 获取模板详情
   * @param {string} templateId
   * @returns {Object|null}
   */
  getTemplate(templateId) {
    const tpl = this.templates.get(templateId);
    return tpl ? deepClone(tpl) : null;
  }

  /**
   * 列出所有模板
   * @returns {Array<Object>}
   */
  listTemplates() {
    return Array.from(this.templates.values()).map(deepClone);
  }
}

// ── RuleMarketEngine 使用示例 ──
const rmDemo = () => {
  const engine = new RuleMarketEngine();

  // 创建音乐标准模板
  const tplId = engine.createTemplate(
    {
      permissions: {
        use: GEAR.SELF | GEAR.TRUST | GEAR.DEAL,
        spread: GEAR.TRUST | GEAR.DEAL,
        remix: GEAR.DEAL,
        profit: GEAR.DEAL | GEAR.PUBLIC,
      },
    },
    {
      eventRates: { purchase: 0.7, remix: 0.5, view: 0.0 },
      parentShare: 0.1,
    },
    0,
    { name: '音乐标准协议', description: '适合独立音乐人的标准授权', tags: ['music', 'standard'], assetType: 'music' }
  );

  // 应用模板
  const asset = { id: 'song-demo', creatorId: 'artist-demo', permissions: {} };
  const applied = engine.applyTemplate(asset, tplId);
  assert(applied.applied === true, '模板应成功应用');
  assert(applied.asset.permissions.use === (GEAR.SELF | GEAR.TRUST | GEAR.DEAL), 'use 权限应正确');
  assert(applied.asset.templateHistory.length === 1, '应有模板应用历史');

  // 验证模板
  const valid = engine.validateTemplate(engine.getTemplate(tplId));
  assert(valid.valid === true, '模板应验证通过');

  // 推荐
  const recs = engine.getRecommendedTemplates('music');
  assert(recs.length === 1, '应有1个音乐推荐模板');

  // 非法模板应被拒绝
  let threw = false;
  try {
    engine.createTemplate(
      { permissions: { use: GEAR.NONE, spread: GEAR.NONE, remix: GEAR.NONE, profit: GEAR.NONE } },
      {},
      0
    );
  } catch (e) {
    threw = true;
  }
  assert(threw, '无开放权力的模板应被拒绝');

  console.log('RuleMarketEngine 示例通过 ✓');
};

// ═══════════════════════════════════════════════════════════
// 综合单元测试执行器
// ═══════════════════════════════════════════════════════════

/**
 * 运行所有内置单元测试
 * 测试失败时会抛出错误并终止
 */
function runAllTests() {
  console.log('═══════════════════════════════════════════');
  console.log('  ECHO 核心引擎 — 单元测试套件');
  console.log('═══════════════════════════════════════════\n');

  const tests = [
    { name: 'PermissionEngine', fn: peDemo },
    { name: 'RevenueEngine', fn: reDemo },
    { name: 'GraphEngine', fn: geDemo },
    { name: 'ShiEngine', fn: shiDemo },
    { name: 'ShiTakeoverEngine', fn: stoDemo },
    { name: 'RuleMarketEngine', fn: rmDemo },
  ];

  let passed = 0;
  let failed = 0;

  for (const t of tests) {
    try {
      t.fn();
      passed++;
      console.log(`  ✅ ${t.name} 通过`);
    } catch (e) {
      failed++;
      console.error(`  ❌ ${t.name} 失败: ${e.message}`);
    }
  }

  console.log('\n───────────────────────────────────────────');
  console.log(`  总计: ${tests.length} | 通过: ${passed} | 失败: ${failed}`);
  console.log('───────────────────────────────────────────');

  if (failed > 0) {
    throw new Error(`${failed} 个测试失败`);
  }
  return true;
}

// ═══════════════════════════════════════════════════════════
// 模块导出（Node.js / ESM 兼容）
// ═══════════════════════════════════════════════════════════

const ECHO_ENGINE = {
  // 常量
  GEAR,
  GEAR_BANNED_COMBOS,
  POWER,
  ACTION_MAP,
  LIFE_STAGES,
  META_RULES,
  SHI_WEIGHTS,

  // 工具
  isGearComboValid,
  parseGearMask,
  deepClone,
  genId,
  now,
  fmtDate,
  normalize,

  // 引擎
  PermissionEngine,
  RevenueEngine,
  ShiEngine,
  ShiTakeoverEngine,
  GraphEngine,
  RuleMarketEngine,

  // 测试
  runAllTests,
};

// Node.js CommonJS 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ECHO_ENGINE;
}

// 浏览器 / ESM 全局
if (typeof window !== 'undefined') {
  window.ECHO_ENGINE = ECHO_ENGINE;
}

// ═══════════════════════════════════════════════════════════
// 当直接运行此文件时，自动执行测试
// ═══════════════════════════════════════════════════════════
if (typeof require !== 'undefined' && require.main === module) {
  runAllTests();
}
