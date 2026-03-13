# ECHO Compose - QITMEER QNG 网络前端集成配置

> 项目: ECHO Compose 音乐资产平台  
> 技术栈: React + RainbowKit/Wagmi + Ethers.js  
> 目标网络: QITMEER QNG TestNet / Mainnet

---

## 📋 网络参数汇总

### QNG TestNet (推荐用于开发测试)

| 参数 | 值 |
|------|-----|
| Network Name | QNG - Testnet |
| RPC URL | `https://explorer.qitmeer.io/rpc` |
| Chain ID | `223` |
| Currency Symbol | `MEER` |
| Currency Decimals | `18` |
| Block Explorer | `https://qng-testnet.meerscan.io/` |

### Qitmeer Network Testnet (旧版备用)

| 参数 | 值 |
|------|-----|
| Network Name | Qitmeer Testnet |
| RPC URL | `https://testnet-qng.rpc.qitmeer.io/` |
| Chain ID | `8131` |
| Currency Symbol | `MEER-T` |
| Currency Decimals | `18` |
| Block Explorer | `https://qng-testnet.meerscan.io/` |

### QNG Mainnet (生产环境)

| 参数 | 值 |
|------|-----|
| Network Name | Qitmeer Network Mainnet |
| RPC URL | `https://qng.rpc.qitmeer.io` 或 `https://evm-dataseed1.meerscan.io` |
| Chain ID | `813` |
| Currency Symbol | `MEER` |
| Currency Decimals | `18` |
| Block Explorer | `https://qng.qitmeer.io/` |

---

## 1️⃣ Wagmi 配置文件

### `src/config/wagmi.ts`

```typescript
import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { 
  http, 
  createConfig,
  type Chain 
} from 'wagmi';
import { 
  injected, 
  walletConnect,
  metaMask,
  coinbaseWallet 
} from 'wagmi/connectors';

// ============================================
// QITMEER QNG 网络定义
// ============================================

/**
 * QNG TestNet (Chain ID: 223)
 * 推荐用于开发和测试
 */
export const qngTestnet: Chain = {
  id: 223,
  name: 'QNG - Testnet',
  nativeCurrency: {
    name: 'MEER',
    symbol: 'MEER',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['https://explorer.qitmeer.io/rpc'],
      webSocket: undefined,
    },
    public: {
      http: ['https://explorer.qitmeer.io/rpc'],
      webSocket: undefined,
    },
  },
  blockExplorers: {
    default: {
      name: 'QNG Testnet Explorer',
      url: 'https://qng-testnet.meerscan.io/',
    },
  },
  testnet: true,
};

/**
 * Qitmeer Testnet (Chain ID: 8131)
 * 旧版测试网络，备用
 */
export const qitmeerTestnet: Chain = {
  id: 8131,
  name: 'Qitmeer Testnet',
  nativeCurrency: {
    name: 'MEER Test',
    symbol: 'MEER-T',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['https://testnet-qng.rpc.qitmeer.io/'],
    },
    public: {
      http: ['https://testnet-qng.rpc.qitmeer.io/'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Qitmeer Testnet Explorer',
      url: 'https://qng-testnet.meerscan.io/',
    },
  },
  testnet: true,
};

/**
 * QNG Mainnet (Chain ID: 813)
 * 生产环境使用
 */
export const qngMainnet: Chain = {
  id: 813,
  name: 'Qitmeer Network Mainnet',
  nativeCurrency: {
    name: 'MEER',
    symbol: 'MEER',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: [
        'https://qng.rpc.qitmeer.io',
        'https://evm-dataseed1.meerscan.io',
        'https://evm-dataseed2.meerscan.io',
      ],
    },
    public: {
      http: [
        'https://qng.rpc.qitmeer.io',
        'https://evm-dataseed1.meerscan.io',
        'https://evm-dataseed2.meerscan.io',
      ],
    },
  },
  blockExplorers: {
    default: {
      name: 'QNG Explorer',
      url: 'https://qng.qitmeer.io/',
    },
  },
  testnet: false,
};

// ============================================
// RainbowKit 配置 (推荐)
// ============================================

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'YOUR_PROJECT_ID';

/**
 * 使用 RainbowKit 的 getDefaultConfig 创建配置
 * 推荐方式，简化配置流程
 */
export const rainbowConfig = getDefaultConfig({
  appName: 'ECHO Compose - 音乐资产平台',
  projectId,
  chains: [qngTestnet, qitmeerTestnet, qngMainnet],
  transports: {
    [qngTestnet.id]: http('https://explorer.qitmeer.io/rpc'),
    [qitmeerTestnet.id]: http('https://testnet-qng.rpc.qitmeer.io/'),
    [qngMainnet.id]: http('https://qng.rpc.qitmeer.io'),
  },
  ssr: true, // 如果使用了 Next.js 的 SSR
});

// ============================================
// 纯 Wagmi 配置 (不使用 RainbowKit 时)
// ============================================

/**
 * 纯 Wagmi 配置
 * 适用于不使用 RainbowKit 的场景
 */
export const wagmiConfig = createConfig({
  chains: [qngTestnet, qitmeerTestnet, qngMainnet],
  connectors: [
    injected({ target: 'metaMask' }),
    metaMask(),
    coinbaseWallet({
      appName: 'ECHO Compose',
    }),
    walletConnect({
      projectId,
      metadata: {
        name: 'ECHO Compose',
        description: '音乐资产平台',
        url: 'https://echocompose.com',
        icons: ['https://echocompose.com/icon.png'],
      },
    }),
  ],
  transports: {
    [qngTestnet.id]: http('https://explorer.qitmeer.io/rpc'),
    [qitmeerTestnet.id]: http('https://testnet-qng.rpc.qitmeer.io/'),
    [qngMainnet.id]: http('https://qng.rpc.qitmeer.io'),
  },
});

// ============================================
// 工具函数
// ============================================

/**
 * 根据 Chain ID 获取网络配置
 */
export const getChainById = (chainId: number): Chain | undefined => {
  const chains = [qngTestnet, qitmeerTestnet, qngMainnet];
  return chains.find((chain) => chain.id === chainId);
};

/**
 * 检查网络是否为 QNG 网络
 */
export const isQngNetwork = (chainId: number): boolean => {
  return [223, 8131, 813].includes(chainId);
};

/**
 * 获取网络显示名称
 */
export const getNetworkDisplayName = (chainId: number): string => {
  const chain = getChainById(chainId);
  return chain?.name || 'Unknown Network';
};

/**
 * 获取区块浏览器交易链接
 */
export const getExplorerTxUrl = (chainId: number, txHash: string): string => {
  const chain = getChainById(chainId);
  if (!chain?.blockExplorers?.default) return '';
  return `${chain.blockExplorers.default.url}/tx/${txHash}`;
};

/**
 * 获取区块浏览器地址链接
 */
export const getExplorerAddressUrl = (chainId: number, address: string): string => {
  const chain = getChainById(chainId);
  if (!chain?.blockExplorers?.default) return '';
  return `${chain.blockExplorers.default.url}/address/${address}`;
};

// 导出默认配置
export default rainbowConfig;
```

---

## 2️⃣ RainbowKitProvider 配置

### `src/providers/Web3Provider.tsx`

```tsx
'use client';

import React from 'react';
import { RainbowKitProvider, darkTheme, lightTheme } from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider } from 'wagmi';
import { rainbowConfig, qngTestnet, qitmeerTestnet, qngMainnet } from '@/config/wagmi';

// 创建 React Query 客户端
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000, // 1分钟
      retry: 2,
    },
  },
});

interface Web3ProviderProps {
  children: React.ReactNode;
}

/**
 * Web3 全局 Provider
 * 整合 Wagmi 和 RainbowKit
 */
export function Web3Provider({ children }: Web3ProviderProps) {
  return (
    <WagmiProvider config={rainbowConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          theme={{
            lightMode: lightTheme({
              accentColor: '#7b3fe4', // Qitmeer 品牌紫
              accentColorForeground: 'white',
              borderRadius: 'large',
              fontStack: 'system',
            }),
            darkMode: darkTheme({
              accentColor: '#7b3fe4',
              accentColorForeground: 'white',
              borderRadius: 'large',
              fontStack: 'system',
            }),
          }}
          modalSize="compact"
          initialChain={qngTestnet} // 默认连接到 QNG TestNet
          appInfo={{
            appName: 'ECHO Compose',
            learnMoreUrl: 'https://docs.echocompose.com',
          }}
        >
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default Web3Provider;
```

### `src/app/layout.tsx` (Next.js 示例)

```tsx
import { Web3Provider } from '@/providers/Web3Provider';
import '@rainbow-me/rainbowkit/styles.css';
import './globals.css';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN">
      <body>
        <Web3Provider>
          {children}
        </Web3Provider>
      </body>
    </html>
  );
}
```

---

## 3️⃣ NetworkSwitcher 网络切换组件

### `src/components/NetworkSwitcher.tsx`

```tsx
'use client';

import React, { useState } from 'react';
import { useChainId, useSwitchChain, useAccount } from 'wagmi';
import { Check, ChevronDown, Globe, AlertCircle } from 'lucide-react';
import { 
  qngTestnet, 
  qitmeerTestnet, 
  qngMainnet,
  getNetworkDisplayName,
  isQngNetwork 
} from '@/config/wagmi';

// 支持的网络列表
const SUPPORTED_CHAINS = [
  { 
    chain: qngTestnet, 
    icon: '🧪',
    description: '推荐用于开发测试',
  },
  { 
    chain: qitmeerTestnet, 
    icon: '🔧',
    description: '旧版测试网络',
  },
  { 
    chain: qngMainnet, 
    icon: '🌐',
    description: '生产环境',
  },
] as const;

/**
 * 网络状态指示器
 */
function NetworkStatus({ chainId }: { chainId: number }) {
  const isSupported = isQngNetwork(chainId);
  
  return (
    <span
      className={`inline-flex h-2 w-2 rounded-full ${
        isSupported ? 'bg-green-500' : 'bg-red-500'
      }`}
      title={isSupported ? '已连接到 QNG 网络' : '未连接到 QNG 网络'}
    />
  );
}

/**
 * 网络切换按钮组件
 */
export function NetworkSwitcher() {
  const chainId = useChainId();
  const { chains, switchChain, isPending } = useSwitchChain();
  const { isConnected } = useAccount();
  const [isOpen, setIsOpen] = useState(false);

  // 获取当前网络
  const currentChain = SUPPORTED_CHAINS.find(
    ({ chain }) => chain.id === chainId
  );

  // 处理网络切换
  const handleSwitch = (newChainId: number) => {
    if (switchChain) {
      switchChain({ chainId: newChainId });
      setIsOpen(false);
    }
  };

  // 未连接钱包时的提示
  if (!isConnected) {
    return (
      <button
        disabled
        className="flex items-center gap-2 px-4 py-2 rounded-lg bg-gray-100 
                   text-gray-400 cursor-not-allowed border border-gray-200"
      >
        <Globe className="w-4 h-4" />
        <span>请先连接钱包</span>
      </button>
    );
  }

  return (
    <div className="relative">
      {/* 切换按钮 */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={isPending}
        className={`flex items-center gap-2 px-4 py-2 rounded-lg border
                   transition-all duration-200 min-w-[180px] justify-between
                   ${isPending ? 'opacity-50 cursor-wait' : 'hover:bg-gray-50'}
                   ${!isQngNetwork(chainId) 
                     ? 'bg-red-50 border-red-200 text-red-700' 
                     : 'bg-white border-gray-200 text-gray-700'}`}
      >
        <div className="flex items-center gap-2">
          <NetworkStatus chainId={chainId} />
          <span className="font-medium">
            {currentChain ? `${currentChain.icon} ${currentChain.chain.name}` : 
             getNetworkDisplayName(chainId)}
          </span>
        </div>
        {isPending ? (
          <div className="w-4 h-4 border-2 border-gray-400 border-t-transparent rounded-full animate-spin" />
        ) : (
          <ChevronDown className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
        )}
      </button>

      {/* 网络不支持警告 */}
      {!isQngNetwork(chainId) && (
        <div className="absolute top-full left-0 right-0 mt-2 p-2 bg-red-50 
                        border border-red-200 rounded-lg text-xs text-red-600
                        flex items-start gap-1">
          <AlertCircle className="w-3 h-3 mt-0.5 flex-shrink-0" />
          <span>当前网络不支持，请切换到 QNG 网络</span>
        </div>
      )}

      {/* 下拉菜单 */}
      {isOpen && (
        <>
          {/* 遮罩层 */}
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setIsOpen(false)} 
          />
          
          {/* 菜单内容 */}
          <div className="absolute top-full left-0 right-0 mt-2 py-2 bg-white 
                          border border-gray-200 rounded-xl shadow-lg z-50 
                          min-w-[240px]">
            <div className="px-3 py-1.5 text-xs font-medium text-gray-400 uppercase">
              选择网络
            </div>
            
            {SUPPORTED_CHAINS.map(({ chain, icon, description }) => {
              const isActive = chain.id === chainId;
              const isSupported = chains.some((c) => c.id === chain.id);
              
              return (
                <button
                  key={chain.id}
                  onClick={() => handleSwitch(chain.id)}
                  disabled={isActive || !isSupported}
                  className={`w-full flex items-center gap-3 px-3 py-3 mx-2 rounded-lg
                             transition-colors text-left max-w-[calc(100%-16px)]
                             ${isActive 
                               ? 'bg-purple-50 text-purple-700' 
                               : 'hover:bg-gray-50 text-gray-700'}
                             ${!isSupported ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  <span className="text-lg">{icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="font-medium truncate">{chain.name}</div>
                    <div className="text-xs text-gray-400 truncate">
                      Chain ID: {chain.id} · {description}
                    </div>
                  </div>
                  {isActive && (
                    <Check className="w-4 h-4 text-purple-600 flex-shrink-0" />
                  )}
                </button>
              );
            })}
            
            {/* 添加网络按钮 */}
            <div className="border-t border-gray-100 mt-2 pt-2 px-3">
              <button
                onClick={() => {
                  // 打开 MetaMask 添加网络
                  if (typeof window !== 'undefined' && (window as any).ethereum) {
                    (window as any).ethereum.request({
                      method: 'wallet_addEthereumChain',
                      params: [{
                        chainId: `0x${qngTestnet.id.toString(16)}`,
                        chainName: qngTestnet.name,
                        nativeCurrency: qngTestnet.nativeCurrency,
                        rpcUrls: qngTestnet.rpcUrls.default.http,
                        blockExplorerUrls: [qngTestnet.blockExplorers?.default?.url],
                      }],
                    });
                  }
                  setIsOpen(false);
                }}
                className="w-full text-left text-sm text-purple-600 
                          hover:text-purple-700 py-1.5"
              >
                + 手动添加 QNG TestNet
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

/**
 * 简洁版网络切换组件
 */
export function NetworkSwitcherSimple() {
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { isConnected } = useAccount();

  if (!isConnected) return null;

  return (
    <select
      value={chainId}
      onChange={(e) => switchChain?.({ chainId: Number(e.target.value) })}
      className="px-3 py-2 rounded-lg border border-gray-200 bg-white
                 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
    >
      {SUPPORTED_CHAINS.map(({ chain }) => (
        <option key={chain.id} value={chain.id}>
          {chain.name}
        </option>
      ))}
    </select>
  );
}

export default NetworkSwitcher;
```

---

## 4️⃣ 测试交易发送示例

### `src/components/SendTransaction.tsx`

```tsx
'use client';

import React, { useState } from 'react';
import { 
  useSendTransaction, 
  useWaitForTransactionReceipt, 
  useAccount,
  useBalance 
} from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { Send, Loader2, ExternalLink, CheckCircle, XCircle } from 'lucide-react';
import { getExplorerTxUrl, qngTestnet } from '@/config/wagmi';

/**
 * 发送 MEER 交易组件
 * 用于测试 QNG 网络交易功能
 */
export function SendTransaction() {
  const { address, chainId } = useAccount();
  const { data: balance } = useBalance({ address });
  
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [error, setError] = useState<string | null>(null);

  const {
    data: hash,
    isPending,
    sendTransaction,
    reset,
  } = useSendTransaction();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  // 处理发送交易
  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!recipient || !amount) {
      setError('请填写完整信息');
      return;
    }

    // 验证地址格式 (简单验证)
    if (!recipient.startsWith('0x') || recipient.length !== 42) {
      setError('无效的地址格式');
      return;
    }

    try {
      await sendTransaction({
        to: recipient as `0x${string}`,
        value: parseEther(amount),
      });
    } catch (err: any) {
      setError(err.message || '交易失败');
    }
  };

  // 重置表单
  const handleReset = () => {
    setRecipient('');
    setAmount('');
    setError(null);
    reset();
  };

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-xl shadow-lg border border-gray-100">
      <div className="flex items-center gap-2 mb-6">
        <Send className="w-5 h-5 text-purple-600" />
        <h2 className="text-xl font-bold text-gray-800">发送 MEER (测试)</h2>
      </div>

      {/* 余额显示 */}
      {balance && (
        <div className="mb-4 p-3 bg-gray-50 rounded-lg">
          <span className="text-sm text-gray-500">当前余额: </span>
          <span className="font-medium text-gray-800">
            {formatEther(balance.value)} {balance.symbol}
          </span>
        </div>
      )}

      {/* 交易成功显示 */}
      {isSuccess && hash && (
        <div className="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
          <div className="flex items-center gap-2 text-green-700 mb-2">
            <CheckCircle className="w-5 h-5" />
            <span className="font-medium">交易已确认!</span>
          </div>
          <a
            href={getExplorerTxUrl(chainId || qngTestnet.id, hash)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-sm text-green-600 
                      hover:text-green-700 underline"
          >
            查看交易详情
            <ExternalLink className="w-3 h-3" />
          </a>
        </div>
      )}

      {/* 错误显示 */}
      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg
                        flex items-center gap-2 text-red-600 text-sm">
          <XCircle className="w-4 h-4 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleSend} className="space-y-4">
        {/* 接收地址 */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            接收地址
          </label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            placeholder="0x..."
            disabled={isPending || isConfirming || isSuccess}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg
                      focus:outline-none focus:ring-2 focus:ring-purple-500
                      disabled:bg-gray-50 disabled:text-gray-500
                      font-mono text-sm"
          />
        </div>

        {/* 金额 */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            金额 (MEER)
          </label>
          <input
            type="number"
            step="0.0001"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.01"
            disabled={isPending || isConfirming || isSuccess}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg
                      focus:outline-none focus:ring-2 focus:ring-purple-500
                      disabled:bg-gray-50 disabled:text-gray-500"
          />
          <p className="mt-1 text-xs text-gray-400">
            建议测试金额: 0.001 MEER
          </p>
        </div>

        {/* 按钮组 */}
        <div className="flex gap-3 pt-2">
          {isSuccess ? (
            <button
              type="button"
              onClick={handleReset}
              className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 
                        rounded-lg hover:bg-gray-200 transition-colors
                        font-medium"
            >
              发送新交易
            </button>
          ) : (
            <>
              <button
                type="button"
                onClick={() => {
                  setRecipient('');
                  setAmount('');
                }}
                disabled={isPending || isConfirming}
                className="px-4 py-2 text-gray-600 hover:bg-gray-100 
                          rounded-lg transition-colors"
              >
                重置
              </button>
              <button
                type="submit"
                disabled={isPending || isConfirming || !recipient || !amount}
                className="flex-1 px-4 py-2 bg-purple-600 text-white 
                          rounded-lg hover:bg-purple-700 transition-colors
                          disabled:opacity-50 disabled:cursor-not-allowed
                          font-medium flex items-center justify-center gap-2"
              >
                {(isPending || isConfirming) && (
                  <Loader2 className="w-4 h-4 animate-spin" />
                )}
                {isPending 
                  ? '等待确认...' 
                  : isConfirming 
                    ? '确认中...' 
                    : '发送交易'}
              </button>
            </>
          )}
        </div>
      </form>

      {/* 测试提示 */}
      <div className="mt-6 p-3 bg-blue-50 border border-blue-100 rounded-lg">
        <p className="text-xs text-blue-600">
          <strong>💡 提示:</strong> 在 QNG TestNet 上测试交易无需真实资金。
          如需要测试币，请访问官方 Faucet。
        </p>
      </div>
    </div>
  );
}

/**
 * 只读调用示例 - 获取区块信息
 */
export function BlockInfo() {
  // 这里可以使用 useBlockNumber, useBlock 等 hook
  // 示例简化展示
  return (
    <div className="p-4 bg-gray-50 rounded-lg">
      <h3 className="font-medium text-gray-700 mb-2">区块信息</h3>
      <p className="text-sm text-gray-500">
        使用 wagmi 的 useBlockNumber 和 useBlock hook 可以获取当前区块信息
      </p>
    </div>
  );
}

export default SendTransaction;
```

---

## 5️⃣ 连接钱包指引文档

### `docs/WALLET_SETUP.md`

```markdown
# ECHO Compose 钱包连接指南

## 概述

ECHO Compose 使用 RainbowKit + Wagmi 实现钱包连接功能，支持以下钱包：

- ✅ MetaMask
- ✅ WalletConnect 兼容钱包
- ✅ Coinbase Wallet
- ✅ 浏览器注入钱包 (Rabby, OKX 等)

## 快速开始

### 1. 安装依赖

```bash
npm install @rainbow-me/rainbowkit wagmi viem @tanstack/react-query
```

### 2. 环境变量配置

创建 `.env.local` 文件：

```env
# WalletConnect Project ID (从 https://cloud.walletconnect.com 获取)
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here

# 可选: 默认网络 (testnet/mainnet)
NEXT_PUBLIC_DEFAULT_NETWORK=testnet
```

### 3. 使用组件

```tsx
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { NetworkSwitcher } from '@/components/NetworkSwitcher';

function Header() {
  return (
    <header className="flex items-center gap-4">
      <NetworkSwitcher />
      <ConnectButton 
        showBalance={true}
        chainStatus="icon"
        accountStatus="address"
      />
    </header>
  );
}
```

## 手动添加 QNG 网络到 MetaMask

如果自动添加失败，可以手动添加：

### QNG TestNet

1. 打开 MetaMask，点击网络下拉菜单
2. 选择 "添加网络"
3. 填写以下信息：

```
网络名称: QNG - Testnet
RPC URL: https://explorer.qitmeer.io/rpc
链 ID: 223
货币符号: MEER
区块浏览器: https://qng-testnet.meerscan.io/
```

### QNG Mainnet

```
网络名称: Qitmeer Network Mainnet
RPC URL: https://qng.rpc.qitmeer.io
链 ID: 813
货币符号: MEER
区块浏览器: https://qng.qitmeer.io/
```

## 常见问题

### Q: 连接后显示 "Wrong Network"

A: 使用 `NetworkSwitcher` 组件切换到正确的 QNG 网络，或在 MetaMask 中手动添加网络。

### Q: 无法获取余额

A: 确保:
1. 已连接到正确的网络
2. RPC URL 可访问
3. 钱包中有 MEER 代币

### Q: 交易一直 Pending

A: 
1. 检查网络拥堵情况
2. 在区块浏览器上查看交易状态
3. 必要时提高 Gas 价格重试

### Q: WalletConnect 连接失败

A: 
1. 确保已正确配置 Project ID
2. 检查 WalletConnect 中继服务器状态
3. 尝试刷新页面重连

## 开发调试

### 查看连接状态

```tsx
import { useAccount, useNetwork } from 'wagmi';

function DebugInfo() {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  return (
    <pre>
      {JSON.stringify({
        isConnected,
        address,
        chainId: chain?.id,
        chainName: chain?.name,
      }, null, 2)}
    </pre>
  );
}
```

### 网络诊断

```tsx
import { useChainId, useSwitchNetwork } from 'wagmi';

function NetworkDiagnostics() {
  const chainId = useChainId();
  const { switchNetwork } = useSwitchNetwork();

  return (
    <div>
      <p>当前 Chain ID: {chainId}</p>
      <button onClick={() => switchNetwork?.(223)}>
        切换到 QNG TestNet
      </button>
    </div>
  );
}
```

## 安全提示

⚠️ **永远不要**: 
- 分享私钥或助记词
- 在不信任的网站上连接钱包
- 签署看不懂的交易数据

✅ **始终**: 
- 仔细检查交易接收地址
- 在测试网充分测试后再上主网
- 保持钱包软件更新
```

---

## 6️⃣ 项目目录结构建议

```
src/
├── app/
│   ├── layout.tsx          # 根布局，引入 Web3Provider
│   ├── page.tsx            # 首页
│   └── ...
├── components/
│   ├── NetworkSwitcher.tsx # 网络切换组件
│   ├── SendTransaction.tsx # 交易发送组件
│   └── ...
├── config/
│   └── wagmi.ts            # Wagmi/RainbowKit 配置
├── providers/
│   └── Web3Provider.tsx    # Web3 Provider 封装
├── hooks/
│   └── useQngNetwork.ts    # 自定义 Hooks (可选)
└── ...
```

---

## 7️⃣ 依赖版本参考

```json
{
  "dependencies": {
    "@rainbow-me/rainbowkit": "^2.x",
    "wagmi": "^2.x",
    "viem": "^2.x",
    "@tanstack/react-query": "^5.x",
    "ethers": "^6.x"
  }
}
```

---

## 8️⃣ 参考资源

- [Qitmeer 官方文档](https://docs.meerlabs.com/)
- [QNG 测试网浏览器](https://qng-testnet.meerscan.io/)
- [QNG 主网浏览器](https://qng.qitmeer.io/)
- [RainbowKit 文档](https://www.rainbowkit.com/docs/introduction)
- [Wagmi 文档](https://wagmi.sh/)
- [Viem 文档](https://viem.sh/)

---

## 9️⃣ 故障排除

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| Chain ID 不匹配 | 连接到了错误网络 | 使用 NetworkSwitcher 切换 |
| RPC 连接失败 | 节点不可用 | 更换备用 RPC URL |
| 余额显示为 0 | 未获取到数据 | 检查网络连接，刷新页面 |
| 交易发送失败 | Gas 不足 | 确保钱包有足够 MEER |
| 钱包弹窗不显示 | 浏览器拦截 | 允许弹出窗口 |

---

*文档生成时间: 2025-03-13*  
*适用于 ECHO Compose v1.0*
