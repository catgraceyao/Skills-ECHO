# Skills ECHO化 设计方案

> 让现有技能识别、使用、交易 ECHO 资产的完整技术方案

---

## 1. 技能接口标准

### 1.1 ECHO 资产输入接口规范

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoAssetInput` | 定义技能接收 ECHO 资产的标准输入格式 | 技能需要处理用户提供的加密文件、NFT、许可等资产 | ```python\n@dataclass\nclass EchoAssetInput:\n    asset_id: str           # ECHO 资产唯一标识\n    asset_type: AssetType   # 文件/音乐/视频/许可等\n    content_hash: str       # 内容哈希验证\n    rights_proof: RightsProof  # 权利证明（见1.3）\n    encrypted_content: Optional[bytes] = None\n    metadata: Dict[str, Any] = field(default_factory=dict)\n``` |
| `AssetType` | 枚举支持的 ECHO 资产类型 | 类型检查、路由分发、权限控制 | ```python\nclass AssetType(Enum):\n    FILE = "file"           # 加密文件\n    MUSIC = "music"         # 音频资产\n    VIDEO = "video"         # 视频资产\n    IMAGE = "image"         # 图片资产\n    LICENSE = "license"     # 许可/授权\n    COMPOSITE = "composite" # 组合资产\n``` |
| `RightsProof` | 携带用户对资产的权利证明 | 链上验证、离线验证、缓存校验 | ```python\n@dataclass\nclass RightsProof:\n    owner_address: str      # 用户钱包地址\n    token_id: Optional[int] = None\n    license_type: LicenseType = LicenseType.OWNER\n    signature: str          # 权利签名\n    expires_at: Optional[datetime] = None\n    chain_proof: Optional[ChainProof] = None\n``` |
| `AssetResolver` | 资产解析器，统一处理各种来源的 ECHO 资产 | 从链接、ID、文件等多种格式解析 | ```python\nclass AssetResolver:\n    async def resolve(self, source: Union[str, Path, Dict]) -> EchoAssetInput:\n        # 支持: echo://asset/123, /path/to/asset.meta, {...}\n        if isinstance(source, str) and source.startswith("echo://"):\n            return await self._resolve_uri(source)\n        return await self._resolve_file(source)\n``` |

### 1.2 ECHO 资产输出接口规范

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoAssetOutput` | 定义技能生成 ECHO 资产的标准输出格式 | 技能生成内容后自动注册为资产 | ```python\n@dataclass\nclass EchoAssetOutput:\n    content: bytes          # 原始内容\n    content_type: str       # MIME类型\n    asset_type: AssetType\n    metadata: AssetMetadata  # 标准元数据\n    encryption_config: EncryptionConfig\n    royalty_config: Optional[RoyaltyConfig] = None\n    derived_from: List[str] = field(default_factory=list)  # 溯源\n``` |
| `AssetMetadata` | ECHO 资产标准元数据结构 | 注册资产时自动填充 | ```python\n@dataclass
class AssetMetadata:
    title: str
    description: str
    creator: str            # 创建者地址
    created_at: datetime
    tags: List[str] = field(default_factory=list)
    properties: Dict[str, Any] = field(default_factory=dict)
    
    def to_onchain_format(self) -> Dict:
        return {
            "name": self.title,
            "description": self.description,
            "image": "",  # 生成的封面
            "attributes": [{"trait_type": k, "value": v} 
                          for k, v in self.properties.items()]
        }
``` |
| `AssetRegistration` | 自动注册生成内容为 ECHO 资产 | 视频生成、音乐创作、文档处理等技能输出 | ```python
@dataclass
class AssetRegistration:
    auto_register: bool = True
    license_template: LicenseTemplate = LicenseTemplate.CC_BY_NC
    initial_price: Optional[Decimal] = None
    enable_derivatives: bool = False  # 是否允许衍生
    
    async def register(self, output: EchoAssetOutput) -> str:
        # 返回 asset_id
        return await echo_chain.mint_asset(output, self)
``` |
| `AssetEmitter` | 资产发射器，处理输出到注册的全流程 | 技能完成后自动上链 | ```python
class AssetEmitter:
    async def emit(self, output: EchoAssetOutput, 
                   registration: AssetRegistration) -> EmissionResult:
        # 1. 加密内容
        encrypted = await self._encrypt(output)
        # 2. 计算内容哈希
        content_hash = hashlib.sha256(output.content).hexdigest()
        # 3. 上传到去中心化存储
        storage_url = await self._upload_to_ipfs(encrypted)
        # 4. 链上注册
        asset_id = await registration.register(output)
        return EmissionResult(asset_id=asset_id, tx_hash=..., uri=storage_url)
``` |

### 1.3 权利声明接口

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `RightsRequirement` | 技能声明需要的权利 | 技能注册时声明输入要求 | ```python
@dataclass
class RightsRequirement:
    # 需要的权利类型
    required_rights: List[RightType]
    # 权利验证方式
    verify_mode: VerifyMode = VerifyMode.STRICT
    # 最小持有时间（防刷）
    min_hold_duration: timedelta = timedelta(hours=1)
    # 降级方案
    fallback: Optional[FallbackStrategy] = None

class RightType(Enum):
    OWNERSHIP = "ownership"      # 完全所有权
    LICENSE_BASIC = "license:basic"  # 基础许可
    LICENSE_COMMERCIAL = "license:commercial"
    LICENSE_DERIVATIVE = "license:derivative"  # 可衍生
    ACCESS_READ = "access:read"
    ACCESS_MODIFY = "access:modify"
``` |
| `RightsProvision` | 技能声明产生的权利 | 技能输出时声明授予用户的权利 | ```python
@dataclass
class RightsProvision:
    # 产生的权利类型
    granted_rights: List[RightType]
    # 许可期限
    duration: LicenseDuration = LicenseDuration.PERPETUAL
    # 转让限制
    transferable: bool = True
    # 衍生限制
    derivative_allowed: bool = False
    # 版税配置
    royalty_bps: int = 0  # 基点 (1/10000)
``` |
| `@echo_skill` | 装饰器：声明技能的 ECHO 能力 | 技能开发时标记 | ```python
@echo_skill(
    name="video-enhancer",
    version="1.0.0",
    inputs={
        "video": RightsRequirement(
            required_rights=[RightType.LICENSE_BASIC],
            fallback=FallbackStrategy.WATERMARK
        )
    },
    outputs={
        "enhanced_video": RightsProvision(
            granted_rights=[RightType.OWNERSHIP],
            derivative_allowed=True,
            royalty_bps=250  # 2.5%
        )
    }
)
class VideoEnhancerSkill(BaseSkill):
    pass
``` |

---

## 2. 权利感知机制

### 2.1 运行时权利验证

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `RightsVerifier` | 运行时验证用户对资产的权利 | 技能执行前检查权限 | ```python
class RightsVerifier:
    def __init__(self, echo_client: EchoClient, cache: RightsCache):
        self.client = echo_client
        self.cache = cache
    
    async def verify(
        self, 
        user_address: str,
        asset_id: str, 
        required_rights: List[RightType]
    ) -> VerificationResult:
        # 1. 检查缓存
        cached = await self.cache.get(user_address, asset_id)
        if cached and cached.covers(required_rights):
            return VerificationResult.ok(cached)
        
        # 2. 链上查询
        onchain_rights = await self.client.query_rights(asset_id, user_address)
        
        # 3. 更新缓存
        await self.cache.set(user_address, asset_id, onchain_rights)
        
        # 4. 验证
        if not onchain_rights.covers(required_rights):
            missing = required_rights - onchain_rights.granted
            return VerificationResult.failed(missing)
        
        return VerificationResult.ok(onchain_rights)
``` |
| `VerificationMiddleware` | 中间件层自动验证 | 透明拦截无权限调用 | ```python
class VerificationMiddleware:
    async def process(self, ctx: SkillContext, next: Callable):
        skill = ctx.skill
        for input_name, requirement in skill.rights_requirements.items():
            asset = ctx.inputs.get(input_name)
            if not asset:
                continue
            
            result = await self.verifier.verify(
                ctx.user.address,
                asset.asset_id,
                requirement.required_rights
            )
            
            if not result.success:
                if requirement.fallback:
                    ctx = await self._apply_fallback(ctx, requirement.fallback)
                else:
                    raise RightsException(f"Missing rights: {result.missing}")
        
        return await next(ctx)
``` |
| `MultiAssetBatchVerify` | 批量验证多个资产 | 技能需要多个输入资产时 | ```python
async def batch_verify(
    self, 
    requests: List[VerifyRequest]
) -> BatchVerificationResult:
    # 先查缓存，未命中再批量链上查询
    uncached = []
    for req in requests:
        cached = await self.cache.get(req.user, req.asset_id)
        if not cached:
            uncached.append(req)
    
    if uncached:
        # 单次 RPC 批量查询
        results = await self.client.batch_query_rights(uncached)
        await self.cache.batch_set(results)
    
    return self._aggregate_results(requests)
``` |

### 2.2 权利缓存策略

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `RightsCache` | 权利缓存接口 | 减少链上查询 | ```python
class RightsCache(ABC):
    @abstractmethod
    async def get(self, user: str, asset: str) -> Optional[CachedRights]: ...
    
    @abstractmethod
    async def set(self, user: str, asset: str, rights: RightsInfo, ttl: int): ...
    
    @abstractmethod
    async def invalidate(self, asset: str): ...  # 资产转移时触发

class RedisRightsCache(RightsCache):
    def __init__(self, redis: Redis):
        self.redis = redis
        self.default_ttl = 300  # 5分钟
    
    async def get(self, user: str, asset: str) -> Optional[CachedRights]:
        key = f"echo:rights:{user}:{asset}"
        data = await self.redis.get(key)
        if data:
            cached = CachedRights.from_json(data)
            if cached.expires_at > datetime.now():
                return cached
        return None
``` |
| `CacheInvalidation` | 缓存失效机制 | 资产权利变更时同步 | ```python
class CacheInvalidation:
    """监听链上事件，及时失效缓存"""
    
    async def listen_events(self):
        async for event in self.echo_client.watch_events():
            if event.type in ["Transfer", "LicenseGranted", "LicenseRevoked"]:
                asset_id = event.asset_id
                # 清除该资产的所有用户缓存
                await self.cache.invalidate_pattern(f"*:{asset_id}")
                
                # 广播给所有技能实例
                await self.event_bus.publish(RightsChangedEvent(asset_id))
``` |
| `OptimisticCaching` | 乐观缓存策略 | 读多写少场景 | ```python
class OptimisticCaching(RightsCache):
    """乐观缓存：允许短暂不一致，优先性能"""
    
    async def get_with_stale(self, user: str, asset: str, 
                             max_stale: int = 60) -> Optional[CachedRights]:
        key = f"echo:rights:{user}:{asset}"
        data = await self.redis.get(key)
        if data:
            cached = CachedRights.from_json(data)
            age = (datetime.now() - cached.cached_at).seconds
            
            # 即使过期也返回，后台刷新
            if age > self.default_ttl:
                asyncio.create_task(self._refresh_async(user, asset))
            
            return cached
        return None
``` |

### 2.3 权利不足的优雅降级

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `FallbackStrategy` | 降级策略枚举 | 无权限时的处理选择 | ```python
class FallbackStrategy(Enum):
    REJECT = "reject"           # 直接拒绝
    WATERMARK = "watermark"     # 添加水印输出
    LOW_RES = "low_resolution"  # 降低质量
    PARTIAL = "partial"         # 部分功能
    PREVIEW = "preview"         # 仅预览
    PAY_PER_USE = "pay_per_use" # 单次付费使用
``` |
| `WatermarkFallback` | 水印降级 | 无许可时带水印输出 | ```python
class WatermarkFallback(FallbackHandler):
    async def apply(self, ctx: SkillContext) -> SkillContext:
        ctx.metadata["watermarked"] = True
        ctx.metadata["watermark_text"] = f"ECHO Preview - {ctx.user.address[:8]}..."
        ctx.metadata["original_quality"] = ctx.config.quality
        ctx.config.quality = min(ctx.config.quality, 0.7)
        return ctx
    
    async def post_process(self, output: bytes) -> bytes:
        # 添加可见水印
        return await self._add_watermark(
            output, 
            text=self.ctx.metadata["watermark_text"],
            opacity=0.3
        )
``` |
| `PayPerUseFallback` | 单次付费降级 | 临时获取使用权 | ```python
class PayPerUseFallback(FallbackHandler):
    async def apply(self, ctx: SkillContext) -> SkillContext:
        # 弹出支付确认（或自动扣款）
        quote = await self.echo_client.get_usage_quote(
            asset_id=ctx.inputs["asset"].asset_id,
            usage_type=ctx.skill.usage_type
        )
        
        if ctx.auto_approve or await self._confirm_payment(quote):
            tx = await self.echo_client.pay_for_usage(quote)
            ctx.metadata["temporary_license"] = tx.license_id
            ctx.metadata["expires_at"] = tx.expires_at
            return ctx
        
        raise PaymentDeclinedException()
``` |
| `TieredDegradation` | 分层降级 | 根据权利缺失程度逐级降级 | ```python
class TieredDegradation:
    """根据缺失的权利类型，应用不同降级"""
    
    TIER_MAP = {
        {RightType.OWNERSHIP}: FallbackStrategy.FULL,
        {RightType.LICENSE_COMMERCIAL}: FallbackStrategy.WATERMARK,
        {RightType.LICENSE_BASIC}: FallbackStrategy.LOW_RES,
        {RightType.ACCESS_READ}: FallbackStrategy.PREVIEW,
    }
    
    async def degrade(self, ctx: SkillContext, missing: Set[RightType]) -> SkillContext:
        # 找到最适合的降级策略
        for required_rights, strategy in sorted(
            self.TIER_MAP.items(), 
            key=lambda x: len(x[0]), 
            reverse=True
        ):
            if missing <= required_rights:  # 缺失的是子集
                handler = self._get_handler(strategy)
                return await handler.apply(ctx)
        
        # 完全无权利，拒绝或单次付费
        return await PayPerUseFallback().apply(ctx)
``` |

---

## 3. 现有技能 ECHO化 改造示例

### 3.1 文件处理技能

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoFileProcessor` | 支持 ECHO 加密文件的文件处理器 | 处理受保护的文档、图片、视频文件 | ```python
@echo_skill(
    name="echo-file-processor",
    inputs={
        "file": RightsRequirement(
            required_rights=[RightType.ACCESS_READ],
            fallback=FallbackStrategy.REJECT
        )
    },
    outputs={
        "processed": RightsProvision(
            granted_rights=[RightType.OWNERSHIP],
            royalty_bps=100  # 1% 归原资产所有者
        )
    }
)
class EchoFileProcessor(BaseSkill):
    async def execute(self, ctx: SkillContext) -> SkillOutput:
        asset = ctx.inputs["file"]
        
        # 1. 解密内容（使用 rights_proof 中的密钥）
        decrypted = await self._decrypt(asset)
        
        # 2. 处理文件
        processed = await self._process(decrypted, ctx.config)
        
        # 3. 如果输入是衍生作品，添加溯源
        derived_from = [asset.asset_id] if asset.asset_type != AssetType.FILE else []
        
        # 4. 输出新资产
        return EchoAssetOutput(
            content=processed,
            asset_type=AssetType.FILE,
            derived_from=derived_from,
            metadata=AssetMetadata(
                title=f"Processed: {asset.metadata.get('title', 'Unknown')}",
                creator=ctx.user.address
            )
        )
    
    async def _decrypt(self, asset: EchoAssetInput) -> bytes:
        # 从 rights_proof 获取解密密钥
        key = await echo_crypto.derive_key(asset.rights_proof)
        return await echo_crypto.decrypt(asset.encrypted_content, key)
``` |
| `PermissionAwareFS` | 权利感知的文件系统接口 | 统一处理普通文件和 ECHO 文件 | ```python
class PermissionAwareFS:
    """让文件处理技能透明处理 ECHO 资产"""
    
    async def read(self, path: Union[str, EchoAssetInput]) -> bytes:
        if isinstance(path, EchoAssetInput):
            # 验证权利并解密
            await self._verify_and_cache_rights(path)
            return await self._decrypt(path)
        
        # 普通文件直接读取
        return await aiofiles.read(path)
    
    async def write(self, path: str, content: bytes, 
                    register_as_echo: bool = False) -> Union[str, EchoAssetOutput]:
        if not register_as_echo:
            await aiofiles.write(path, content)
            return path
        
        # 自动注册为 ECHO 资产
        return await self.emitter.emit(
            EchoAssetOutput(content=content, ...),
            AssetRegistration(auto_register=True)
        )
``` |
| `EchoDocumentConverter` | ECHO 文档转换器（PDF/Word/MD互转） | 保护知识产权的文档处理 | ```python
class EchoDocumentConverter(EchoFileProcessor):
    """文档转换技能 - 保持权利链条"""
    
    async def execute(self, ctx: SkillContext) -> SkillOutput:
        input_asset = ctx.inputs["document"]
        target_format = ctx.config["target_format"]
        
        # 解密源文档
        content = await self._decrypt(input_asset)
        
        # 转换格式
        converted = await self._convert(content, target_format)
        
        # 关键：继承原资产的授权设置
        original_license = await self.echo_client.get_license(input_asset.asset_id)
        
        return EchoAssetOutput(
            content=converted,
            metadata=AssetMetadata(
                title=f"{input_asset.metadata['title']}.{target_format}",
                properties={
                    "source_format": input_asset.metadata.get("format"),
                    "converted_by": self.name,
                    "original_license": original_license.template.value
                }
            ),
            # 继承许可模板
            registration=AssetRegistration(
                license_template=original_license.template,
                royalty_bps=original_license.royalty_bps
            ),
            derived_from=[input_asset.asset_id]
        )
``` |

### 3.2 视频生成技能

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoVideoGenerator` | 输出自动注册为 ECHO 资产的视频生成器 | AI 视频创作，保护创作者权益 | ```python
@echo_skill(
    name="echo-video-generator",
    inputs={
        "prompt": None,  # 文本提示不需要权利
        "reference_video": RightsRequirement(
            required_rights=[RightType.LICENSE_DERIVATIVE],
            fallback=FallbackStrategy.REJECT
        ),
        "style_reference": RightsRequirement(
            required_rights=[RightType.LICENSE_BASIC],
            fallback=FallbackStrategy.WATERMARK
        )
    },
    outputs={
        "video": RightsProvision(
            granted_rights=[RightType.OWNERSHIP],
            derivative_allowed=True,  # 允许再创作
            royalty_bps=500  # 5% 版税
        )
    }
)
class EchoVideoGenerator(BaseSkill):
    async def execute(self, ctx: SkillContext) -> SkillOutput:
        # 1. 准备输入
        prompt = ctx.inputs["prompt"]
        references = []
        
        if "reference_video" in ctx.inputs:
            ref = await self._prepare_video(ctx.inputs["reference_video"])
            references.append(ref)
        
        # 2. 生成视频
        generated = await self.model.generate(
            prompt=prompt,
            references=references,
            config=ctx.config
        )
        
        # 3. 自动注册为 ECHO 资产
        derived_from = [
            ctx.inputs[k].asset_id 
            for k in ["reference_video", "style_reference"] 
            if k in ctx.inputs
        ]
        
        output = EchoAssetOutput(
            content=generated.video_bytes,
            asset_type=AssetType.VIDEO,
            content_type="video/mp4",
            metadata=AssetMetadata(
                title=ctx.config.get("title", f"Generated: {prompt[:30]}..."),
                description=prompt,
                creator=ctx.user.address,
                properties={
                    "duration": generated.duration,
                    "resolution": f"{generated.width}x{generated.height}",
                    "model": self.model.name,
                    "generation_params": ctx.config
                }
            ),
            derived_from=derived_from,
            royalty_config=RoyaltyConfig(
                recipients=self._calculate_royalty_split(derived_from),
                bps=500
            )
        )
        
        # 4. 发射资产
        result = await self.emitter.emit(output, AssetRegistration())
        
        return SkillOutput(
            asset_id=result.asset_id,
            preview_url=result.preview_url,
            tx_hash=result.tx_hash
        )
    
    def _calculate_royalty_split(self, derived_from: List[str]) -> List[RoyaltyRecipient]:
        """计算版税分配：创作者70%，素材提供者30%"""
        recipients = [RoyaltyRecipient(address="creator", bps=350)]
        
        if derived_from:
            per_source = 150 // len(derived_from)  # 每个源1.5%
            for asset_id in derived_from:
                owner = self.echo_client.get_owner(asset_id)
                recipients.append(RoyaltyRecipient(address=owner, bps=per_source))
        
        return recipients
``` |
| `VideoTemplateMarket` | 视频模板市场集成 | 使用付费模板生成视频 | ```python
class VideoTemplateMarket:
    """集成 ECHO 模板市场的视频生成"""
    
    async def use_template(self, template_id: str, 
                          user_params: Dict, 
                          buyer: str) -> EchoVideoGenerator:
        # 1. 获取模板资产
        template = await self.echo_client.get_asset(template_id)
        
        # 2. 检查或购买使用权
        has_rights = await self.verifier.verify(
            buyer, template_id, [RightType.LICENSE_BASIC]
        )
        
        if not has_rights.success:
            # 自动购买
            await self.echo_client.buy_license(template_id, buyer)
        
        # 3. 返回配置好的生成器
        return EchoVideoGenerator(
            base_template=template,
            template_owner=template.metadata["creator"]
        )
``` |
| `ProvenanceTracker` | 生成视频的血统追踪 | 版权溯源、纠纷处理 | ```python
class ProvenanceTracker:
    """追踪 AI 生成视频的完整血统"""
    
    async def get_provenance(self, asset_id: str) -> ProvenanceGraph:
        asset = await self.echo_client.get_asset(asset_id)
        
        graph = ProvenanceGraph(root=asset_id)
        
        # 递归追踪所有源素材
        to_visit = [(asset_id, 0)]
        while to_visit:
            current_id, depth = to_visit.pop(0)
            current = await self.echo_client.get_asset(current_id)
            
            for source_id in current.derived_from:
                graph.add_edge(source_id, current_id, {
                    "relationship": "derived_from",
                    "contribution": self._estimate_contribution(source_id, current)
                })
                to_visit.append((source_id, depth + 1))
        
        return graph
    
    def generate_certificate(self, graph: ProvenanceGraph) -> str:
        """生成溯源证书（可用于版权证明）"""
        return json.dumps({
            "asset_id": graph.root,
            "lineage": graph.to_dict(),
            "timestamp": datetime.utcnow().isoformat(),
            "verification_hash": graph.merkle_root()
        }, indent=2)
``` |

### 3.3 音乐技能

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoMusicSkill` | 与「音」项目集成的音乐技能 | 创作、混音、采样受保护的音乐 | ```python
@echo_skill(
    name="echo-music-studio",
    inputs={
        "stems": RightsRequirement(
            required_rights=[RightType.LICENSE_DERIVATIVE],
            # 音乐需要明确的再创作许可
            verify_mode=VerifyMode.STRICT
        ),
        "samples": RightsRequirement(
            required_rights=[RightType.LICENSE_BASIC],
            fallback=FallbackStrategy.WATERMARK  # 无许可时添加水印
        ),
        "reference_track": RightsRequirement(
            required_rights=[RightType.ACCESS_READ],
            fallback=FallbackStrategy.PREVIEW  # 仅用于参考分析
        )
    },
    outputs={
        "track": RightsProvision(
            granted_rights=[RightType.OWNERSHIP],
            derivative_allowed=True,
            royalty_bps=1000  # 10% 音乐行业标准
        ),
        "stems": RightsProvision(
            granted_rights=[RightType.LICENSE_BASIC],
            derivative_allowed=True,
            royalty_bps=500
        )
    }
)
class EchoMusicStudio(BaseSkill):
    """与「音」项目深度集成的音乐创作技能"""
    
    def __init__(self):
        self.yin_client = YinProjectClient()  # 「音」项目客户端
        self.echo_client = EchoClient()
    
    async def execute(self, ctx: SkillContext) -> SkillOutput:
        project = MusicProject()
        
        # 1. 加载分轨（stems）
        if "stems" in ctx.inputs:
            for stem_asset in ctx.inputs["stems"]:
                stem_data = await self._load_audio(stem_asset)
                project.add_stem(Stem(
                    audio=stem_data,
                    source_asset=stem_asset.asset_id,
                    license_terms=await self._get_license_terms(stem_asset)
                ))
        
        # 2. 加载采样
        if "samples" in ctx.inputs:
            for sample in ctx.inputs["samples"]:
                sample_data = await self._load_audio(sample)
                project.add_sample(Sample(
                    audio=sample_data,
                    source_asset=sample.asset_id
                ))
        
        # 3. 调用「音」的处理引擎
        processed = await self.yin_client.process(project, ctx.config)
        
        # 4. 分析内容指纹（用于 Content ID）
        fingerprint = await self.yin_client.generate_fingerprint(processed.mix)
        
        # 5. 注册到「音」的 Content ID 系统
        await self.yin_client.register_content_id(
            fingerprint=fingerprint,
            echo_asset_id=None,  # 将在下面创建
            rights_holders=self._collect_rights_holders(project)
        )
        
        # 6. 输出多层级资产
        outputs = []
        
        # 6.1 主音轨 - 完整所有权
        track_output = EchoAssetOutput(
            content=processed.mix,
            asset_type=AssetType.MUSIC,
            metadata=AssetMetadata(
                title=ctx.config["title"],
                properties={
                    "bpm": processed.bpm,
                    "key": processed.key,
                    "duration": processed.duration,
                    "fingerprint": fingerprint,
                    "stems_count": len(project.stems),
                    "samples_count": len(project.samples)
                }
            ),
            derived_from=[s.source_asset for s in project.stems + project.samples]
        )
        track_result = await self.emitter.emit(track_output, AssetRegistration())
        outputs.append(("track", track_result))
        
        # 6.2 分轨包 - 允许他人再创作
        if ctx.config.get("export_stems", False):
            stems_output = EchoAssetOutput(
                content=processed.export_stems(),
                asset_type=AssetType.MUSIC,
                metadata=AssetMetadata(
                    title=f"{ctx.config['title']} - Stems",
                    properties={"type": "stems_package"}
                ),
                # 更宽松的许可
                registration=AssetRegistration(
                    license_template=LicenseTemplate.CC_BY,
                    initial_price=ctx.config.get("stem_price")
                )
            )
            stems_result = await self.emitter.emit(stems_output, AssetRegistration())
            outputs.append(("stems", stems_result))
        
        return SkillOutput(outputs=dict(outputs))
``` |
| `YinIntegration` | 「音」项目深度集成模块 | 指纹、Content ID、版税分配 | ```python
class YinIntegration:
    """ECHO 与「音」项目的桥接层"""
    
    async def register_track(self, audio: bytes, 
                            echo_asset_id: str,
                            rights_holders: List[RightsHolder]) -> str:
        """注册音轨到「音」的 Content ID 系统"""
        
        # 1. 生成音频指纹
        fingerprint = await self.yin.generate_fingerprint(audio)
        
        # 2. 检查是否包含未授权采样
        matches = await self.yin.identify(fingerprint)
        for match in matches:
            if match.confidence > 0.9:
                # 检查是否有该采样的权利
                has_rights = await self.echo_client.verify_rights(
                    echo_asset_id, match.source_id, RightType.LICENSE_BASIC
                )
                if not has_rights:
                    raise UnauthorizedSampleException(match.source_id)
        
        # 3. 注册 Content ID
        content_id = await self.yin.register({
            "fingerprint": fingerprint,
            "echo_asset_id": echo_asset_id,
            "rights_holders": [
                {"address": h.address, "share": h.share} 
                for h in rights_holders
            ]
        })
        
        # 4. 将 Content ID 写回 ECHO 资产元数据
        await self.echo_client.update_metadata(echo_asset_id, {
            "content_id": content_id,
            "fingerprint": fingerprint
        })
        
        return content_id
    
    async def handle_royalty_distribution(self, content_id: str, 
                                         amount: Decimal) -> List[Transaction]:
        """「音」检测到播放时，触发 ECHO 版税分配"""
        
        # 获取权利持有者
        holders = await self.yin.get_rights_holders(content_id)
        
        # 执行分配
        txs = []
        for holder in holders:
            share = amount * holder.share
            tx = await self.echo_client.transfer(holder.address, share)
            txs.append(tx)
        
        return txs
``` |
| `SampleClearance` | 采样清除检查 | 确保音乐不包含未授权采样 | ```python
class SampleClearance:
    """音乐发布前的采样清除检查"""
    
    async def check_clearance(self, audio: bytes, 
                             user_address: str) -> ClearanceReport:
        """
        检查音频是否包含需要清除的采样
        返回: ClearanceReport 包含需要的许可和费用
        """
        fingerprint = await self.yin.generate_fingerprint(audio)
        matches = await self.yin.identify(fingerprint)
        
        required_clearances = []
        for match in matches:
            if match.confidence < 0.8:
                continue  # 置信度太低，可能是误报
            
            source_asset = await self.echo_client.find_by_content_id(match.source_id)
            
            # 检查用户是否已有权利
            has_rights = await self.echo_client.verify_rights(
                user_address, source_asset.id, RightType.LICENSE_BASIC
            )
            
            if not has_rights:
                # 计算需要的许可费用
                quote = await self.echo_client.get_license_quote(
                    source_asset.id,
                    LicenseType.BASIC
                )
                required_clearances.append(ClearanceItem(
                    source=source_asset,
                    confidence=match.confidence,
                    timestamp=match.timestamp,
                    required_license=quote
                ))
        
        return ClearanceReport(
            can_publish=len(required_clearances) == 0,
            required_clearances=required_clearances,
            total_cost=sum(c.required_license.price for c in required_clearances)
        )
``` |

---

## 4. ECHO Skill SDK

### 4.1 开发者工具

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `@echo_skill` | ECHO 技能装饰器 | 快速标记技能 | ```python
def echo_skill(
    name: str,
    version: str,
    inputs: Dict[str, Optional[RightsRequirement]],
    outputs: Dict[str, RightsProvision],
    auto_register: bool = True
):
    """标记类为 ECHO 技能，自动处理权利验证和资产注册"""
    def decorator(cls):
        cls._echo_meta = EchoSkillMeta(
            name=name,
            version=version,
            inputs=inputs,
            outputs=outputs,
            auto_register=auto_register
        )
        
        # 注入基类
        if not issubclass(cls, BaseSkill):
            cls = type(cls.__name__, (BaseSkill, cls), {})
        
        # 包装 execute 方法
        original_execute = cls.execute
        
        async def wrapped_execute(self, ctx: SkillContext):
            # 自动验证输入权利
            for input_name, requirement in inputs.items():
                if requirement and input_name in ctx.inputs:
                    await self._verify_rights(ctx, input_name, requirement)
            
            # 执行原方法
            result = await original_execute(self, ctx)
            
            # 自动注册输出
            if auto_register and isinstance(result, EchoAssetOutput):
                result = await self._auto_register(result)
            
            return result
        
        cls.execute = wrapped_execute
        return cls
    
    return decorator
``` |
| `EchoSkillBuilder` | 技能构建器 | 程序化构建技能 | ```python
class EchoSkillBuilder:
    """流式构建 ECHO 技能"""
    
    def __init__(self, name: str):
        self.name = name
        self.inputs = {}
        self.outputs = {}
        self.handler = None
    
    def requires(self, name: str, *rights: RightType, 
                 fallback: FallbackStrategy = None):
        self.inputs[name] = RightsRequirement(
            required_rights=list(rights),
            fallback=fallback
        )
        return self
    
    def produces(self, name: str, *rights: RightType, **kwargs):
        self.outputs[name] = RightsProvision(
            granted_rights=list(rights),
            **kwargs
        )
        return self
    
    def with_handler(self, fn: Callable):
        self.handler = fn
        return self
    
    def build(self) -> Type[BaseSkill]:
        @echo_skill(
            name=self.name,
            inputs=self.inputs,
            outputs=self.outputs
        )
        class BuiltSkill(BaseSkill):
            async def execute(self, ctx: SkillContext):
                return await self.handler(ctx)
        
        return BuiltSkill

# 使用示例
skill = (EchoSkillBuilder("image-upscaler")
    .requires("image", RightType.LICENSE_BASIC)
    .produces("upscaled", RightType.OWNERSHIP, royalty_bps=200)
    .with_handler(lambda ctx: upscale(ctx.inputs["image"]))
    .build())
``` |
| `EchoContext` | 增强的上下文对象 | 提供 ECHO 相关工具 | ```python
class EchoContext:
    """为技能执行提供 ECHO 工具"""
    
    def __init__(self, base_ctx: SkillContext, echo_client: EchoClient):
        self.ctx = base_ctx
        self.echo = echo_client
        self.verifier = RightsVerifier(echo_client)
        self.emitter = AssetEmitter(echo_client)
    
    async def get_asset(self, input_name: str) -> DecryptedAsset:
        """获取并解密输入资产"""
        asset_input = self.ctx.inputs[input_name]
        await self.verifier.verify_or_fail(
            self.ctx.user.address,
            asset_input.asset_id,
            self.ctx.skill.rights_requirements[input_name].required_rights
        )
        return await self._decrypt(asset_input)
    
    async def emit_asset(self, content: bytes, **kwargs) -> EmissionResult:
        """发射新资产"""
        output = EchoAssetOutput(content=content, **kwargs)
        return await self.emitter.emit(output, AssetRegistration())
    
    async def derive_from(self, *asset_ids: str) -> List[str]:
        """自动构建溯源列表"""
        return list(asset_ids)
``` |

### 4.2 配置项规范

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `echo.config.yaml` | ECHO 技能配置文件 | 声明式配置技能 | ```yaml
skill:
  name: video-enhancer
  version: 1.0.0
  
echo:
  # 链配置
  chain:
    rpc_url: ${ECHO_RPC_URL}
    contract_address: "0x..."
  
  # 输入资产配置
  inputs:
    video:
      required_rights:
        - license:basic
      fallback: watermark
      
    style_reference:
      required_rights:
        - license:basic
      fallback: low_resolution
  
  # 输出资产配置
  outputs:
    enhanced_video:
      granted_rights:
        - ownership
      license_template: cc_by_nc
      enable_derivatives: true
      royalty_bps: 250
      
  # 缓存配置
  cache:
    provider: redis
    ttl: 300
    stale_acceptable: 60
  
  # 加密配置
  encryption:
    provider: echo_crypto
    algorithm: aes_256_gcm
``` |
| `SkillManifest` | 技能清单格式 | 技能市场发现 | ```json
{
  "manifest_version": "1.0",
  "skill": {
    "name": "echo-music-studio",
    "version": "1.2.0",
    "description": "AI music creation with ECHO rights management",
    "author": "echo-labs"
  },
  "echo_capabilities": {
    "accepts_assets": ["music", "audio"],
    "produces_assets": ["music"],
    "requires_verification": true,
    "supports_royalties": true
  },
  "rights_schema": {
    "inputs": {
      "stems": {
        "required": ["license:derivative"],
        "optional": ["license:commercial"]
      }
    },
    "outputs": {
      "track": {
        "grants": ["ownership"],
        "default_license": "cc_by_nc",
        "max_royalty_bps": 1500
      }
    }
  }
}
``` |

### 4.3 测试与验证工具

| 功能名称 | 功能描述 | 使用场景 | 代码示例 |
|---------|---------|---------|---------|
| `EchoSkillTester` | ECHO 技能测试框架 | 单元测试、集成测试 | ```python
class EchoSkillTester:
    """测试 ECHO 技能的完整工具"""
    
    def __init__(self):
        self.mock_client = MockEchoClient()
        self.verifier = RightsVerifier(self.mock_client, MockCache())
    
    async def test_rights_verification(self, skill: BaseSkill):
        """测试权利验证逻辑"""
        # 测试无权限场景
        ctx_no_rights = self._create_context(
            user=User(address="0x123"),
            inputs={
                "file": EchoAssetInput(
                    asset_id="asset_001",
                    rights_proof=RightsProof(owner_address="0x999")  # 不同用户
                )
            }
        )
        
        with pytest.raises(RightsException):
            await skill.execute(ctx_no_rights)
        
        # 测试有权限场景
        self.mock_client.grant_rights("0x123", "asset_001", [RightType.OWNERSHIP])
        
        ctx_with_rights = self._create_context(
            user=User(address="0x123"),
            inputs={
                "file": EchoAssetInput(
                    asset_id="asset_001",
                    rights_proof=RightsProof(owner_address="0x123")
                )
            }
        )
        
        result = await skill.execute(ctx_with_rights)
        assert result is not None
    
    async def test_asset_registration(self, skill: BaseSkill):
        """测试资产自动注册"""
        ctx = self._create_valid_context()
        result = await skill.execute(ctx)
        
        # 验证资产已注册
        assert result.asset_id is not None
        assert result.tx_hash is not None
        
        # 验证元数据正确
        asset = self.mock_client.get_asset(result.asset_id)
        assert asset.metadata.creator == ctx.user.address
``` |
| `RightsSimulation` | 权利状态模拟器 | 测试各种权利组合 | ```python
class RightsSimulation:
    """模拟不同权利状态进行测试"""
    
    def __init__(self):
        self.scenarios = []
    
    def add_scenario(self, name: str, rights_map: Dict[str, List[RightType]]):
        """添加测试场景"""
        self.scenarios.append((name, rights_map))
        return self
    
    async def run_matrix(self, skill: BaseSkill, base_ctx: SkillContext):
        """运行权利矩阵测试"""
        results = []
        
        for scenario_name, rights_map in self.scenarios:
            # 设置权利状态
            for asset_id, rights in rights_map.items():
                await self.mock_client.set_rights("test_user", asset_id, rights)
            
            # 执行技能
            try:
                ctx = self._apply_rights_to_context(base_ctx, rights_map)
                result = await skill.execute(ctx)
                results.append({
                    "scenario": scenario_name,
                    "success": True,
                    "output_type": type(result).__name__
                })
            except RightsException as e:
                results.append({
                    "scenario": scenario_name,
                    "success": False,
                    "error": str(e),
                    "fallback_applied": isinstance(e, FallbackAppliedException)
                })
        
        return results

# 使用示例
sim = RightsSimulation()
sim.add_scenario("full_rights", {"asset_1": [RightType.OWNERSHIP]})
sim.add_scenario("basic_only", {"asset_1": [RightType.LICENSE_BASIC]})
sim.add_scenario("no_rights", {"asset_1": []})

results = await sim.run_matrix(my_skill, test_context)
``` |
| `LocalEchoChain` | 本地 ECHO 链模拟 | 离线开发测试 | ```python
class LocalEchoChain:
    """内存中的 ECHO 链模拟，用于本地开发"""
    
    def __init__(self):
        self.assets: Dict[str, Asset] = {}
        self.rights: Dict[str, Dict[str, List[RightType]]] = {}  # asset -> user -> rights
        self.events: List[ChainEvent] = []
    
    async def mint_asset(self, output: EchoAssetOutput, 
                        registration: AssetRegistration) -> str:
        """模拟铸造资产"""
        asset_id = f"local_{len(self.assets)}"
        self.assets[asset_id] = Asset(
            id=asset_id,
            owner=output.metadata.creator,
            metadata=output.metadata,
            rights={output.metadata.creator: registration.granted_rights}
        )
        self.events.append(ChainEvent("Mint", asset_id))
        return asset_id
    
    async def query_rights(self, asset_id: str, 
                          user: str) -> RightsInfo:
        """模拟查询权利"""
        asset = self.assets.get(asset_id)
        if not asset:
            return RightsInfo(granted=[])
        
        return RightsInfo(granted=asset.rights.get(user, []))
    
    async def transfer(self, asset_id: str, from_addr: str, to_addr: str):
        """模拟转移"""
        asset = self.assets[asset_id]
        asset.owner = to_addr
        asset.rights[to_addr] = asset.rights.pop(from_addr, [])
        self.events.append(ChainEvent("Transfer", asset_id))
        
        # 触发缓存失效
        await self._emit_invalidation(asset_id)
``` |
| `EchoDevServer` | 开发服务器 | 本地调试技能 | ```python
class EchoDevServer:
    """本地开发服务器，提供完整的 ECHO 环境"""
    
    def __init__(self):
        self.chain = LocalEchoChain()
        self.skills: Dict[str, BaseSkill] = {}
    
    def register_skill(self, skill: BaseSkill):
        self.skills[skill.name] = skill
    
    async def invoke(self, skill_name: str, 
                    user: str, 
                    inputs: Dict,
                    config: Dict = None) -> Dict:
        """模拟调用技能"""
        skill = self.skills[skill_name]
        
        ctx = SkillContext(
            user=User(address=user),
            inputs=self._resolve_inputs(inputs),
            config=config or {},
            skill=skill,
            echo_client=self.chain
        )
        
        result = await skill.execute(ctx)
        
        return {
            "success": True,
            "result": result,
            "tx_logs": self.chain.events[-5:]  # 最近5个链上事件
        }
    
    def create_webui(self) -> str:
        """生成调试用的 Web UI"""
        return """
        <!DOCTYPE html>
        <html>
        <head><title>ECHO Skill Dev</title></head>
        <body>
            <h1>ECHO Skill Development Environment</h1>
            <div id="skills">
                <!-- 技能列表和测试表单 -->
            </div>
            <script>
                // WebSocket 连接到本地链
                // 实时显示权利验证和资产注册
            </script>
        </body>
        </html>
        """
``` |

---

## 附录：类型定义参考

```python
# 核心类型定义（供 SDK 实现参考）

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Union, Callable
from datetime import datetime, timedelta
from enum import Enum, auto
from decimal import Decimal

class RightType(Enum):
    OWNERSHIP = "ownership"
    LICENSE_BASIC = "license:basic"
    LICENSE_COMMERCIAL = "license:commercial"
    LICENSE_DERIVATIVE = "license:derivative"
    ACCESS_READ = "access:read"
    ACCESS_MODIFY = "access:modify"

class AssetType(Enum):
    FILE = "file"
    MUSIC = "music"
    VIDEO = "video"
    IMAGE = "image"
    LICENSE = "license"
    COMPOSITE = "composite"

class LicenseTemplate(Enum):
    CC0 = "cc0"
    CC_BY = "cc_by"
    CC_BY_NC = "cc_by_nc"
    CC_BY_SA = "cc_by_sa"
    PROPRIETARY = "proprietary"

class LicenseDuration(Enum):
    PERPETUAL = "perpetual"
    FIXED = "fixed"
    SUBSCRIPTION = "subscription"

class VerifyMode(Enum):
    STRICT = "strict"
    LENIENT = "lenient"
    OFFLINE = "offline"

@dataclass
class RightsInfo:
    granted: List[RightType]
    expires_at: Optional[datetime] = None
    source: str = "onchain"  # onchain, cache, offline

@dataclass
class RoyaltyRecipient:
    address: str
    bps: int  # 基点

@dataclass
class RoyaltyConfig:
    recipients: List[RoyaltyRecipient]
    bps: int

@dataclass
class EncryptionConfig:
    algorithm: str = "aes_256_gcm"
    key_derivation: str = "pbkdf2"

@dataclass
class EmissionResult:
    asset_id: str
    tx_hash: str
    uri: str
    preview_url: Optional[str] = None
```

---

> **设计参考**：此方案参考了 Python 装饰器模式、React Hooks 的声明式 API、以及 Stripe 的开发者体验设计。旨在让技能开发者以最少的代码改动即可接入 ECHO 协议。
