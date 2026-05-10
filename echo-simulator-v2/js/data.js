/**
 * ECHO 模拟器 — 共享数据层
 * 包含用户、资产、验证事件、规则模板的模拟数据
 */

// ========================
// 用户数据
// ========================
const USERS = [
  {
    id: 'alice', name: 'Alice', role: 'creator', type: '独立音乐人',
    balance: 1000, reputation: 5.0,
    trustNetwork: ['alice', 'bob'],
    avatarColor: '#4a90a4',
    bio: '创作电子氛围音乐，相信开放的力量'
  },
  {
    id: 'bob', name: 'Bob', role: 'creator', type: '视频创作者',
    balance: 500, reputation: 3.0,
    trustNetwork: ['bob', 'alice', 'charlie'],
    avatarColor: '#5a9a6e',
    bio: '制作科普短视频，喜欢用音乐做BGM'
  },
  {
    id: 'charlie', name: 'Charlie', role: 'creator', type: '开源开发者',
    balance: 300, reputation: 4.0,
    trustNetwork: ['charlie', 'bob'],
    avatarColor: '#8b6914',
    bio: '开发音频处理工具，GPL信仰者'
  },
  {
    id: 'diana', name: 'Diana', role: 'user', type: '普通用户',
    balance: 100, reputation: 1.0,
    trustNetwork: ['diana'],
    avatarColor: '#c8a84c',
    bio: '音乐爱好者，偶尔remix'
  },
  {
    id: 'eve', name: 'Eve', role: 'platform', type: '平台运营',
    balance: 5000, reputation: 3.5,
    trustNetwork: ['eve'],
    avatarColor: '#2c3e50',
    bio: 'ECHO平台运营，维护生态秩序'
  },
  {
    id: 'mallory', name: 'Mallory', role: 'platform', type: 'AI公司',
    balance: 10000, reputation: 2.0,
    trustNetwork: ['mallory'],
    avatarColor: '#c45c48',
    bio: '训练AI音乐生成模型'
  }
];

// ========================
// 资产数据
// ========================
const ASSETS = [
  {
    id: 'song_spring', name: '春日序曲', creatorId: 'alice', type: 'music',
    permissions: { use: 0b001110, expand: 0b000110, derive: 0b000010, benefit: 0b000010 },
    // 用=己亲约, 扩=己亲, 衍=己, 益=己
    description: '一首关于春天的电子氛围音乐',
    createdAt: 1715000000000,
    price: 5,
    tags: ['电子', '氛围', '春天'],
    shiEnabled: true,
    downloads: 128,
    views: 2048
  },
  {
    id: 'video_tech', name: '量子计算科普', creatorId: 'bob', type: 'video',
    permissions: { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 },
    // 全公开
    description: '5分钟讲清楚量子计算原理',
    createdAt: 1715001000000,
    price: 0,
    tags: ['科普', '量子计算', '教育'],
    shiEnabled: false,
    downloads: 56,
    views: 1024
  },
  {
    id: 'code_audio', name: 'EchoAudio工具库', creatorId: 'charlie', type: 'code',
    permissions: { use: 0b100000, expand: 0b100000, derive: 0b010000, benefit: 0b010000 },
    // 用扩=公, 衍益=法
    description: '开源音频处理JavaScript库',
    createdAt: 1715002000000,
    price: 0,
    tags: ['开源', '音频', 'JavaScript'],
    shiEnabled: true,
    downloads: 312,
    views: 892
  },
  {
    id: 'photo_night', name: '城市夜景', creatorId: 'diana', type: 'image',
    permissions: { use: 0b001000, expand: 0b000100, derive: 0b000010, benefit: 0b000010 },
    // 用=约, 扩=亲, 衍=己, 益=己
    description: '上海外滩夜景摄影作品',
    createdAt: 1715003000000,
    price: 10,
    tags: ['摄影', '夜景', '上海'],
    shiEnabled: true,
    downloads: 45,
    views: 567
  },
  {
    id: 'rule_platform', name: 'ECHO平台标准合约', creatorId: 'eve', type: 'rule',
    permissions: { use: 0b001110, expand: 0b001110, derive: 0b000110, benefit: 0b000110 },
    description: 'ECHO平台推荐的标准授权模板',
    createdAt: 1715004000000,
    price: 0,
    tags: ['规则', '模板', '标准'],
    shiEnabled: false,
    downloads: 89,
    views: 445
  },
  {
    id: 'remix_spring', name: '春日序曲·Remix', creatorId: 'diana', type: 'music',
    parentId: 'song_spring',
    permissions: { use: 0b001110, expand: 0b000110, derive: 0b000010, benefit: 0b000010 },
    description: '基于Alice的春日序曲制作的Lo-Fi Remix',
    createdAt: 1715005000000,
    price: 3,
    tags: ['Remix', 'Lo-Fi', '春日序曲'],
    shiEnabled: true,
    downloads: 67,
    views: 334
  },
  {
    id: 'app_podcast', name: '播客制作套件', creatorId: 'bob', type: 'tool',
    parentId: 'code_audio',
    permissions: { use: 0b100000, expand: 0b010000, derive: 0b010000, benefit: 0b010000 },
    // 用=公, 扩衍益=法
    description: '基于EchoAudio的播客自动化制作工具',
    createdAt: 1715006000000,
    price: 15,
    tags: ['播客', '工具', '自动化'],
    shiEnabled: true,
    downloads: 23,
    views: 178
  },
  {
    id: 'ai_model', name: '氛围音乐生成模型', creatorId: 'mallory', type: 'ai',
    parentId: 'song_spring',
    permissions: { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 },
    // 全公开（因为法档授权）
    description: '基于春日序曲训练的氛围音乐AI模型',
    createdAt: 1715007000000,
    price: 50,
    tags: ['AI', '生成模型', '氛围音乐'],
    shiEnabled: true,
    downloads: 156,
    views: 678
  }
];

// ========================
// 验证事件数据
// ========================
const EVENTS = [
  // Alice发布春日序曲
  { id: 'evt_001', type: 'register', subject: 'song_spring', object: null, userId: 'alice', timestamp: 1715000000000, amount: 0, note: '登记资产' },
  // Bob观看
  { id: 'evt_002', type: 'view', subject: 'song_spring', object: null, userId: 'bob', timestamp: 1715000100000, amount: 0, note: 'Bob观看' },
  // Bob引用做BGM
  { id: 'evt_003', type: 'reference', subject: 'video_tech', object: 'song_spring', userId: 'bob', timestamp: 1715000200000, amount: 0, note: '视频引用音乐' },
  // Bob购买使用权
  { id: 'evt_004', type: 'purchase', subject: 'song_spring', object: null, userId: 'bob', timestamp: 1715000300000, amount: 5, note: '购买使用权' },
  // Charlie下载代码
  { id: 'evt_005', type: 'download', subject: 'code_audio', object: null, userId: 'charlie', timestamp: 1715000400000, amount: 0, note: '下载开源库' },
  // Diana观看
  { id: 'evt_006', type: 'view', subject: 'song_spring', object: null, userId: 'diana', timestamp: 1715000500000, amount: 0, note: 'Diana观看' },
  // Diana Remix
  { id: 'evt_007', type: 'remix', subject: 'remix_spring', object: 'song_spring', userId: 'diana', timestamp: 1715000600000, amount: 0, note: '创作Remix' },
  // Diana购买Remix
  { id: 'evt_008', type: 'purchase', subject: 'remix_spring', object: null, userId: 'diana', timestamp: 1715000700000, amount: 3, note: '购买Remix' },
  // Eve应用平台规则
  { id: 'evt_009', type: 'apply_rule', subject: 'rule_platform', object: 'song_spring', userId: 'eve', timestamp: 1715000800000, amount: 0, note: '应用平台规则' },
  // Charlie fork代码做播客工具
  { id: 'evt_010', type: 'fork', subject: 'app_podcast', object: 'code_audio', userId: 'bob', timestamp: 1715000900000, amount: 0, note: 'Fork开源库' },
  // Bob购买播客工具
  { id: 'evt_011', type: 'purchase', subject: 'app_podcast', object: null, userId: 'bob', timestamp: 1715001000000, amount: 15, note: '购买播客工具' },
  // Mallory申请法档授权
  { id: 'evt_012', type: 'apply_law', subject: 'ai_model', object: 'song_spring', userId: 'mallory', timestamp: 1715001100000, amount: 0, note: '申请法档训练授权' },
  // Alice同意法档授权
  { id: 'evt_013', type: 'grant_law', subject: 'song_spring', object: 'ai_model', userId: 'alice', timestamp: 1715001200000, amount: 0, note: '授权法档使用' },
  // Mallory发布AI模型
  { id: 'evt_014', type: 'register', subject: 'ai_model', object: null, userId: 'mallory', timestamp: 1715001300000, amount: 0, note: '发布AI模型' },
  // 大量用户使用AI模型
  { id: 'evt_015', type: 'purchase', subject: 'ai_model', object: null, userId: 'diana', timestamp: 1715001400000, amount: 50, note: '购买AI模型使用权' },
  { id: 'evt_016', type: 'view', subject: 'ai_model', object: null, userId: 'bob', timestamp: 1715001500000, amount: 0, note: '查看AI模型' },
  { id: 'evt_017', type: 'view', subject: 'ai_model', object: null, userId: 'charlie', timestamp: 1715001600000, amount: 0, note: '查看AI模型' },
  // 春日序曲势图接管触发
  { id: 'evt_018', type: 'shi_takeover', subject: 'song_spring', object: null, userId: 'system', timestamp: 1715001700000, amount: 0, note: '势图接管：用权自动开放至公档' }
];

// ========================
// 规则模板数据
// ========================
const RULE_TEMPLATES = [
  {
    id: 'tpl_music_std', name: '独立音乐人标准合约', type: 'music',
    description: '适合独立音乐人的标准授权模板',
    permissions: { use: 0b001110, expand: 0b000110, derive: 0b000010, benefit: 0b000010 },
    // 用=己亲约, 扩=己亲, 衍=己, 益=己
    price: 0, downloads: 523, rating: 4.5,
    creatorId: 'eve', createdAt: 1715000000000,
    tags: ['音乐', '标准', '独立'],
    rules: { purchaseRate: 0.7, remixRate: 0.5, parentShare: 0.1 }
  },
  {
    id: 'tpl_gpl', name: 'GPL风格开源', type: 'code',
    description: '类似GPL的开源协议，用扩衍益全部公开',
    permissions: { use: 0b100000, expand: 0b100000, derive: 0b100000, benefit: 0b100000 },
    price: 0, downloads: 1024, rating: 4.8,
    creatorId: 'charlie', createdAt: 1715000000000,
    tags: ['代码', '开源', 'GPL'],
    rules: { purchaseRate: 0, remixRate: 0, parentShare: 0 }
  },
  {
    id: 'tpl_ai_open', name: 'AI训练数据开放', type: 'data',
    description: '允许AI公司合法使用数据训练模型',
    permissions: { use: 0b010000, expand: 0b001000, derive: 0b010000, benefit: 0b010000 },
    // 用=法, 扩=约, 衍=法, 益=法
    price: 0, downloads: 89, rating: 3.5,
    creatorId: 'mallory', createdAt: 1715000000000,
    tags: ['AI', '数据', '训练'],
    rules: { purchaseRate: 0.3, remixRate: 0.2, parentShare: 0.05 }
  },
  {
    id: 'tpl_art_gallery', name: '视觉艺术画廊代理', type: 'image',
    description: '适合视觉艺术作品的画廊代理模式',
    permissions: { use: 0b001000, expand: 0b000100, derive: 0b000010, benefit: 0b000010 },
    // 用=约, 扩=亲, 衍=己, 益=己
    price: 2, downloads: 234, rating: 4.2,
    creatorId: 'eve', createdAt: 1715000000000,
    tags: ['视觉', '艺术', '画廊'],
    rules: { purchaseRate: 0.8, remixRate: 0.6, parentShare: 0.15 }
  },
  {
    id: 'tpl_blog_friendly', name: '个人博客友好协议', type: 'text',
    description: '适合个人博客文章的宽松授权',
    permissions: { use: 0b100000, expand: 0b010000, derive: 0b001000, benefit: 0b000100 },
    // 用=公, 扩=法, 衍=约, 益=亲
    price: 0, downloads: 445, rating: 4.0,
    creatorId: 'alice', createdAt: 1715000000000,
    tags: ['博客', '文字', '友好'],
    rules: { purchaseRate: 0, remixRate: 0.3, parentShare: 0.1 }
  }
];

// ========================
// 场景脚本
// ========================
const SCENARIOS = [
  {
    id: 'scene_music',
    name: '独立音乐人的生态生长',
    desc: 'Alice发布单曲，被引用、改编、传播，势图接管自动开放权限',
    icon: '🎵',
    steps: [
      { delay: 500, action: 'register', assetId: 'song_spring', userId: 'alice', note: 'Alice登记《春日序曲》' },
      { delay: 1500, action: 'view', assetId: 'song_spring', userId: 'bob', note: 'Bob发现并观看' },
      { delay: 2500, action: 'purchase', assetId: 'song_spring', userId: 'bob', amount: 5, note: 'Bob购买使用权' },
      { delay: 3500, action: 'reference', assetId: 'video_tech', parentId: 'song_spring', userId: 'bob', note: 'Bob用音乐做视频BGM' },
      { delay: 4500, action: 'view', assetId: 'song_spring', userId: 'diana', note: 'Diana观看' },
      { delay: 5500, action: 'remix', assetId: 'remix_spring', parentId: 'song_spring', userId: 'diana', note: 'Diana创作Remix' },
      { delay: 6500, action: 'purchase', assetId: 'remix_spring', userId: 'diana', amount: 3, note: '购买Remix' },
      { delay: 7500, action: 'apply_law', assetId: 'ai_model', parentId: 'song_spring', userId: 'mallory', note: 'Mallory申请法档授权' },
      { delay: 8500, action: 'grant_law', assetId: 'song_spring', userId: 'alice', note: 'Alice同意授权' },
      { delay: 9500, action: 'purchase', assetId: 'ai_model', userId: 'diana', amount: 50, note: 'Diana购买AI模型' },
      { delay: 10500, action: 'shi_takeover', assetId: 'song_spring', note: '势图接管：用权自动开放至公档' },
      { delay: 11500, action: 'config_lock', assetId: 'song_spring', userId: 'alice', note: 'Alice试图收紧权限，被系统阻止' }
    ]
  },
  {
    id: 'scene_opensource',
    name: '开源软件社区自治',
    desc: 'Charlie发布开源工具，社区fork、改进、形成生态',
    icon: '💻',
    steps: [
      { delay: 500, action: 'register', assetId: 'code_audio', userId: 'charlie', note: 'Charlie发布EchoAudio' },
      { delay: 1500, action: 'download', assetId: 'code_audio', userId: 'bob', note: 'Bob下载使用' },
      { delay: 2500, action: 'download', assetId: 'code_audio', userId: 'diana', note: 'Diana下载使用' },
      { delay: 3500, action: 'fork', assetId: 'app_podcast', parentId: 'code_audio', userId: 'bob', note: 'Bob Fork做播客工具' },
      { delay: 4500, action: 'purchase', assetId: 'app_podcast', userId: 'bob', amount: 15, note: '购买播客工具' },
      { delay: 5500, action: 'shi_takeover', assetId: 'code_audio', note: '势图接管：扩权自动开放' },
      { delay: 6500, action: 'remix', assetId: 'app_podcast', parentId: 'code_audio', userId: 'diana', note: 'Diana改进播客工具' },
      { delay: 7500, action: 'purchase', assetId: 'app_podcast', userId: 'mallory', amount: 15, note: 'Mallory购买' }
    ]
  },
  {
    id: 'scene_society',
    name: '多Agent社会经济',
    desc: '5个Agent在ECHO网络中自发交易、衍生、分润',
    icon: '🏙️',
    steps: [
      { delay: 500, action: 'register', assetId: 'song_spring', userId: 'alice', note: 'Alice发歌' },
      { delay: 1000, action: 'register', assetId: 'photo_night', userId: 'diana', note: 'Diana发照片' },
      { delay: 1500, action: 'register', assetId: 'code_audio', userId: 'charlie', note: 'Charlie发代码' },
      { delay: 2000, action: 'purchase', assetId: 'song_spring', userId: 'bob', amount: 5, note: 'Bob买歌' },
      { delay: 2500, action: 'purchase', assetId: 'photo_night', userId: 'eve', amount: 10, note: 'Eve买照片' },
      { delay: 3000, action: 'remix', assetId: 'remix_spring', parentId: 'song_spring', userId: 'diana', note: 'Diana Remix' },
      { delay: 3500, action: 'reference', assetId: 'video_tech', parentId: 'song_spring', userId: 'bob', note: 'Bob引用' },
      { delay: 4000, action: 'fork', assetId: 'app_podcast', parentId: 'code_audio', userId: 'bob', note: 'Bob Fork' },
      { delay: 4500, action: 'apply_law', assetId: 'ai_model', parentId: 'song_spring', userId: 'mallory', note: 'Mallory申请' },
      { delay: 5000, action: 'grant_law', assetId: 'song_spring', userId: 'alice', note: 'Alice授权' },
      { delay: 5500, action: 'register', assetId: 'ai_model', userId: 'mallory', note: 'Mallory发模型' },
      { delay: 6000, action: 'purchase', assetId: 'ai_model', userId: 'diana', amount: 50, note: 'Diana买模型' },
      { delay: 6500, action: 'purchase', assetId: 'ai_model', userId: 'bob', amount: 50, note: 'Bob买模型' },
      { delay: 7000, action: 'shi_takeover', assetId: 'song_spring', note: '势图接管触发' },
      { delay: 7500, action: 'revenue_split', assetId: 'ai_model', note: '多级分润执行' }
    ]
  },
  {
    id: 'scene_takeover',
    name: '势图接管冲突与解决',
    desc: '展示势图接管"只开放不收紧"原则和元规则约束',
    icon: '⚖️',
    steps: [
      { delay: 500, action: 'register', assetId: 'song_spring', userId: 'alice', note: 'Alice发歌（保守配置）' },
      { delay: 1500, action: 'view', assetId: 'song_spring', userId: 'bob', note: 'Bob观看' },
      { delay: 2500, action: 'view', assetId: 'song_spring', userId: 'diana', note: 'Diana观看' },
      { delay: 3500, action: 'view', assetId: 'song_spring', userId: 'charlie', note: 'Charlie观看' },
      { delay: 4500, action: 'remix', assetId: 'remix_spring', parentId: 'song_spring', userId: 'diana', note: 'Remix' },
      { delay: 5500, action: 'reference', assetId: 'video_tech', parentId: 'song_spring', userId: 'bob', note: '引用' },
      { delay: 6500, action: 'shi_takeover', assetId: 'song_spring', note: '接管：扩权开放至公档' },
      { delay: 7500, action: 'config_lock', assetId: 'song_spring', userId: 'alice', note: 'Alice试图收紧→被阻止' },
      { delay: 8500, action: 'apply_law', assetId: 'ai_model', parentId: 'song_spring', userId: 'mallory', note: '申请法档' },
      { delay: 9500, action: 'grant_law', assetId: 'song_spring', userId: 'alice', note: '授权' },
      { delay: 10500, action: 'shi_takeover', assetId: 'song_spring', note: '接管：益权开放至法档' }
    ]
  }
];

// ========================
// 元规则
// ========================
const META_RULES = [
  { id: 1, name: '初始配置不可篡改', desc: '谁有权利', icon: '🔒' },
  { id: 2, name: '配置即承诺', desc: '权利如何使用', icon: '📜' },
  { id: 3, name: '流动即执行', desc: '承诺如何生效', icon: '🌊' },
  { id: 4, name: '衍生即继承', desc: '承诺如何传递', icon: '🌱' },
  { id: 5, name: '版本即历史', desc: '承诺如何保护', icon: '📚' },
  { id: 6, name: '势位即边界', desc: '承诺如何适应变化', icon: '⚖️' }
];

// ========================
// 生命阶段配置
// ========================
const LIFE_STAGES = [
  { id: 0, name: '潜藏', threshold: 0, color: '#2a2a30', desc: '无验证事件，独立存在' },
  { id: 1, name: '显现', threshold: 20, color: '#4a90a4', desc: '开始被引用，建议开放' },
  { id: 2, name: '生长', threshold: 40, color: '#5a9a6e', desc: '中度连接，自动开放' },
  { id: 3, name: '大成', threshold: 60, color: '#c8a84c', desc: '高度连接，锁定最低档' },
  { id: 4, name: '转化', threshold: 80, color: '#c45c48', desc: '周期尾声，建议完全开放' }
];

// ========================
// 工具函数
// ========================
const DataUtils = {
  getUser(id) { return USERS.find(u => u.id === id); },
  getAsset(id) { return ASSETS.find(a => a.id === id); },
  getAssetEvents(id) { return EVENTS.filter(e => e.subject === id || e.object === id); },
  getUserAssets(id) { return ASSETS.filter(a => a.creatorId === id); },
  getTemplate(id) { return RULE_TEMPLATES.find(t => t.id === id); },
  getScenario(id) { return SCENARIOS.find(s => s.id === id); },
  
  gearName(mask) {
    const names = [];
    for (let i = 0; i <= 5; i++) if (mask & (1 << i)) names.push(['禁','己','亲','约','法','公'][i]);
    return names.join('·') || '禁';
  },
  
  gearColor(gear) {
    const colors = ['#555','#8b6914','#4a90a4','#c8a84c','#2c3e50','#5a9a6e'];
    const highest = [5,4,3,2,1,0].find(i => gear & (1<<i)) || 0;
    return colors[highest];
  },
  
  formatTime(ts) {
    const d = new Date(ts);
    return `${d.getMonth()+1}月${d.getDate()}日 ${d.getHours()}:${d.getMinutes().toString().padStart(2,'0')}`;
  },
  
  formatCurrency(amount) {
    return amount === 0 ? '免费' : `¥${amount}`;
  }
};

// ========================
// 导出（UMD）
// ========================
(function (global) {
  const ECHOData = {
    USERS, ASSETS, EVENTS, RULE_TEMPLATES, SCENARIOS,
    META_RULES, LIFE_STAGES, DataUtils
  };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = ECHOData;
  } else {
    global.ECHOData = ECHOData;
  }
})(typeof globalThis !== 'undefined' ? globalThis : window);
