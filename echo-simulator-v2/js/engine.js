(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined'
    ? module.exports = factory()
    : typeof define === 'function' && define.amd
    ? define(factory)
    : (global = typeof globalThis !== 'undefined' ? globalThis : global || self, global.ECHOEngine = factory());
})(this, function () {
  'use strict';

  // ========================
  // 简单断言工具（内联单元测试用）
  // ========================
  const assert = {
    equal(actual, expected, msg) {
      if (actual !== expected) {
        throw new Error(`${msg || 'Assert.equal failed'}: expected ${expected}, got ${actual}`);
      }
    },
    deepEqual(actual, expected, msg) {
      const a = JSON.stringify(actual);
      const e = JSON.stringify(expected);
      if (a !== e) {
        throw new Error(`${msg || 'Assert.deepEqual failed'}: expected ${e}, got ${a}`);
      }
    },
    ok(value, msg) {
      if (!value) throw new Error(msg || 'Assert.ok failed');
    },
    approx(actual, expected, epsilon = 1e-6, msg) {
      if (Math.abs(actual - expected) > epsilon) {
        throw new Error(`${msg || 'Assert.approx failed'}: expected ~${expected}, got ${actual}`);
      }
    }
  };

  // ========================
  // 四权档位常量
  // ========================
  const Gear = { NONE: 0, SELF: 1, TRUST: 2, CONTRACT: 3, LAW: 4, PUBLIC: 5 };
  const GearNames = { 0:'禁',1:'己',2:'亲',3:'约',4:'法',5:'公' };
  const ActionMap = { view:'use', share:'expand', remix:'derive', purchase:'benefit' };

  // ========================
  // 辅助函数
  // ========================
  function nowMs() { return Date.now(); }

  /**
   * 检查档位组合是否被禁止
   * @param {number} gear
   * @returns {boolean}
   */
  function isForbiddenGear(gear) {
    const gears = [];
    for (let i = 0; i <= 5; i++) if (gear & (1 << i)) gears.push(i);
    // 禁止组合：{0,任何}、{5,1/2}、{0,3/4}
    if (gears.includes(0) && gears.length > 1) return true;
    if (gears.includes(5) && (gears.includes(1) || gears.includes(2))) return true;
    if (gears.includes(0) && (gears.includes(3) || gears.includes(4))) return true;
    return false;
  }

  /**
   * 检查某档位是否包含指定档位
   * @param {number} gear - 档位组合（位掩码）
   * @param {number} target - 目标档位
   * @returns {boolean}
   */
  function gearIncludes(gear, target) {
    if (target === 0) return (gear & 1) !== 0; // 禁档特判
    return (gear & (1 << target)) !== 0;
  }

  /**
   * 获取档位组合的最高档位
   * @param {number} gear
   * @returns {number}
   */
  function highestGear(gear) {
    for (let i = 5; i >= 0; i--) if (gear & (1 << i)) return i;
    return 0;
  }

  /**
   * 用户是否在资产的信任圈
   * @param {object} user
   * @param {object} asset
   * @returns {boolean}
   */
  function inTrustNetwork(user, asset) {
    if (!asset.creatorId || !user.trustNetwork) return false;
    const creatorTrust = user.trustNetwork || [];
    return creatorTrust.includes(asset.creatorId);
  }

  /**
   * 检查契约关系
   * @param {object} user
   * @param {object} asset
   * @param {string} action
   * @returns {boolean}
   */
  function hasContract(user, asset, action) {
    // 契约检查：用户与资产是否建立了付费/订阅关系
    // 简化实现：检查用户是否在asset的contractUsers列表中
    const contracts = asset.contractUsers || [];
    return contracts.includes(user.id);
  }

  // ========================
  // 1. PermissionEngine — 四权验证引擎
  // ========================

  /**
   * 四权验证引擎
   * 遵循档位检查顺序：己→亲→约→法，层层递进
   * 支持档位组合验证与禁止组合检测
   *
   * @example
   * const pe = new PermissionEngine();
   * const result = pe.checkPermission(alice, songAsset, 'view', { platformId: 'echo' });
   * console.log(result); // { allowed: true, reason: '亲档：信任圈', fee: 0 }
   */
  class PermissionEngine {
    constructor() {
      this.stats = { checks: 0, allowed: 0, denied: 0 };
    }

    /**
     * 检查用户是否有权对资产执行某操作
     * @param {object} user - 用户对象 { id, name, role, trustNetwork }
     * @param {object} asset - 资产对象 { permissions: {use,expand,derive,benefit}, creatorId, contractUsers }
     * @param {string} action - 动作类型: view|share|remix|purchase
     * @param {object} context - 上下文 { platformId, timestamp, isCreator }
     * @returns {{allowed: boolean, reason: string, fee: number}}
     */
    checkPermission(user, asset, action, context = {}) {
      this.stats.checks++;

      const right = ActionMap[action];
      if (!right) {
        this.stats.denied++;
        return { allowed: false, reason: '未知动作类型', fee: 0 };
      }

      const gear = asset.permissions?.[right] ?? 0;

      // 禁止组合检测
      if (isForbiddenGear(gear)) {
        this.stats.denied++;
        return { allowed: false, reason: '档位组合非法（禁止组合）', fee: 0 };
      }

      // 己档检查
      if (gearIncludes(gear, Gear.SELF)) {
        const isOwner = context.isCreator || user.id === asset.creatorId;
        if (isOwner) {
          this.stats.allowed++;
          return { allowed: true, reason: '己档：所有者权限', fee: 0 };
        }
      }

      // 亲档检查（信任圈）
      if (gearIncludes(gear, Gear.TRUST)) {
        if (inTrustNetwork(user, asset)) {
          this.stats.allowed++;
          return { allowed: true, reason: '亲档：信任圈', fee: 0 };
        }
      }

      // 约档检查（契约/付费）
      if (gearIncludes(gear, Gear.CONTRACT)) {
        if (hasContract(user, asset, action)) {
          const fee = this._getFee(asset, action);
          this.stats.allowed++;
          return { allowed: true, reason: '约档：契约关系', fee };
        }
        // 约档需要付费但未付费 → 可提示付费
        if (action === 'view' || action === 'remix') {
          const fee = this._getFee(asset, action);
          return { allowed: false, reason: '约档：需要付费或订阅', fee };
        }
      }

      // 法档检查（社区规则/法权）
      if (gearIncludes(gear, Gear.LAW)) {
        // 法档通常由社区共识决定，简化：通过平台验证即允许
        if (context.platformId) {
          this.stats.allowed++;
          return { allowed: true, reason: '法档：社区自治规则', fee: 0 };
        }
      }

      // 公档（公共品，无条件开放）
      if (gearIncludes(gear, Gear.PUBLIC)) {
        this.stats.allowed++;
        return { allowed: true, reason: '公档：公共品', fee: 0 };
      }

      // 禁档（无任何权限）
      if (gearIncludes(gear, Gear.NONE)) {
        this.stats.denied++;
        return { allowed: false, reason: '禁档：禁止访问', fee: 0 };
      }

      this.stats.denied++;
      return { allowed: false, reason: '未满足任何权限档位', fee: 0 };
    }

    /**
     * 获取某操作的费率
     * @private
     */
    _getFee(asset, action) {
      const feeMap = { view: 1, share: 0, remix: 5, purchase: 10 };
      const templateFee = asset.templateRules?.[action + '_fee'];
      return templateFee ?? feeMap[action] ?? 0;
    }

    /**
     * 批量验证
     * @param {object[]} checks - { user, asset, action, context }[]
     * @returns {{allowed: boolean, reason: string, fee: number}[]}
     */
    batchCheck(checks) {
      return checks.map(c => this.checkPermission(c.user, c.asset, c.action, c.context));
    }

    /**
     * 获取引擎统计
     * @returns {{checks: number, allowed: number, denied: number}}
     */
    getStats() {
      return { ...this.stats };
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== PermissionEngine Tests ===');
      const engine = new PermissionEngine();

      const alice = { id: 'alice', name: 'Alice', role: 'creator', trustNetwork: ['alice', 'bob'] };
      const bob = { id: 'bob', name: 'Bob', role: 'creator', trustNetwork: ['bob'] };
      const mallory = { id: 'mallory', name: 'Mallory', role: 'platform', trustNetwork: [] };

      // 资产1：己档（仅自己）
      const privateAsset = {
        id: 'a1', creatorId: 'alice',
        permissions: { use: 0b000010, expand: 0b000010, derive: 0b000010, benefit: 0b000010 },
        contractUsers: []
      };
      // 资产2：己+亲
      const friendAsset = {
        id: 'a2', creatorId: 'alice',
        permissions: { use: 0b000110, expand: 0b000110, derive: 0b000010, benefit: 0b000010 },
        contractUsers: []
      };
      // 资产3：约档
      const contractAsset = {
        id: 'a3', creatorId: 'alice',
        permissions: { use: 0b001000, expand: 0b001000, derive: 0b001000, benefit: 0b001000 },
        contractUsers: ['bob']
      };
      // 资产4：公档
      const publicAsset = {
        id: 'a4', creatorId: 'alice',
        permissions: { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 },
        contractUsers: []
      };
      // 资产5：禁档+任何（禁止组合）
      const badAsset = {
        id: 'a5', creatorId: 'alice',
        permissions: { use: 0b000011, expand: 0b000011, derive: 0b000001, benefit: 0b000001 },
        contractUsers: []
      };

      // 测试：己档
      let r = engine.checkPermission(alice, privateAsset, 'view');
      assert.ok(r.allowed, 'Owner should have self-gear access');
      assert.equal(r.reason, '己档：所有者权限', 'Self gear reason');

      r = engine.checkPermission(bob, privateAsset, 'view');
      assert.ok(!r.allowed, 'Non-owner denied self-gear asset');

      // 测试：亲档
      r = engine.checkPermission(bob, friendAsset, 'view');
      assert.ok(r.allowed, 'Trust network member allowed');
      assert.equal(r.reason, '亲档：信任圈', 'Trust gear reason');

      r = engine.checkPermission(mallory, friendAsset, 'view');
      assert.ok(!r.allowed, 'Non-trust member denied');

      // 测试：约档
      r = engine.checkPermission(bob, contractAsset, 'view');
      assert.ok(r.allowed, 'Contract user allowed');
      r = engine.checkPermission(alice, contractAsset, 'view');
      assert.ok(!r.allowed, 'Non-contract user denied contract asset');

      // 测试：公档
      r = engine.checkPermission(mallory, publicAsset, 'view');
      assert.ok(r.allowed, 'Public gear allows anyone');

      // 测试：禁止组合
      r = engine.checkPermission(alice, badAsset, 'view');
      assert.ok(!r.allowed, 'Forbidden gear combo denied');

      // 测试：法档
      const lawAsset = {
        id: 'a6', creatorId: 'alice',
        permissions: { use: 0b010000, expand: 0b010000, derive: 0b010000, benefit: 0b010000 },
        contractUsers: []
      };
      r = engine.checkPermission(mallory, lawAsset, 'view', { platformId: 'echo' });
      assert.ok(r.allowed, 'Law gear with platform context allowed');

      // 测试统计
      const stats = engine.getStats();
      assert.ok(stats.checks > 0, 'Stats tracked');

      console.log('✅ PermissionEngine all tests passed');
    }
  }

  // ========================
  // 2. RevenueEngine — 分润引擎
  // ========================

  /**
   * 分润引擎
   * 多级递归分配（引用链上溯），每层衰减系数0.5
   * 支持规则模板中的付费规则
   *
   * @example
   * const re = new RevenueEngine();
   * const dist = re.calculateDistribution(asset, 'purchase', 100);
   * console.log(dist); // [{userId, amount, level, reason}]
   */
  class RevenueEngine {
    constructor(graphEngine) {
      this.graph = graphEngine;
      this.defaultDecay = 0.5;
      this.eventRatios = { purchase: 1.0, remix: 0.5, view: 0.1, share: 0.05 };
    }

    /**
     * 计算单次事件的收益分配
     * @param {object} asset - 资产对象
     * @param {string} eventType - 事件类型: purchase/remix/view/share
     * @param {number} amount - 总金额
     * @param {object} [options] - 选项 { decay, maxDepth }
     * @returns {{userId: string, amount: number, level: number, reason: string}[]}
     */
    calculateDistribution(asset, eventType, amount, options = {}) {
      const decay = options.decay ?? this.defaultDecay;
      const maxDepth = options.maxDepth ?? 5;
      const ratio = this.eventRatios[eventType] ?? 0.1;
      const effectiveAmount = amount * ratio;

      const distributions = [];
      const visited = new Set();

      // 当前资产创作者获得当前层级份额
      const distribute = (currentAsset, level, remainingAmount) => {
        if (level >= maxDepth || remainingAmount < 0.01) return;
        if (visited.has(currentAsset.id + ':' + level)) return;
        visited.add(currentAsset.id + ':' + level);

        const share = remainingAmount * (1 - decay);
        const upstream = remainingAmount * decay;

        if (share > 0.01 && currentAsset.creatorId) {
          distributions.push({
            userId: currentAsset.creatorId,
            amount: Math.round(share * 100) / 100,
            level,
            reason: `${eventType}收益，层级${level}，资产${currentAsset.id}`
          });
        }

        // 上溯引用链
        const chain = this.graph ? this.graph.getVerificationChain(currentAsset.id) : [];
        if (chain.length > 0 && upstream > 0.01) {
          // 均分给上游引用资产
          const perUpstream = upstream / chain.length;
          for (const parent of chain) {
            distribute(parent, level + 1, perUpstream);
          }
        }
      };

      distribute(asset, 0, effectiveAmount);

      // 汇总同一用户的收益
      const merged = {};
      for (const d of distributions) {
        if (!merged[d.userId]) {
          merged[d.userId] = { userId: d.userId, amount: 0, levels: [], reasons: [] };
        }
        merged[d.userId].amount += d.amount;
        merged[d.userId].levels.push(d.level);
        merged[d.userId].reasons.push(d.reason);
      }

      return Object.values(merged).map(m => ({
        userId: m.userId,
        amount: Math.round(m.amount * 100) / 100,
        level: Math.min(...m.levels),
        reason: m.reasons[0] + (m.reasons.length > 1 ? ` 等${m.reasons.length}笔` : '')
      }));
    }

    /**
     * 快速计算（仅当前层级，不上溯）
     * @param {object} asset
     * @param {string} eventType
     * @param {number} amount
     * @returns {{userId: string, amount: number, level: number, reason: string}[]}
     */
    calculateSimple(asset, eventType, amount) {
      const ratio = this.eventRatios[eventType] ?? 0.1;
      const effective = amount * ratio;
      if (!asset.creatorId) return [];
      return [{
        userId: asset.creatorId,
        amount: Math.round(effective * 100) / 100,
        level: 0,
        reason: `${eventType}收益（单层）`
      }];
    }

    /**
     * 设置事件类型分润比例
     * @param {object} ratios - { purchase: 1.0, ... }
     */
    setEventRatios(ratios) {
      this.eventRatios = { ...this.eventRatios, ...ratios };
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== RevenueEngine Tests ===');
      const graph = new GraphEngine();
      const engine = new RevenueEngine(graph);

      const parent = { id: 'parent', creatorId: 'alice' };
      const child = { id: 'child', creatorId: 'bob', parentAsset: 'parent' };
      const grandchild = { id: 'grandchild', creatorId: 'charlie', parentAsset: 'child' };

      // 模拟引用链
      graph.addEvent({ id:'e1', type:'reference', subjectAsset:'child', objectAsset:'parent', timestamp:1000, userId:'bob' });
      graph.addEvent({ id:'e2', type:'reference', subjectAsset:'grandchild', objectAsset:'child', timestamp:2000, userId:'charlie' });

      // 测试单层
      let dist = engine.calculateSimple(child, 'purchase', 100);
      assert.equal(dist.length, 1, 'Simple gives 1 entry');
      assert.equal(dist[0].userId, 'bob', 'Simple goes to child creator');
      assert.equal(dist[0].amount, 100, 'Simple amount = 100');

      // 测试多级分配
      dist = engine.calculateDistribution(grandchild, 'purchase', 100);
      const charlieShare = dist.find(d => d.userId === 'charlie');
      const bobShare = dist.find(d => d.userId === 'bob');
      const aliceShare = dist.find(d => d.userId === 'alice');

      assert.ok(charlieShare, 'Charlie gets share');
      assert.ok(bobShare, 'Bob gets upstream share');
      assert.ok(aliceShare, 'Alice gets top-level share');
      assert.ok(charlieShare.amount > bobShare.amount, 'Level 0 > level 1');
      assert.ok(bobShare.amount > aliceShare.amount, 'Level 1 > level 2');

      // 测试不同事件类型
      engine.setEventRatios({ remix: 0.3 });
      dist = engine.calculateDistribution(child, 'remix', 100);
      const remixShare = dist.find(d => d.userId === 'bob');
      assert.approx(remixShare.amount, 15, 0.1, 'Remix ratio applied'); // 100*0.3*(1-0.5)=15

      console.log('✅ RevenueEngine all tests passed');
    }
  }

  // ========================
  // 3. ShiEngine — 势位计算引擎
  // ========================

  /**
   * 势位计算引擎
   * P = 0.4×时间密度T + 0.4×中心性S + 0.2×语义跨越C
   * 5生命阶段：潜藏(0)→显现(1)→生长(2)→大成(3)→转化(4)
   *
   * @example
   * const se = new ShiEngine();
   * const pos = se.calculatePosition('asset_001', events, graph);
   * const stage = se.getLifeStage(pos.score); // 1=显现
   */
  class ShiEngine {
    constructor() {
      this.weights = { time: 0.4, centrality: 0.4, semantic: 0.2 };
      this.timeWindows = { short: 7, medium: 30, long: 90 };
    }

    /**
     * 计算资产势位分数
     * @param {string} assetId
     * @param {object[]} events - 验证事件数组
     * @param {GraphEngine} graph - 验证图引擎
     * @returns {{score: number, stage: number, dimensions: {time: number, centrality: number, semantic: number}}}
     */
    calculatePosition(assetId, events, graph) {
      const T = this.calculateTimeDensity(assetId, events);
      const S = this.calculateCentrality(assetId, graph);
      const C = this.calculateSemanticCross(assetId, events);
      const score = Math.min(100, Math.max(0,
        this.weights.time * T +
        this.weights.centrality * S +
        this.weights.semantic * C
      ));
      return {
        score: Math.round(score * 10) / 10,
        stage: this.getLifeStage(score),
        dimensions: { time: Math.round(T * 10) / 10, centrality: Math.round(S * 10) / 10, semantic: Math.round(C * 10) / 10 }
      };
    }

    /**
     * 计算中心性 S（度中心性+介数中心性+PageRank综合）
     * 简化实现：归一化到0-100
     * @param {string} assetId
     * @param {GraphEngine} graph
     * @returns {number}
     */
    calculateCentrality(assetId, graph) {
      if (!graph) return 0;
      const neighbors = graph.getNeighbors(assetId);
      const degree = neighbors.length;

      // PageRank分数
      const pr = graph.calculatePageRank();
      const prScore = (pr[assetId] || 0) * 100;

      // 度中心性：假设最大度数为20，归一化
      const degreeScore = Math.min(100, degree / 20 * 100);

      // 简化的介数：引用链长度
      const chain = graph.getVerificationChain(assetId);
      const betweenness = Math.min(100, chain.length / 10 * 100);

      // 综合：度30% + PageRank40% + 介数30%
      return degreeScore * 0.3 + prScore * 0.4 + betweenness * 0.3;
    }

    /**
     * 计算时间密度 T
     * 7d/30d/90d窗口内事件密度
     * @param {string} assetId
     * @param {object[]} events
     * @returns {number} 0-100
     */
    calculateTimeDensity(assetId, events) {
      const now = nowMs();
      const assetEvents = events.filter(e => e.subjectAsset === assetId || e.objectAsset === assetId);
      if (assetEvents.length === 0) return 0;

      const countIn = (days) => {
        const ms = days * 86400000;
        return assetEvents.filter(e => (now - e.timestamp) < ms).length;
      };

      const c7 = countIn(7);
      const c30 = countIn(30);
      const c90 = countIn(90);

      // 加权：短期0.5 + 中期0.3 + 长期0.2，假设最大密度为50次
      const density = Math.min(1, (c7 * 0.5 + c30 * 0.3 + c90 * 0.2) / 20);
      return density * 100;
    }

    /**
     * 计算语义跨越 C
     * 跨领域引用比例
     * @param {string} assetId
     * @param {object[]} events
     * @returns {number} 0-100
     */
    calculateSemanticCross(assetId, events) {
      const related = events.filter(e => e.subjectAsset === assetId || e.objectAsset === assetId);
      if (related.length === 0) return 0;

      // 统计不同类型的引用
      const types = {};
      for (const e of related) types[e.type] = (types[e.type] || 0) + 1;
      const uniqueTypes = Object.keys(types).length;
      // 假设最多5种类型为满分
      return Math.min(100, uniqueTypes / 5 * 100);
    }

    /**
     * 获取生命阶段
     * @param {number} position - 势位分数 0-100
     * @returns {number} 0=潜藏,1=显现,2=生长,3=大成,4=转化
     */
    getLifeStage(position) {
      if (position < 20) return 0;      // 潜藏
      if (position < 40) return 1;      // 显现
      if (position < 60) return 2;      // 生长
      if (position < 80) return 3;      // 大成
      return 4;                         // 转化
    }

    /**
     * 获取生命阶段名称
     * @param {number} stage
     * @returns {string}
     */
    getStageName(stage) {
      return ['潜藏','显现','生长','大成','转化'][stage] || '未知';
    }

    /**
     * 获取阶段建议
     * @param {number} stage
     * @returns {string}
     */
    getStageSuggestion(stage) {
      const suggestions = [
        '资产尚无验证事件，建议保持当前配置',
        '开始被引用，建议适度开放用权档位',
        '中度连接，势图接管将自动开放（每次最多升1档）',
        '高度连接，锁定最低档，禁止收紧配置',
        '周期尾声，建议完全开放或冻结资产'
      ];
      return suggestions[stage] || '';
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== ShiEngine Tests ===');
      const engine = new ShiEngine();

      // 测试生命阶段映射
      assert.equal(engine.getLifeStage(10), 0, 'Stage 0: latent');
      assert.equal(engine.getLifeStage(25), 1, 'Stage 1: manifest');
      assert.equal(engine.getLifeStage(45), 2, 'Stage 2: growth');
      assert.equal(engine.getLifeStage(65), 3, 'Stage 3: mature');
      assert.equal(engine.getLifeStage(85), 4, 'Stage 4: transform');

      assert.equal(engine.getStageName(2), '生长', 'Stage name');

      // 测试时间密度（模拟数据）
      const now = nowMs();
      const events = [
        { id:'e1', type:'reference', subjectAsset:'a1', objectAsset:'a2', timestamp: now - 86400000 * 2, userId:'u1' },
        { id:'e2', type:'remix', subjectAsset:'a1', objectAsset:'a3', timestamp: now - 86400000 * 10, userId:'u2' },
        { id:'e3', type:'integrate', subjectAsset:'a1', objectAsset:'a4', timestamp: now - 86400000 * 50, userId:'u3' },
      ];
      const T = engine.calculateTimeDensity('a1', events);
      assert.ok(T > 0, 'Time density positive');
      assert.ok(T <= 100, 'Time density bounded');

      // 测试语义跨越
      const C = engine.calculateSemanticCross('a1', events);
      assert.equal(C, 60, 'Semantic cross: 3 types / 5 * 100 = 60');

      // 测试完整势位计算
      const graph = new GraphEngine();
      graph.addEvent(events[0]);
      graph.addEvent(events[1]);
      graph.addEvent(events[2]);
      const pos = engine.calculatePosition('a1', events, graph);
      assert.ok(pos.score >= 0 && pos.score <= 100, 'Score in range');
      assert.ok(pos.stage >= 0 && pos.stage <= 4, 'Stage in range');
      assert.ok(pos.dimensions.time >= 0, 'Time dimension');
      assert.ok(pos.dimensions.centrality >= 0, 'Centrality dimension');
      assert.ok(pos.dimensions.semantic >= 0, 'Semantic dimension');

      console.log('✅ ShiEngine all tests passed');
    }
  }

  // ========================
  // 4. GraphEngine — 验证图引擎
  // ========================

  /**
   * 验证图引擎
   * 管理资产节点与验证事件边，支持引用链追溯与PageRank计算
   *
   * @example
   * const ge = new GraphEngine();
   * ge.addEvent({ type:'reference', subjectAsset:'a2', objectAsset:'a1', ... });
   * const chain = ge.getVerificationChain('a2'); // [a1]
   * const pr = ge.calculatePageRank();
   */
  class GraphEngine {
    constructor() {
      this.nodes = new Map(); // assetId -> { id, edges: [] }
      this.edges = new Map(); // eventId -> event
      this.edgeList = [];     // 有序边列表
    }

    /**
     * 添加验证事件，自动更新图结构
     * @param {object} event - { id, type, subjectAsset, objectAsset, timestamp, userId, platformId, semanticDepth }
     * @returns {boolean}
     */
    addEvent(event) {
      if (!event.id || !event.subjectAsset || !event.objectAsset) return false;

      // 确保节点存在
      if (!this.nodes.has(event.subjectAsset)) {
        this.nodes.set(event.subjectAsset, { id: event.subjectAsset, edges: [] });
      }
      if (!this.nodes.has(event.objectAsset)) {
        this.nodes.set(event.objectAsset, { id: event.objectAsset, edges: [] });
      }

      // 时间衰减权重
      const ageDays = (nowMs() - event.timestamp) / 86400000;
      const timeDecay = Math.exp(-0.1 * Math.max(0, ageDays));
      const weight = (event.semanticDepth || 0.5) * timeDecay;

      const edge = { ...event, weight, ageDays };
      this.edges.set(event.id, edge);
      this.edgeList.push(edge);

      // 添加有向边：subjectAsset -> objectAsset（引用关系）
      this.nodes.get(event.subjectAsset).edges.push({
        to: event.objectAsset,
        type: event.type,
        weight,
        eventId: event.id
      });

      return true;
    }

    /**
     * 从事件数组批量构建图
     * @param {object[]} events
     */
    buildGraph(events) {
      this.nodes.clear();
      this.edges.clear();
      this.edgeList = [];
      for (const e of events) this.addEvent(e);
    }

    /**
     * 获取某节点的邻居（被引用的资产）
     * @param {string} assetId
     * @returns {{assetId: string, type: string, weight: number}[]}
     */
    getNeighbors(assetId) {
      const node = this.nodes.get(assetId);
      if (!node) return [];
      return node.edges.map(e => ({ assetId: e.to, type: e.type, weight: e.weight }));
    }

    /**
     * 获取某资产的完整引用链（递归上溯）
     * @param {string} assetId
     * @param {number} [maxDepth=10]
     * @param {Set} [visited]
     * @returns {object[]}
     */
    getVerificationChain(assetId, maxDepth = 10, visited = new Set()) {
      if (maxDepth <= 0 || visited.has(assetId)) return [];
      visited.add(assetId);

      const node = this.nodes.get(assetId);
      if (!node || node.edges.length === 0) return [];

      const chain = [];
      for (const edge of node.edges) {
        const parent = this.nodes.get(edge.to);
        if (parent) {
          chain.push({ assetId: edge.to, type: edge.type, weight: edge.weight });
          chain.push(...this.getVerificationChain(edge.to, maxDepth - 1, visited));
        }
      }
      return chain;
    }

    /**
     * 计算PageRank
     * @param {number} [damping=0.85]
     * @param {number} [iterations=100]
     * @param {number} [epsilon=1e-6]
     * @returns {object} { assetId: rank }
     */
    calculatePageRank(damping = 0.85, iterations = 100, epsilon = 1e-6) {
      const nodeIds = Array.from(this.nodes.keys());
      const N = nodeIds.length;
      if (N === 0) return {};

      let ranks = {};
      for (const id of nodeIds) ranks[id] = 1 / N;

      // 构建邻接矩阵（出链）
      const outgoing = {};
      for (const id of nodeIds) {
        outgoing[id] = this.nodes.get(id).edges.length;
      }

      for (let iter = 0; iter < iterations; iter++) {
        const newRanks = {};
        let diff = 0;

        for (const id of nodeIds) {
          let rank = (1 - damping) / N;

          // 收集入链贡献
          for (const otherId of nodeIds) {
            if (otherId === id) continue;
            const node = this.nodes.get(otherId);
            const edge = node.edges.find(e => e.to === id);
            if (edge && outgoing[otherId] > 0) {
              rank += damping * ranks[otherId] / outgoing[otherId];
            }
          }

          newRanks[id] = rank;
          diff += Math.abs(rank - ranks[id]);
        }

        ranks = newRanks;
        if (diff < epsilon) break;
      }

      return ranks;
    }

    /**
     * 获取图中所有节点
     * @returns {string[]}
     */
    getAllNodes() {
      return Array.from(this.nodes.keys());
    }

    /**
     * 获取图中所有边
     * @returns {object[]}
     */
    getAllEdges() {
      return [...this.edgeList];
    }

    /**
     * 获取指定资产的事件列表
     * @param {string} assetId
     * @returns {object[]}
     */
    getAssetEvents(assetId) {
      return this.edgeList.filter(e => e.subjectAsset === assetId || e.objectAsset === assetId);
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== GraphEngine Tests ===');
      const engine = new GraphEngine();

      const events = [
        { id:'e1', type:'reference', subjectAsset:'a2', objectAsset:'a1', timestamp: nowMs(), userId:'u1', semanticDepth: 0.8 },
        { id:'e2', type:'remix', subjectAsset:'a3', objectAsset:'a2', timestamp: nowMs(), userId:'u2', semanticDepth: 0.6 },
        { id:'e3', type:'integrate', subjectAsset:'a4', objectAsset:'a2', timestamp: nowMs(), userId:'u3', semanticDepth: 0.5 },
        { id:'e4', type:'reference', subjectAsset:'a5', objectAsset:'a3', timestamp: nowMs(), userId:'u4', semanticDepth: 0.4 },
      ];

      for (const e of events) engine.addEvent(e);

      // 测试节点
      assert.ok(engine.nodes.has('a1'), 'Node a1 exists');
      assert.ok(engine.nodes.has('a5'), 'Node a5 exists');

      // 测试邻居
      const neighbors = engine.getNeighbors('a2');
      assert.equal(neighbors.length, 2, 'a2 has 2 outgoing edges');

      // 测试引用链
      const chain = engine.getVerificationChain('a3');
      assert.ok(chain.length > 0, 'Chain non-empty');
      assert.equal(chain[0].assetId, 'a2', 'First chain element is a2');

      // 测试PageRank
      const pr = engine.calculatePageRank();
      assert.ok(Object.keys(pr).length === 5, 'PageRank for all nodes');
      let total = 0;
      for (const k in pr) total += pr[k];
      assert.approx(total, 1.0, 0.01, 'PageRank sums to ~1');

      // 测试全部事件
      assert.equal(engine.getAllEdges().length, 4, 'All edges stored');

      console.log('✅ GraphEngine all tests passed');
    }
  }

  // ========================
  // 5. ShiTakeoverEngine — 势图接管引擎
  // ========================

  /**
   * 势图接管引擎
   * 根据全网态势自动调整档位，遵循"只开放，不收紧"原则
   * 核心规则：新配置 = 旧配置 OR 建议配置（取并集）
   *
   * @example
   * const te = new ShiTakeoverEngine();
   * const need = te.evaluateTakeover(asset, 2, { enabled: true, cooldownDays: 7 });
   * if (need.adjust) {
   *   const suggestion = te.generateSuggestion(asset, 2);
   * }
   */
  class ShiTakeoverEngine {
    constructor() {
      this.lastTakeover = new Map(); // assetId -> timestamp
      this.cooldownDays = 7;
    }

    /**
     * 评估是否需要调整
     * @param {object} asset - 资产对象
     * @param {number} currentStage - 当前生命阶段 0-4
     * @param {object} config - 配置 { enabled, cooldownDays, scope, maxLevel }
     * @returns {{adjust: boolean, reason: string, nextStage: number}}
     */
    evaluateTakeover(asset, currentStage, config = {}) {
      const enabled = config.enabled ?? asset.shiTakeover?.enabled ?? false;
      if (!enabled) return { adjust: false, reason: '势图接管已关闭', nextStage: currentStage };

      const cooldown = config.cooldownDays ?? this.cooldownDays;
      const lastTime = this.lastTakeover.get(asset.id) || 0;
      const daysSince = (nowMs() - lastTime) / 86400000;
      if (daysSince < cooldown) {
        return { adjust: false, reason: `冷却期未过（${Math.ceil(cooldown - daysSince)}天）`, nextStage: currentStage };
      }

      // 阶段递进规则
      const stageRules = [
        { minStage: 1, action: 'suggest_open', maxGearShift: 0 },   // 显现：建议开放
        { minStage: 2, action: 'auto_open', maxGearShift: 1 },       // 生长：自动开放，每次最多升1档
        { minStage: 3, action: 'lock_min', maxGearShift: 2 },       // 大成：锁定最低档
        { minStage: 4, action: 'suggest_full', maxGearShift: 5 },   // 转化：建议完全开放
      ];

      for (const rule of stageRules) {
        if (currentStage >= rule.minStage) {
          return {
            adjust: true,
            reason: `阶段${currentStage}触发规则：${rule.action}`,
            nextStage: currentStage,
            maxGearShift: rule.maxGearShift
          };
        }
      }

      return { adjust: false, reason: '当前阶段无需调整', nextStage: currentStage };
    }

    /**
     * 应用生态协议约束
     * @param {object} config
     * @param {number} stage
     * @returns {object} 约束后的配置
     */
    applyConstraints(config, stage) {
      const constrained = { ...config };
      if (stage >= 3) {
        // 大成阶段：锁定最低档，禁止收紧
        constrained.lockMinGear = true;
        constrained.allowTighten = false;
      } else if (stage >= 2) {
        // 生长阶段：自动开放，每次最多升1档
        constrained.allowTighten = false;
        constrained.maxGearShift = Math.min(constrained.maxGearShift || 1, 1);
      } else {
        constrained.allowTighten = false;
      }
      return constrained;
    }

    /**
     * 生成配置建议
     * @param {object} asset
     * @param {number} stage
     * @returns {{permissions: object, reason: string, changed: boolean}}
     */
    generateSuggestion(asset, stage) {
      const current = asset.permissions || {};
      const suggest = { ...current };
      let changed = false;
      let reason = '';

      const rights = ['use', 'expand', 'derive', 'benefit'];

      if (stage === 1) {
        // 显现：建议适度开放用权到亲档
        for (const r of rights) {
          const gear = current[r] || 0;
          if (!gearIncludes(gear, Gear.TRUST) && !gearIncludes(gear, Gear.PUBLIC)) {
            suggest[r] = gear | (1 << Gear.TRUST);
            changed = true;
          }
        }
        reason = '显现阶段：建议开放亲档（信任圈）';
      } else if (stage === 2) {
        // 生长：自动开放约档
        for (const r of rights) {
          const gear = current[r] || 0;
          const target = gear | (1 << Gear.CONTRACT);
          // "只开放，不收紧"：新=旧 OR 建议
          suggest[r] = gear | target;
          if (suggest[r] !== gear) changed = true;
        }
        reason = '生长阶段：自动开放约档（每次最多升1档）';
      } else if (stage === 3) {
        // 大成：锁定最低档为约档
        for (const r of rights) {
          const gear = current[r] || 0;
          if (!gearIncludes(gear, Gear.CONTRACT)) {
            suggest[r] = gear | (1 << Gear.CONTRACT);
            changed = true;
          }
        }
        reason = '大成阶段：锁定最低约档，禁止收紧';
      } else if (stage === 4) {
        // 转化：建议完全开放或冻结
        for (const r of rights) {
          suggest[r] = 1 << Gear.PUBLIC;
        }
        changed = true;
        reason = '转化阶段：建议完全开放为公共品';
      } else {
        reason = '潜藏阶段：无建议';
      }

      // 清理禁止组合
      for (const r of rights) {
        if (isForbiddenGear(suggest[r])) {
          // 回退到当前配置
          suggest[r] = current[r] || 0;
        }
      }

      return { permissions: suggest, reason, changed };
    }

    /**
     * 应用建议到资产（记录接管时间）
     * @param {object} asset
     * @param {object} suggestion
     * @returns {boolean}
     */
    applySuggestion(asset, suggestion) {
      if (!suggestion.changed) return false;
      this.lastTakeover.set(asset.id, nowMs());
      asset.permissions = { ...asset.permissions, ...suggestion.permissions };
      return true;
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== ShiTakeoverEngine Tests ===');
      const engine = new ShiTakeoverEngine();

      const asset = {
        id: 'a1', creatorId: 'alice',
        permissions: { use: 0b000010, expand: 0b000010, derive: 0b000010, benefit: 0b000010 },
        shiTakeover: { enabled: true }
      };

      // 测试：潜藏阶段不调整
      let eval = engine.evaluateTakeover(asset, 0, { enabled: true });
      assert.ok(!eval.adjust, 'Latent stage no adjust');

      // 测试：显现阶段建议
      eval = engine.evaluateTakeover(asset, 1, { enabled: true, cooldownDays: 0 });
      assert.ok(eval.adjust, 'Manifest stage adjusts');

      const sug = engine.generateSuggestion(asset, 1);
      assert.ok(sug.changed, 'Suggestion changed for manifest');
      assert.ok(gearIncludes(sug.permissions.use, Gear.TRUST), 'Manifest suggests trust gear');

      // 测试：生长阶段自动开放
      const sug2 = engine.generateSuggestion(asset, 2);
      assert.ok(gearIncludes(sug2.permissions.use, Gear.CONTRACT) || !sug2.changed, 'Growth suggests contract');

      // 测试：大成锁定
      const sug3 = engine.generateSuggestion(asset, 3);
      assert.ok(gearIncludes(sug3.permissions.use, Gear.CONTRACT), 'Mature locks contract');

      // 测试"只开放不收紧"原则
      const tightAsset = {
        id: 'a2', creatorId: 'alice',
        permissions: { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 },
        shiTakeover: { enabled: true }
      };
      const sugTight = engine.generateSuggestion(tightAsset, 2);
      // 公共品已经是最大开放，不应收紧
      assert.equal(sugTight.permissions.use, 0b100000, 'No tightening: public stays public');

      // 测试约束应用
      const constrained = engine.applyConstraints({ maxGearShift: 3 }, 3);
      assert.ok(constrained.lockMinGear, 'Mature locks min gear');
      assert.ok(!constrained.allowTighten, 'Mature prohibits tightening');

      console.log('✅ ShiTakeoverEngine all tests passed');
    }
  }

  // ========================
  // 6. RuleMarketEngine — 规则市场引擎
  // ========================

  /**
   * 规则市场引擎
   * 规则模板的创建、验证、应用与推荐
   * 模板嵌入约档(3)和法档(4)的可选约束
   *
   * @example
   * const rm = new RuleMarketEngine();
   * const tplId = rm.createTemplate({ name:'标准合约', type:'music' }, rules, 10, { author:'alice' });
   * const ok = rm.applyTemplate(asset, tplId);
   */
  class RuleMarketEngine {
    constructor() {
      this.templates = new Map();
      this.templateCounter = 0;
      this.usageStats = new Map(); // templateId -> usageCount
    }

    /**
     * 创建规则模板
     * @param {object} config - { name, type, description }
     * @param {object} rules - 四权规则 { use, expand, derive, benefit } + 付费规则
     * @param {number} price - 模板价格（ECHO代币）
     * @param {object} meta - { author, tags, version }
     * @returns {string} templateId
     */
    createTemplate(config, rules, price = 0, meta = {}) {
      const templateId = `tpl_${++this.templateCounter}_${Date.now().toString(36)}`;
      const template = {
        id: templateId,
        name: config.name || '未命名模板',
        type: config.type || 'generic',
        description: config.description || '',
        rules: { ...rules },
        price: Math.max(0, price),
        meta: {
          author: meta.author || 'anonymous',
          tags: meta.tags || [],
          version: meta.version || '1.0',
          createdAt: nowMs(),
          ...meta
        },
        validated: false
      };

      // 自动验证
      template.validated = this.validateTemplate(template);
      this.templates.set(templateId, template);
      this.usageStats.set(templateId, 0);
      return templateId;
    }

    /**
     * 将模板应用到资产
     * @param {object} asset
     * @param {string} templateId
     * @returns {boolean}
     */
    applyTemplate(asset, templateId) {
      const template = this.templates.get(templateId);
      if (!template) return false;
      if (!template.validated) return false;

      // 应用规则到资产权限
      const newPerms = { ...asset.permissions };
      for (const right of ['use', 'expand', 'derive', 'benefit']) {
        if (template.rules[right] !== undefined) {
          newPerms[right] = template.rules[right];
        }
      }

      // 检查禁止组合
      for (const right of ['use', 'expand', 'derive', 'benefit']) {
        if (isForbiddenGear(newPerms[right])) {
          return false;
        }
      }

      asset.permissions = newPerms;
      asset.templateId = templateId;
      asset.templateRules = { ...template.rules };

      this.usageStats.set(templateId, (this.usageStats.get(templateId) || 0) + 1);
      return true;
    }

    /**
     * 验证模板逻辑自洽性
     * @param {object} template
     * @returns {boolean}
     */
    validateTemplate(template) {
      const rules = template.rules || {};
      const rights = ['use', 'expand', 'derive', 'benefit'];

      // 检查所有档位组合是否合法
      for (const right of rights) {
        if (rules[right] !== undefined && isForbiddenGear(rules[right])) {
          return false;
        }
      }

      // 检查用权与扩权的一致性（扩权不能高于用权）
      const use = rules.use ?? 0;
      const expand = rules.expand ?? 0;
      if (highestGear(expand) > highestGear(use)) {
        // 扩权高于用权通常不合理，但可警告不阻止
        // 返回 true，标记为 warning
      }

      // 检查益权是否有对应的分润规则
      const benefit = rules.benefit ?? 0;
      if (gearIncludes(benefit, Gear.CONTRACT) && !rules.feeSchedule) {
        // 约档收益权应该有费率表
        // 不强制阻止，标记为 warning
      }

      // 检查衍权与扩权的一致性
      const derive = rules.derive ?? 0;
      if (highestGear(derive) > highestGear(expand)) {
        // 衍生权高于扩权不合理
      }

      return true;
    }

    /**
     * 获取推荐模板列表
     * @param {string} assetType - 资产类型: music/video/code/image/text
     * @param {number} [limit=5]
     * @returns {object[]}
     */
    getRecommendedTemplates(assetType, limit = 5) {
      const candidates = [];
      for (const [id, tpl] of this.templates) {
        let score = 0;
        // 类型匹配
        if (tpl.type === assetType) score += 10;
        // 人气（使用次数）
        score += (this.usageStats.get(id) || 0);
        // 验证状态
        if (tpl.validated) score += 5;
        candidates.push({ ...tpl, score });
      }
      candidates.sort((a, b) => b.score - a.score);
      return candidates.slice(0, limit);
    }

    /**
     * 获取模板详情
     * @param {string} templateId
     * @returns {object|null}
     */
    getTemplate(templateId) {
      const tpl = this.templates.get(templateId);
      return tpl ? { ...tpl, usageCount: this.usageStats.get(templateId) || 0 } : null;
    }

    /**
     * 获取所有模板
     * @returns {object[]}
     */
    getAllTemplates() {
      return Array.from(this.templates.values()).map(t => ({
        ...t, usageCount: this.usageStats.get(t.id) || 0
      }));
    }

    /** 运行单元测试 */
    static runTests() {
      console.log('=== RuleMarketEngine Tests ===');
      const engine = new RuleMarketEngine();

      // 测试创建模板
      const tplId = engine.createTemplate(
        { name: '独立音乐人标准合约', type: 'music', description: '适合独立音乐人的开放协议' },
        {
          use: 0b001110,      // 己+亲+约
          expand: 0b001110,   // 己+亲+约
          derive: 0b000110,   // 己+亲
          benefit: 0b001000,  // 约
          feeSchedule: { view: 1, remix: 5, purchase: 10 }
        },
        5,
        { author: 'echo_foundation', tags: ['music', 'standard'], version: '1.0' }
      );
      assert.ok(tplId.startsWith('tpl_'), 'Template ID format');
      assert.ok(engine.templates.has(tplId), 'Template stored');

      // 测试获取模板
      const tpl = engine.getTemplate(tplId);
      assert.equal(tpl.name, '独立音乐人标准合约', 'Template name');
      assert.equal(tpl.type, 'music', 'Template type');
      assert.ok(tpl.validated, 'Template auto-validated');

      // 测试应用到资产
      const asset = {
        id: 'a1', creatorId: 'alice',
        permissions: { use: 0b000010, expand: 0b000010, derive: 0b000010, benefit: 0b000010 },
        contractUsers: []
      };
      const ok = engine.applyTemplate(asset, tplId);
      assert.ok(ok, 'Template applied');
      assert.equal(asset.templateId, tplId, 'Asset linked to template');
      assert.ok(gearIncludes(asset.permissions.use, Gear.CONTRACT), 'Use gear includes contract after apply');

      // 测试非法模板被拒绝
      const badId = engine.createTemplate(
        { name: 'Bad Template', type: 'music' },
        { use: 0b000011 }, // 禁+己 = 禁止组合
        0
      );
      const badTpl = engine.getTemplate(badId);
      assert.ok(!badTpl.validated, 'Invalid template not validated');

      // 测试非法模板不能应用
      const asset2 = { id: 'a2', creatorId: 'bob', permissions: { use: 0b000010, expand: 0b000010, derive: 0b000010, benefit: 0b000010 } };
      const badApply = engine.applyTemplate(asset2, badId);
      assert.ok(!badApply, 'Invalid template not applied');

      // 测试推荐
      engine.createTemplate({ name: 'GPL风格', type: 'code' }, { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 }, 0, { author: 'fsf' });
      engine.createTemplate({ name: '视觉艺术', type: 'image' }, { use: 0b001000, expand: 0b001000, derive: 0b000100, benefit: 0b001000 }, 2);
      const recs = engine.getRecommendedTemplates('music');
      assert.ok(recs.length > 0, 'Recommendations non-empty');
      assert.equal(recs[0].type, 'music', 'First rec matches type');

      console.log('✅ RuleMarketEngine all tests passed');
    }
  }

  // ========================
  // 全局单元测试入口
  // ========================
  function runAllTests() {
    console.log('\n═══════════════════════════════════════');
    console.log('   ECHO Engine v2.0 — 单元测试');
    console.log('═══════════════════════════════════════\n');
    PermissionEngine.runTests();
    GraphEngine.runTests();
    RevenueEngine.runTests();
    ShiEngine.runTests();
    ShiTakeoverEngine.runTests();
    RuleMarketEngine.runTests();
    console.log('\n═══════════════════════════════════════');
    console.log('   ✅ 全部引擎单元测试通过');
    console.log('═══════════════════════════════════════\n');
  }

  // ========================
  // 导出
  // ========================
  return {
    PermissionEngine,
    RevenueEngine,
    ShiEngine,
    GraphEngine,
    ShiTakeoverEngine,
    RuleMarketEngine,
    runAllTests,
    Gear, GearNames, ActionMap
  };
});
