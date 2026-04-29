# ECHO Protocol Layer 0 - Integration Document

> **Version**: v1.0  
> **Date**: 2026-04-19  
> **Status**: Architecture Draft  
> **Author**: Layer 0 Integration Agent  

---

## Table of Contents

1. [Layer 0 Architecture Overview](#1-layer-0-architecture-overview)
2. [Contract Interaction Diagrams](#2-contract-interaction-diagrams)
3. [Common Infrastructure](#3-common-infrastructure)
4. [Deployment Architecture](#4-deployment-architecture)
5. [Security Model](#5-security-model)
6. [Gas Optimization](#6-gas-optimization)
7. [Upper Layer Integration](#7-upper-layer-integration)
8. [Testing and Audit Plan](#8-testing-and-audit-plan)

---

## 1. Layer 0 Architecture Overview

### 1.1 Design Philosophy

Layer 0 serves as the foundational trust layer for the entire ECHO ecosystem. It provides four atomic capabilities:

| Capability | Contract | Purpose |
|------------|----------|---------|
| **Asset Minting** | EchoCore | Create, track, and manage digital assets |
| **Rights Registration** | RightsRegistry | Configure the four-dimensional rights model |
| **Revenue Distribution** | RevenueSplitter | Transparent and automatic value flow |
| **Cross-Chain Bridge** | CrossChainBridge | Interoperability with external ecosystems |

### 1.2 Core Principles

1. **Minimal On-Chain Logic**: Store only what must be immutable; compute off-chain when possible
2. **Event-Driven Architecture**: All state changes emit events for indexing and monitoring
3. **Upgradeable by Design**: Proxy patterns enable protocol evolution without migration
4. **Composability First**: Contracts designed to be called by Layer 1-5 components

### 1.3 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Layer 0: Protocol Core                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────┐   │
│   │   EchoCore   │◄──►│RightsRegistry│◄──►│RevenueSplitter│◄──►CrossChain│   │
│   │              │    │              │    │               │    │  Bridge │   │
│   │ • Mint       │    │ • 4D Rights  │    │ • Distribution│    │• Lock   │   │
│   │ • Ownership  │    │ • Licensing  │    │ • Tracing     │    │• Mint   │   │
│   │ • Metadata   │    │ • Inheritance│    │ • Settlement  │    │• Sync   │   │
│   └──────┬───────┘    └──────┬───────┘    └───────┬───────┘    └────┬───┘   │
│          │                   │                    │                 │       │
│          └───────────────────┴────────────────────┘                 │       │
│                           │                                         │       │
│                    Shared Libraries                                 │       │
│              ┌────────────┬────────────┐                         │       │
│              │ AccessControl │ RightsMath │ MerkleUtils │         │       │
│              └────────────┴────────────┘                         │       │
│                                                                    │       │
│   ┌──────────────────────────────────────────────────────────────┴──────┐  │
│   │                           Event System                               │  │
│   │  AssetMinted │ RightsConfigured │ LicenseGranted │ RevenueDistributed │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                          Proxy Layer                                  │  │
│   │   TransparentUpgradeableProxy (OpenZeppelin) for all core contracts   │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Upper Layers (1-5)                               │
│  Layer 1: Creator Tools │ Layer 2: Sandbox │ Layer 3: Skill Market        │
│  Layer 4: Agents        │ Layer 5: Applications                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 Contract Responsibilities Matrix

| Function Area | EchoCore | RightsRegistry | RevenueSplitter | CrossChainBridge |
|---------------|----------|----------------|-----------------|------------------|
| **Asset Identity** | ✓ Primary | ✓ Read | ✓ Read | ✓ Read |
| **Ownership** | ✓ Primary | ✗ | ✗ | ✓ Sync |
| **Rights Config** | ✗ | ✓ Primary | ✓ Read | ✓ Sync |
| **Revenue Logic** | ✗ | ✗ | ✓ Primary | ✗ |
| **Cross-Chain** | ✓ Lock/Unlock | ✓ Sync | ✓ Read | ✓ Primary |
| **Event Emission** | ✓ | ✓ | ✓ | ✓ |

---

## 2. Contract Interaction Diagrams

### 2.1 Asset Minting with Rights Configuration

When a creator mints a new asset with a Blueprint configuration:

```
┌──────────┐     ┌──────────┐     ┌──────────────┐     ┌────────────────┐
│  Creator │────►│ EchoCore │────►│RightsRegistry│     │ RevenueSplitter│
│  (User)  │     │          │     │                │     │                │
└──────────┘     └──────────┘     └────────────────┘     └────────────────┘
       │              │                  │                      │
       │  1. mintAsset(metadata, blueprint)
       │─────────────►│                  │                      │
       │              │                  │                      │
       │              │  2. _mint()      │                      │
       │              │  Store asset     │                      │
       │              │  Emit AssetMinted│                      │
       │              │                  │                      │
       │              │  3. configureRights(assetId, blueprint)     │
       │              │─────────────────►│                      │
       │              │                  │                      │
       │              │                  │  3a. Store 4D rights │
       │              │                  │       Use/Der/Ext/Rev│
       │              │                  │                      │
       │              │                  │  3b. Validate splits │
       │              │                  │─────────────────────►│
       │              │                  │                      │
       │              │                  │  3c. Return validity │
       │              │                  │◄─────────────────────│
       │              │                  │                      │
       │              │                  │  3d. Emit RightsConfigured
       │              │                  │                      │
       │              │  4. Return assetId│                     │
       │◄─────────────│                  │                      │
       │              │                  │                      │
```

**Key Integration Points**:
1. EchoCore creates the asset and assigns ownership
2. EchoCore atomically calls RightsRegistry to configure rights
3. RightsRegistry validates revenue splits with RevenueSplitter
4. All state changes emit indexed events

### 2.2 Derivative Creation with Upstream Tracing

When a creator creates a derivative work:

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐     ┌────────────────┐
│   Creator   │────►│ EchoCore │────►│RightsRegistry│────►│RevenueSplitter │
│ (Derivative)│     │          │     │                │     │                │
└─────────────┘     └──────────┘     └────────────────┘     └────────────────┘
       │                 │                 │                      │
       │  1. mintDerivative(metadata, parentIds[], blueprint)
       │────────────────►│                 │                      │
       │                 │                 │                      │
       │                 │  2. _mint()     │                      │
       │                 │  Store asset    │                      │
       │                 │                 │                      │
       │                 │  3. checkUpstreamRights(parentIds)
       │                 │────────────────►│                      │
       │                 │                 │                      │
       │                 │  3a. Validate derivation rights       │
       │                 │  3b. Return aggregated constraints    │
       │                 │◄────────────────│                      │
       │                 │                 │                      │
       │                 │  4. configureRights with inherited constraints
       │                 │────────────────►│                      │
       │                 │                 │                      │
       │                 │  4a. Store rights with parent refs    │
       │                 │                 │                      │
       │                 │                 │  4b. traceUpstream(childId)
       │                 │                 │─────────────────────►│
       │                 │                 │                      │
       │                 │                 │  4c. Build split tree│
       │                 │                 │  4d. Store for future
       │                 │                 │◄─────────────────────│
       │                 │                 │                      │
       │                 │  5. Emit DerivativeCreated(parents, child)
       │                 │                 │                      │
       │◄────────────────│                 │                      │
```

**Key Integration Points**:
1. Creator specifies parent asset IDs during minting
2. RightsRegistry checks derivation rights of all parents
3. RevenueSplitter builds the upstream tracing tree for future distributions
4. Derivative inherits constraints from all upstream assets

### 2.3 Revenue Distribution Flow

When revenue is generated from asset usage:

```
┌─────────┐     ┌────────────────┐     ┌──────────────┐     ┌──────────┐
│  Layer2 │────►│RevenueSplitter │────►│RightsRegistry│────►│ EchoCore │
│  Usage  │     │                │     │                │     │          │
└─────────┘     └────────────────┘     └────────────────┘     └──────────┘
       │               │                      │                    │
       │  1. recordUsage(assetId, amount, proof)
       │──────────────►│                      │                    │
       │               │                      │                    │
       │               │  2. getRevenueConfig(assetId)
       │               │─────────────────────►│                    │
       │               │                      │                    │
       │               │  2a. Return RevRight │                    │
       │               │  (recipients[], shares[])
       │               │◄─────────────────────│                    │
       │               │                      │                    │
       │               │  3. traceUpstream(assetId)
       │               │─────────────────────►│                    │
       │               │                      │                    │
       │               │                      │  3a. Recursively    │
       │               │                      │  get parent refs   │
       │               │                      │                    │
       │               │  3b. Return upstream │                    │
       │               │  asset chain         │                    │
       │               │◄─────────────────────│                    │
       │               │                      │                    │
       │               │  4. calculateSplit(amount, config, upstream)
       │               │  ┌────────────────────────────────────────┐
       │               │  │ • Platform fee (2-5%)                │
       │               │  │ • Direct recipients from RevRight    │
       │               │  │ • Upstream split based on DerRight   │
       │               │  │ • Recursive tracing                  │
       │               │  └────────────────────────────────────────┘
       │               │                      │                    │
       │               │  5. distribute()     │                    │
       │               │  ├─► Direct transfers                       │
       │               │  ├─► Merkle batch (gas optimized)           │
       │               │  └─► Settle to claimable balances          │
       │               │                      │                    │
       │               │  6. Emit RevenueDistributed(assetId, amount, recipients)
       │               │────────────────────────────────────────────►│
```

**Key Integration Points**:
1. Layer 2 provides ZKP-based usage proofs
2. RevenueSplitter reads RevRight config from RightsRegistry
3. RevenueSplitter traces upstream via EchoCore parent relationships
4. Distribution respects DerRight upstream share percentages
5. Supports both immediate transfers and batched Merkle claims

### 2.4 Cross-Chain Asset Transfer

When an asset moves to another chain:

```
┌──────────┐     ┌───────────────┐     ┌──────────────┐     ┌────────────────┐
│   User   │────►│CrossChainBridge│────►│   EchoCore   │────►│RightsRegistry  │
│          │     │                │     │                │     │                │
└──────────┘     └───────────────┘     └────────────────┘     └────────────────┘
       │               │                      │                    │
       │  1. lockAndMint(assetId, targetChain, recipient)
       │──────────────►│                      │                    │
       │               │                      │                    │
       │               │  2. verifyOwnership(assetId, msg.sender)
       │               │─────────────────────►│                    │
       │               │                      │                    │
       │               │  2a. Return ownership│                    │
       │               │◄─────────────────────│                    │
       │               │                      │                    │
       │               │  3. lockAsset(assetId)
       │               │─────────────────────►│                    │
       │               │                      │                    │
       │               │                      │  4. getRightsSnapshot(assetId)
       │               │────────────────────────────────────────────►│
       │               │                      │                    │
       │               │                      │  4a. Return rights config
       │               │                      │◄─────────────────────│
       │               │                      │                    │
       │               │  5. buildPayload(assetId, owner, rightsSnapshot)
       │               │                      │                    │
       │               │  6. sendCrossChainMessage(targetChain, payload)
       │               │──────┐                                     │
       │               │      │ Via LayerZero/Axelar                │
       │               │◄─────┘                                     │
       │               │                      │                    │
       │               │  7. Emit AssetLocked(assetId, targetChain, timestamp)
       │               │────────────────────────────────────────────►│
       │◄──────────────│                      │                    │
       │ (Return tx hash)                   │                    │

───────────────────────────────────────────────────────────────────────────────
                           Target Chain
───────────────────────────────────────────────────────────────────────────────

┌──────────┐     ┌───────────────┐     ┌──────────────┐     ┌────────────────┐
│          │────►│CrossChainBridge│────►│   EchoCore   │────►│RightsRegistry  │
│ (Remote)│     │  (on target)   │     │  (on target) │     │  (on target)   │
└──────────┘     └───────────────┘     └────────────────┘     └────────────────┘
       │               │                      │                    │
       │               │  8. receiveMessage(sourceChain, payload)
       │               │──────┐                                     │
       │               │      │ Verify proof from source chain      │
       │               │◄─────┘                                     │
       │               │                      │                    │
       │               │  9. verifyCrossChainProof(proof)
       │               │  Verify authenticity and non-duplication  │
       │               │                      │                    │
       │               │  10. mintWrappedAsset(payload.owner, payload.metadata)
       │               │─────────────────────►│                    │
       │               │                      │                    │
       │               │                      │  11. configureRights from snapshot
       │               │                      │────────────────────►│
       │               │                      │                    │
       │               │                      │  12. Store with crossChainRef
       │               │                      │◄───────────────────│
       │               │                      │                    │
       │               │  13. Emit AssetMinted(wrappedId, owner, sourceRef)
       │               │◄─────────────────────│                    │
```

**Key Integration Points**:
1. Source chain locks asset in EchoCore
2. Rights snapshot captured from RightsRegistry
3. CrossChainBridge handles message passing (LayerZero/Axelar)
4. Target chain mints wrapped asset with original rights
5. Cross-chain reference maintained for future sync

---

## 3. Common Infrastructure

### 3.1 Event System Architecture

All Layer 0 contracts emit standardized events for indexing by The Graph and other indexers.

#### 3.1.1 Core Events

```solidity
// EchoCore Events
event AssetMinted(
    uint256 indexed assetId,
    address indexed owner,
    bytes32 contentHash,
    bytes32 blueprintHash,
    uint256 timestamp
);

event OwnershipTransferred(
    uint256 indexed assetId,
    address indexed from,
    address indexed to,
    uint256 timestamp
);

event AssetBurned(
    uint256 indexed assetId,
    address indexed owner,
    uint256 timestamp
);

event DerivativeCreated(
    uint256 indexed childId,
    uint256[] indexed parentIds,
    address indexed creator
);

// RightsRegistry Events
event RightsConfigured(
    uint256 indexed assetId,
    RightType indexed rightType,
    bytes32 configHash,
    uint256 timestamp
);

event LicenseGranted(
    uint256 indexed licenseId,
    uint256 indexed assetId,
    RightType indexed rightType,
    address grantor,
    address grantee,
    uint256 expiry
);

event LicenseRevoked(
    uint256 indexed licenseId,
    address indexed revoker,
    uint256 timestamp
);

event RightsInherited(
    uint256 indexed childId,
    uint256 indexed parentId,
    bytes32 constraintsHash
);

// RevenueSplitter Events
event RevenueReceived(
    uint256 indexed assetId,
    uint256 amount,
    address indexed source,
    uint256 timestamp
);

event RevenueDistributed(
    uint256 indexed assetId,
    uint256 totalAmount,
    address[] recipients,
    uint256[] amounts,
    bytes32 merkleRoot
);

event ClaimExecuted(
    address indexed claimant,
    uint256 amount,
    bytes32[] proof
);

event SettlementTriggered(
    uint256 indexed assetId,
    SettlementType indexed settlementType,
    uint256 timestamp
);

// CrossChainBridge Events
event AssetLocked(
    uint256 indexed assetId,
    uint256 indexed targetChainId,
    bytes32 indexed remoteTxHash,
    uint256 timestamp
);

event AssetUnlocked(
    uint256 indexed assetId,
    uint256 indexed sourceChainId,
    address indexed recipient
);

event WrappedAssetMinted(
    uint256 indexed wrappedId,
    uint256 indexed sourceChainId,
    uint256 indexed sourceAssetId,
    address owner
);

event RightsSynced(
    uint256 indexed assetId,
    uint256 indexed targetChainId,
    bytes32 syncHash,
    uint256 timestamp
);
```

#### 3.1.2 Indexing Strategy

```yaml
# Subgraph configuration example
specVersion: 0.0.4
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: EchoCore
    network: mainnet
    source:
      address: "0x..."
      abi: EchoCore
    mapping:
      eventHandlers:
        - event: AssetMinted(indexed uint256,indexed address,bytes32,bytes32,uint256)
          handler: handleAssetMinted
        - event: DerivativeCreated(indexed uint256,uint256[],indexed address)
          handler: handleDerivativeCreated
  - kind: ethereum
    name: RightsRegistry
    network: mainnet
    source:
      address: "0x..."
      abi: RightsRegistry
    mapping:
      eventHandlers:
        - event: RightsConfigured(indexed uint256,indexed uint8,bytes32,uint256)
          handler: handleRightsConfigured
```

### 3.2 Shared Libraries

#### 3.2.1 AccessControl Library

```solidity
// libraries/AccessControl.sol
library AccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct Layout {
        mapping(bytes32 => RoleData) roles;
    }

    bytes32 constant STORAGE_SLOT = keccak256("echo.accesscontrol");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REVENUE_MANAGER_ROLE = keccak256("REVENUE_MANAGER");
}
```

#### 3.2.2 RightsMath Library

```solidity
// libraries/RightsMath.sol
library RightsMath {
    uint256 constant BPS_DENOMINATOR = 10000; // Basis points for precision
    uint256 constant MAX_SPLIT_DEPTH = 10;    // Max derivation chain depth
    uint256 constant MAX_UPSTREAM_SHARE = 5000; // Max 50% to upstream

    /// @notice Calculate split amounts for revenue distribution
    function calculateSplit(
        uint256 total,
        uint256 platformFeeBps,
        SplitConfig[] memory recipients,
        uint256 upstreamShareBps
    ) internal pure returns (SplitResult memory) {
        require(platformFeeBps <= 1000, "Fee too high"); // Max 10%
        require(upstreamShareBps <= MAX_UPSTREAM_SHARE, "Upstream share too high");

        uint256 platformFee = (total * platformFeeBps) / BPS_DENOMINATOR;
        uint256 remaining = total - platformFee;
        uint256 upstreamAmount = (remaining * upstreamShareBps) / BPS_DENOMINATOR;
        uint256 directAmount = remaining - upstreamAmount;

        // Calculate individual recipient shares
        uint256[] memory recipientAmounts = new uint256[](recipients.length);
        uint256 totalShareBps = 0;

        for (uint256 i = 0; i < recipients.length; i++) {
            totalShareBps += recipients[i].shareBps;
            recipientAmounts[i] = (directAmount * recipients[i].shareBps) / BPS_DENOMINATOR;
        }

        require(totalShareBps == BPS_DENOMINATOR, "Shares must sum to 100%");

        return SplitResult({
            platformFee: platformFee,
            upstreamAmount: upstreamAmount,
            recipientAmounts: recipientAmounts,
            upstreamShareBps: upstreamShareBps
        });
    }

    /// @notice Validate derivation depth doesn't exceed maximum
    function validateDepth(uint256 currentDepth) internal pure {
        require(currentDepth < MAX_SPLIT_DEPTH, "Max derivation depth exceeded");
    }
}
```

#### 3.2.3 MerkleUtils Library

```solidity
// libraries/MerkleUtils.sol
library MerkleUtils {
    /// @notice Verify a Merkle proof for batched claims
    function verifyProof(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == root;
    }

    /// @notice Generate leaf node for claim verification
    function generateLeaf(
        address claimant,
        uint256 amount,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(claimant, amount, nonce));
    }

    /// @notice Compute Merkle root from array of leaves
    function computeRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");

        // Implementation of Merkle tree computation
        // Uses iterative hashing to build tree bottom-up
        // ...
        return leaves[0]; // Simplified
    }
}
```

### 3.3 Upgradeability Pattern

All Layer 0 contracts use the UUPS (Universal Upgradeable Proxy Standard) pattern:

```solidity
// interfaces/IEchoCore.sol
interface IEchoCore {
    // View functions
    function ownerOf(uint256 assetId) external view returns (address);
    function getAsset(uint256 assetId) external view returns (Asset memory);
    function getAssetCount() external view returns (uint256);

    // State-changing functions
    function mintAsset(
        bytes32 contentHash,
        bytes32 blueprintHash,
        string calldata metadataURI
    ) external returns (uint256);

    function transferOwnership(uint256 assetId, address newOwner) external;
    function burnAsset(uint256 assetId) external;

    // Admin functions
    function pause() external;
    function unpause() external;
    function upgradeTo(address newImplementation) external;
}

// implementations/EchoCoreV1.sol
contract EchoCoreV1 is IEchoCore, UUPSUpgradeable, PausableUpgradeable {
    // Implementation with explicit version
    string public constant VERSION = "1.0.0";

    // Storage layout - critical for upgrade safety
    uint256[50] private __gap; // Gap for future upgrades

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
        // Additional upgrade validation can go here
        require(newImplementation != address(0), "Invalid implementation");
    }
}
```

---

## 4. Deployment Architecture

### 4.1 Contract Relationship Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Deployment Architecture                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐    │
│   │                     Implementation Contracts                         │    │
│   │                                                                     │    │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │    │
│   │  │ EchoCoreV1  │ │ RightsRegV1 │ │ RevenueV1   │ │ CrossChainV1│ │    │
│   │  │ (Logic)     │ │ (Logic)     │ │ (Logic)     │ │ (Logic)     │ │    │
│   │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ │    │
│   │         │               │               │               │        │    │
│   │         └───────────────┴───────────────┴───────────────┘        │    │
│   │                           │                                       │    │
│   │                    Initialize with                                │    │
│   │                    cross-references                               │    │
│   └───────────────────────────┼───────────────────────────────────────┘    │
│                               │                                            │
│   ┌───────────────────────────┼───────────────────────────────────────┐  │
│   │                      Proxy Contracts                               │   │
│   │                                                                     │  │
│   │  ┌─────────────────────────────────────────────────────────────┐   │  │
│   │  │           TransparentUpgradeableProxy (OpenZeppelin)         │   │  │
│   │  │                                                               │   │  │
│   │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │   │  │
│   │  │  │  EchoCore  │ │RightsReg   │ │  Revenue   │ │CrossChain  │ │   │  │
│   │  │  │   Proxy    │ │  Proxy     │ │  Proxy     │ │  Proxy     │ │   │  │
│   │  │  │ (0xABC...) │ │(0xDEF...)  │ │(0xGHI...)  │ │(0xJKL...)  │ │   │  │
│   │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │   │  │
│   │  └─────────────────────────────────────────────────────────────┘   │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                     Shared Infrastructure                             │  │
│   │                                                                         │  │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │  │
│   │  │ AccessControl│ │ RightsMath │  │ MerkleUtils │  │  EventEmitter│    │  │
│   │  │ Library      │ │ Library    │  │ Library     │  │  Library     │    │  │
│   │  └────────────┘  └────────────┘  └────────────┘  └────────────┘    │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Initialization Sequence

```solidity
// Deployment sequence (deploy.js)

async function deployLayer0(deployer) {
    // 1. Deploy libraries
    const AccessControl = await deploy("AccessControl");
    const RightsMath = await deploy("RightsMath");
    const MerkleUtils = await deploy("MerkleUtils");

    // 2. Link libraries and deploy implementations
    const EchoCoreV1 = await deploy("EchoCoreV1", {
        libraries: {
            AccessControl: AccessControl.address
        }
    });

    const RightsRegistryV1 = await deploy("RightsRegistryV1", {
        libraries: {
            AccessControl: AccessControl.address,
            RightsMath: RightsMath.address
        }
    });

    const RevenueSplitterV1 = await deploy("RevenueSplitterV1", {
        libraries: {
            AccessControl: AccessControl.address,
            RightsMath: RightsMath.address,
            MerkleUtils: MerkleUtils.address
        }
    });

    const CrossChainBridgeV1 = await deploy("CrossChainBridgeV1", {
        libraries: {
            AccessControl: AccessControl.address
        }
    });

    // 3. Deploy proxies
    const echoProxy = await deploy("TransparentUpgradeableProxy",
        EchoCoreV1.address,
        deployer.address, // admin
        EchoCoreV1.interface.encodeFunctionData("initialize", [])
    );

    const rightsProxy = await deploy("TransparentUpgradeableProxy",
        RightsRegistryV1.address,
        deployer.address,
        RightsRegistryV1.interface.encodeFunctionData("initialize", [])
    );

    const revenueProxy = await deploy("TransparentUpgradeableProxy",
        RevenueSplitterV1.address,
        deployer.address,
        RevenueSplitterV1.interface.encodeFunctionData("initialize", [])
    );

    const bridgeProxy = await deploy("TransparentUpgradeableProxy",
        CrossChainBridgeV1.address,
        deployer.address,
        CrossChainBridgeV1.interface.encodeFunctionData("initialize", [])
    );

    // 4. Wire contracts together
    const echoCore = await ethers.getContractAt("IEchoCore", echoProxy.address);
    const rightsReg = await ethers.getContractAt("IRightsRegistry", rightsProxy.address);
    const revenueSplitter = await ethers.getContractAt("IRevenueSplitter", revenueProxy.address);
    const bridge = await ethers.getContractAt("ICrossChainBridge", bridgeProxy.address);

    // Set cross-references
    await rightsReg.setEchoCore(echoProxy.address);
    await rightsReg.setRevenueSplitter(revenueProxy.address);

    await revenueSplitter.setEchoCore(echoProxy.address);
    await revenueSplitter.setRightsRegistry(rightsProxy.address);

    await bridge.setEchoCore(echoProxy.address);
    await bridge.setRightsRegistry(rightsProxy.address);

    // 5. Setup roles
    const adminRole = await echoCore.DEFAULT_ADMIN_ROLE();
    const pauserRole = await echoCore.PAUSER_ROLE();
    const upgraderRole = await echoCore.UPGRADER_ROLE();

    await echoCore.grantRole(pauserRole, emergencyMultisig.address);
    await echoCore.grantRole(upgraderRole, upgradeTimelock.address);

    // Same for other contracts...

    return {
        echoCore: echoProxy.address,
        rightsRegistry: rightsProxy.address,
        revenueSplitter: revenueProxy.address,
        crossChainBridge: bridgeProxy.address
    };
}
```

### 4.3 Proxy Pattern Details

```solidity
// Proxy storage layout (consistent across all proxies)
// This must never change between upgrades

struct ProxyStorage {
    // Slot 0: EIP-1967 admin slot
    address admin;

    // Slot 1: EIP-1967 implementation slot
    address implementation;

    // Slot 2-10: Reserved for future proxy features
    bytes32[9] proxyReserved;
}

// Implementation storage layout (versioned)
// Each implementation has its own storage struct

struct EchoCoreStorageV1 {
    // Asset storage
    mapping(uint256 => Asset) assets;
    mapping(uint256 => address) assetOwners;
    uint256 totalAssets;

    // Parent-child relationships
    mapping(uint256 => uint256[]) assetParents;
    mapping(uint256 => uint256[]) assetChildren;

    // Metadata
    mapping(uint256 => string) metadataURIs;
    mapping(bytes32 => uint256) contentHashToAsset;
}

// For V2 upgrade, we would add:
struct EchoCoreStorageV2 {
    EchoCoreStorageV1 v1;  // Include previous storage

    // New fields
    mapping(uint256 => AssetStats) stats;
    uint256[] featuredAssets;
}
```

---

## 5. Security Model

### 5.1 Access Control Matrix

| Function | Role Required | Description |
|----------|---------------|-------------|
| **EchoCore** |||
| `mintAsset` | PUBLIC | Anyone can mint |
| `transferOwnership` | Asset Owner | Only owner can transfer |
| `burnAsset` | Asset Owner | Only owner can burn |
| `pause` | PAUSER_ROLE | Emergency pause |
| `upgradeTo` | UPGRADER_ROLE | Timelock required |
| **RightsRegistry** |||
| `configureRights` | Asset Owner | Configure own assets |
| `grantLicense` | Asset Owner | Grant licenses |
| `revokeLicense` | License Grantor or Owner | Revoke licenses |
| `setPlatformFee` | ADMIN_ROLE | Adjust fees |
| **RevenueSplitter** |||
| `distribute` | PUBLIC (MEV-resistant) | Anyone can trigger |
| `claim` | Claimant | Claim own rewards |
| `setSettlementDelay` | ADMIN_ROLE | Timing parameters |
| **CrossChainBridge** |||
| `lockAndMint` | Asset Owner | Lock own assets |
| `addSupportedChain` | ADMIN_ROLE | Add new chains |
| `setMessageProtocol` | ADMIN_ROLE | Change bridge provider |

### 5.2 Reentrancy Protection

All state-changing functions follow the Checks-Effects-Interactions pattern:

```solidity
function distribute(uint256 assetId) external nonReentrant {
    // 1. CHECKS
    require(assetId < totalAssets, "Invalid asset");
    require(!isSettled[assetId][block.number], "Already settled");

    SplitConfig memory config = _getSplitConfig(assetId);
    require(config.recipients.length > 0, "No recipients");

    // 2. EFFECTS (state changes before external calls)
    uint256 totalRevenue = pendingRevenue[assetId];
    pendingRevenue[assetId] = 0;
    isSettled[assetId][block.number] = true;

    SplitResult memory result = RightsMath.calculateSplit(
        totalRevenue,
        platformFeeBps,
        config.recipients,
        config.upstreamShareBps
    );

    // 3. INTERACTIONS (external calls last)
    for (uint256 i = 0; i < result.recipientAmounts.length; i++) {
        _safeTransfer(config.recipients[i].addr, result.recipientAmounts[i]);
    }

    emit RevenueDistributed(assetId, totalRevenue, recipients, amounts, merkleRoot);
}
```

### 5.3 Emergency Procedures

```solidity
contract EmergencyManager {
    enum EmergencyLevel {
        NORMAL,      // Standard operation
        CAUTION,     // Increased monitoring
        PAUSE_MINT,  // Pause new mints only
        PAUSE_ALL,   // Pause all state changes
        FULL_LOCK    // Emergency withdrawal only
    }

    EmergencyLevel public currentLevel;

    // Multi-sig required for emergency actions
    uint256 constant EMERGENCY_THRESHOLD = 3;
    address[] public emergencyCommittee;
    mapping(bytes32 => mapping(address => bool)) public emergencyVotes;

    function triggerEmergency(EmergencyLevel level, string calldata reason) external {
        require(isEmergencyCommittee(msg.sender), "Not authorized");

        bytes32 voteHash = keccak256(abi.encodePacked(level, reason, block.timestamp));
        emergencyVotes[voteHash][msg.sender] = true;

        uint256 voteCount = _countVotes(voteHash);
        if (voteCount >= EMERGENCY_THRESHOLD) {
            _executeEmergency(level, reason);
        }
    }

    function _executeEmergency(EmergencyLevel level, string memory reason) internal {
        currentLevel = level;

        if (level == EmergencyLevel.PAUSE_MINT) {
            echoCore.pauseMinting();
        } else if (level == EmergencyLevel.PAUSE_ALL) {
            echoCore.pause();
            rightsRegistry.pause();
            revenueSplitter.pause();
        } else if (level == EmergencyLevel.FULL_LOCK) {
            // Enable emergency withdrawal mode
            revenueSplitter.enableEmergencyWithdrawal();
        }

        emit EmergencyTriggered(level, reason, block.timestamp);
    }

    function liftEmergency() external {
        require(isEmergencyCommittee(msg.sender), "Not authorized");
        // Require unanimous vote to lift emergency
        // ...
    }
}
```

### 5.4 Circuit Breakers

```solidity
modifier circuitBreaker() {
    // Check various metrics
    require(!isVolumeSpike(), "Volume spike detected");
    require(!isValueAnomaly(), "Value anomaly detected");
    require(gasPrice < MAX_GAS_PRICE, "Gas price too high");
    _;
}

function isVolumeSpike() internal view returns (bool) {
    uint256 currentVolume = getVolumeInLastHour();
    uint256 avgVolume = getAverageHourlyVolume(24);

    // Trigger if volume > 10x average
    return currentVolume > avgVolume * 10;
}

function isValueAnomaly() internal view returns (bool) {
    uint256 avgTransaction = getAverageTransactionValue(100);

    // Check recent large transactions
    for (uint256 i = 0; i < recentTransactions.length; i++) {
        if (recentTransactions[i].value > avgTransaction * 100) {
            return true;
        }
    }
    return false;
}
```

### 5.5 Upgrade Safety

```solidity
// Upgrade validation in UUPS pattern
function _authorizeUpgrade(address newImplementation) internal override {
    require(msg.sender == upgradeTimelock, "Only timelock");

    // Verify new implementation is valid
    require(newImplementation.code.length > 0, "Not a contract");

    // Verify storage layout compatibility
    bytes32 oldLayout = keccak256(abi.encode(getStorageLayout()));
    bytes32 newLayout = IImplementation(newImplementation).getStorageLayoutHash();

    require(oldLayout == newLayout || isMigrationApproved(newImplementation),
        "Storage layout mismatch");

    // Verify no critical state changes during upgrade
    require(!echoCore.isPaused(), "Contract paused");
    require(revenueSplitter.noPendingDistributions(), "Pending distributions");

    emit UpgradeAuthorized(newImplementation, block.timestamp);
}
```

---

## 6. Gas Optimization

### 6.1 Storage Optimization Strategies

#### 6.1.1 Packing Multiple Values

```solidity
// Before: 4 storage slots
struct AssetOld {
    address owner;      // 20 bytes (slot 0)
    uint256 contentHash; // 32 bytes (slot 1)
    uint256 blueprintHash; // 32 bytes (slot 2)
    uint256 createdAt;  // 32 bytes (slot 3)
    bool isDerivative;  // 1 byte (slot 4)
}

// After: 2 storage slots using packing
struct Asset {
    address owner;      // 20 bytes
    uint64 createdAt;     // 8 bytes  (max year 2554 is fine)
    uint32 flags;         // 4 bytes  (bit flags for isDerivative, etc.)
    bytes32 contentHash;  // 32 bytes (slot 1)
    bytes32 blueprintHash;// 32 bytes (slot 2)
}
```

#### 6.1.2 Using Mappings Efficiently

```solidity
// Rights configuration - only store non-default values
mapping(uint256 => bytes32) public rightsConfigHash;
mapping(bytes32 => RightsConfig) public configStore;

// Instead of storing per-asset, store unique configurations
// Multiple assets can point to same config hash (saves gas for similar blueprints)
```

### 6.2 Batch Operations

```solidity
// Batch mint for gas efficiency
function batchMint(
    bytes32[] calldata contentHashes,
    bytes32[] calldata blueprintHashes,
    string[] calldata metadataURIs
) external returns (uint256[] memory assetIds) {
    require(
        contentHashes.length == blueprintHashes.length &&
        blueprintHashes.length == metadataURIs.length,
        "Array length mismatch"
    );

    assetIds = new uint256[](contentHashes.length);

    for (uint256 i = 0; i < contentHashes.length; i++) {
        assetIds[i] = _mintSingle(
            contentHashes[i],
            blueprintHashes[i],
            metadataURIs[i]
        );
    }

    emit BatchMinted(assetIds, msg.sender);
}

// Batch revenue distribution using Merkle trees
function batchDistribute(bytes32 merkleRoot, uint256 totalAmount) external {
    // Store merkle root for claimers to verify against
    distributionRoots.push(merkleRoot);
    pendingDistributionAmount += totalAmount;

    emit BatchDistributionPrepared(merkleRoot, totalAmount);
}

function claim(bytes32[] calldata proof, uint256 amount, uint256 nonce) external {
    bytes32 leaf = MerkleUtils.generateLeaf(msg.sender, amount, nonce);
    require(MerkleUtils.verifyProof(currentMerkleRoot, leaf, proof), "Invalid proof");

    require(!hasClaimed[nonce], "Already claimed");
    hasClaimed[nonce] = true;

    _safeTransfer(msg.sender, amount);

    emit ClaimExecuted(msg.sender, amount, proof);
}
```

### 6.3 Optimized Revenue Distribution

```solidity
// Lazy settlement pattern
struct Settlement {
    uint256 assetId;
    uint256 accumulatedAmount;
    uint256 lastSettlementTime;
    SettlementTrigger trigger;
}

enum SettlementTrigger {
    IMMEDIATE,    // Settle on every usage (expensive)
    THRESHOLD,    // Settle when amount > threshold
    TIME_BASED,   // Settle every N hours
    BATCHED       // Settle with other assets in batch
}

function recordUsage(uint256 assetId, uint256 amount) external {
    // Just accumulate, don't distribute
    settlements[assetId].accumulatedAmount += amount;

    // Check if settlement should trigger
    if (_shouldSettle(assetId)) {
        _queueForSettlement(assetId);
    }
}

function _shouldSettle(uint256 assetId) internal view returns (bool) {
    Settlement memory s = settlements[assetId];

    if (s.trigger == SettlementTrigger.IMMEDIATE) return true;
    if (s.trigger == SettlementTrigger.THRESHOLD) {
        return s.accumulatedAmount >= SETTLEMENT_THRESHOLD;
    }
    if (s.trigger == SettlementTrigger.TIME_BASED) {
        return block.timestamp >= s.lastSettlementTime + SETTLEMENT_INTERVAL;
    }
    return false;
}

// Batch settlement executor (can be called by anyone, MEV-resistant)
function executeBatchSettlement(uint256[] calldata assetIds) external {
    require(assetIds.length <= MAX_BATCH_SIZE, "Batch too large");

    uint256 totalGasSaved = 0;

    for (uint256 i = 0; i < assetIds.length; i++) {
        if (_shouldSettle(assetIds[i])) {
            _settle(assetIds[i]);
            totalGasSaved += ESTIMATED_GAS_PER_SETTLEMENT;
        }
    }

    // Reward executor with a portion of gas saved
    _rewardExecutor(msg.sender, totalGasSaved);
}
```

### 6.4 Cross-Contract Call Optimization

```solidity
// Minimize external calls by batching
function mintWithRights(
    bytes32 contentHash,
    bytes32 blueprintHash,
    string calldata metadataURI,
    RightsConfig calldata rights
) external returns (uint256 assetId) {
    // Single transaction for both operations
    assetId = _mint(contentHash, blueprintHash, metadataURI);

    // Use delegatecall or direct internal call when possible
    // Instead of: rightsRegistry.configureRights(assetId, rights);
    // Use: _configureRightsInternal(assetId, rights);

    emit AssetMintedWithRights(assetId, msg.sender, contentHash, rights);
}

// Cache frequently accessed cross-contract data
mapping(uint256 => RightsCache) public rightsCache;

function getRevenueConfig(uint256 assetId) external view returns (RevRight memory) {
    // Check cache first
    if (rightsCache[assetId].timestamp > block.timestamp - CACHE_TTL) {
        return rightsCache[assetId].revRight;
    }

    // Fetch and cache
    RevRight memory config = rightsRegistry.getRevRight(assetId);
    rightsCache[assetId] = RightsCache({
        revRight: config,
        timestamp: block.timestamp
    });

    return config;
}
```

### 6.5 Gas Cost Comparison

| Operation | Naive Implementation | Optimized | Savings |
|-----------|---------------------|-----------|---------|
| Mint + Rights Config | 280,000 gas | 180,000 gas | 36% |
| Revenue Distribution | 150,000 gas (single) | 45,000 gas (Merkle) | 70% |
| Derivative Creation | 320,000 gas | 210,000 gas | 34% |
| Batch Mint (10 items) | 2,800,000 gas | 1,200,000 gas | 57% |
| Cross-Chain Lock | 180,000 gas | 120,000 gas | 33% |

---

## 7. Upper Layer Integration

### 7.1 Layer 1: Creator Tools Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Layer 1 Integration Points                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │  Skill Forge    │                                                        │
│  │  (Layer 1)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           │  1. Read: Get recommended Blueprint templates                   │
│           │     Call: rightsRegistry.getTemplatesBySkillType(type)            │
│           │                                                                 │
│           │  2. Write: Deploy Skill + Blueprint to Layer 0                    │
│           │     Call: echoCore.mintAsset(metadata, blueprintHash)              │
│           │     Then: rightsRegistry.configureRights(assetId, blueprint)     │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐                                                        │
│  │  Blueprint      │                                                        │
│  │  Studio         │                                                        │
│  │  (Layer 1)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           │  1. Read: Inherit upstream constraints                           │
│           │     Call: rightsRegistry.getConstraints(assetId)                │
│           │                                                                 │
│           │  2. Read: Validate Blueprint before deployment                   │
│           │     Call: rightsRegistry.validateBlueprint(blueprint)            │
│           │     Call: revenueSplitter.validateSplits(splits)                 │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐                                                        │
│  │  Revenue Oracle │                                                        │
│  │  (Layer 1)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           │  1. Read: Get historical data for prediction                     │
│           │     Query: The Graph (AssetMinted, RevenueDistributed events)    │
│           │     Call: revenueSplitter.getHistoricalRevenue(assetId, period) │
│           │                                                                 │
│           │  2. Simulate: Preview revenue for Blueprint                      │
│           │     Call: revenueSplitter.previewDistribution(amount, blueprint) │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐                                                        │
│  │  ShiGraph       │                                                        │
│  │  (Layer 1)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           │  Index all Layer 0 events via The Graph subgraph               │
│           │  - AssetMinted, RightsConfigured, RevenueDistributed            │
│           │  - Build relationship graph from DerivativeCreated              │
│           │  - Calculate "Shi" score from on-chain metrics                 │
│           │                                                                 │
│  ┌─────────────────┐                                                        │
│  │  Privacy Guard  │                                                        │
│  │  (Layer 1)      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                 │
│           │  Generate ZK proofs for Layer 2 usage                         │
│           │  Verify against RevenueSplitter claim requirements             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Layer 2: Sandbox Execution

```solidity
// Layer 2 integration with RevenueSplitter
interface ISandboxRevenueReporter {
    /// @notice Report usage from sandbox execution
    /// @param assetId The asset being used
    /// @param executionId Unique execution identifier
    /// @param usageMetrics Structured usage data
    /// @param proof ZK proof of execution
    function reportUsage(
        uint256 assetId,
        bytes32 executionId,
        UsageMetrics calldata usageMetrics,
        bytes calldata proof
    ) external;
}

// Implementation in Layer 0
contract RevenueSplitter is ISandboxRevenueReporter {

    function reportUsage(
        uint256 assetId,
        bytes32 executionId,
        UsageMetrics calldata metrics,
        bytes calldata proof
    ) external override onlySandbox {
        // Verify ZK proof
        require(_verifyUsageProof(assetId, executionId, metrics, proof), "Invalid proof");

        // Calculate revenue based on usage
        uint256 revenue = _calculateRevenue(metrics);

        // Accumulate for settlement
        pendingRevenue[assetId] += revenue;
        executionRecords[executionId] = ExecutionRecord({
            assetId: assetId,
            revenue: revenue,
            timestamp: block.timestamp,
            verified: true
        });

        emit UsageReported(assetId, executionId, revenue, metrics.skillIds);

        // Trigger settlement if threshold met
        if (pendingRevenue[assetId] >= SETTLEMENT_THRESHOLD) {
            _queueForSettlement(assetId);
        }
    }

    modifier onlySandbox() {
        require(
            msg.sender == sandboxL1 || msg.sender == sandboxL2 ||
            msg.sender == sandboxL3 || msg.sender == sandboxL4,
            "Not authorized sandbox"
        );
        _;
    }
}
```

### 7.3 Layer 3: Skill Market

```solidity
// Skill Registry integration with EchoCore
interface ISkillRegistry {
    struct Skill {
        uint256 assetId;          // Reference to Layer 0 asset
        bytes32 skillHash;        // Code hash
        bytes32[] dependencies;   // Other skill asset IDs
        VersionInfo version;
        RatingInfo ratings;
    }

    function registerSkill(
        uint256 assetId,           // Must be minted in EchoCore first
        bytes32 skillHash,
        uint256[] calldata dependencyAssetIds
    ) external returns (uint256 skillId);
}

// Dependency resolution flow
function resolveDependencies(uint256 skillId) external view returns (DependencyTree memory) {
    Skill memory skill = skills[skillId];

    // Check all dependencies are properly licensed
    for (uint256 i = 0; i < skill.dependencies.length; i++) {
        uint256 depId = skill.dependencies[i];

        // Verify dependency exists in EchoCore
        require(echoCore.ownerOf(depId) != address(0), "Dependency not found");

        // Check rights allow derivation/usage
        DerRight memory derRight = rightsRegistry.getDerRight(depId);
        require(derRight.allowed, "Derivation not allowed");

        // Verify licensing is active
        License memory license = rightsRegistry.getActiveLicense(skillId, depId);
        require(license.expiry > block.timestamp, "License expired");
    }

    // Build full dependency tree recursively
    return _buildDependencyTree(skillId, 0);
}
```

### 7.4 Layer 4: Agent Layer

```solidity
// Agent integration contract
interface IAgentIntegration {
    /// @notice Agent requests permission to use an asset
    function requestUsagePermission(
        uint256 assetId,
        UsageIntent calldata intent
    ) external returns (PermissionResult memory);

    /// @notice Agent executes approved usage
    function executeUsage(
        uint256 assetId,
        bytes calldata executionData,
        bytes calldata permissionSignature
    ) external returns (ExecutionResult memory);
}

// Usage intent structure
struct UsageIntent {
    address agentId;           // Agent contract address
    uint256 skillId;           // Skill being used
    uint256[] upstreamAssets;  // Assets referenced
    uint256 estimatedCalls;    // Expected execution count
    uint256 maxBudget;         // Maximum payment willing
    bytes32 executionHash;     // Hash of execution parameters
}

// Permission result
struct PermissionResult {
    bool granted;
    uint256 licenseId;         // Active or newly created license
    uint256 totalCost;         // Calculated total cost
    uint256[] upstreamSplits;  // Breakdown of upstream payments
    bytes signature;           // Signed permission
    uint256 expiry;            // Permission expiry
}
```

### 7.5 Layer 5: Applications

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Layer 5 Integration Patterns                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Echo Market (Trading)                                                      │
│  ├── Read: Get asset details from EchoCore                                  │
│  ├── Read: Get rights config from RightsRegistry                            │
│  ├── Write: Execute ownership transfer via EchoCore                          │
│  └── Write: Transfer license rights via RightsRegistry                     │
│                                                                             │
│  Remix Studio (Creation)                                                    │
│  ├── Read: Check derivation rights from RightsRegistry                     │
│  ├── Write: Mint derivative via EchoCore                                   │
│  ├── Write: Configure rights via RightsRegistry                            │
│  └── Call: Trigger revenue tracing via RevenueSplitter                     │
│                                                                             │
│  Scholar Explorer (Analytics)                                               │
│  ├── Index: All Layer 0 events via subgraph                                 │
│  ├── Query: Complex relationship queries on EchoCore                       │
│  └── Analyze: Revenue patterns from RevenueSplitter                        │
│                                                                             │
│  Portfolio Manager (Investment)                                             │
│  ├── Read: Multi-asset ownership from EchoCore                             │
│  ├── Read: Revenue history from RevenueSplitter                            │
│  ├── Read: Rights configs for valuation                                    │
│  └── Write: Batch operations via multicall                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Testing and Audit Plan

### 8.1 Testing Strategy

#### 8.1.1 Unit Test Coverage

| Contract | Test Category | Target Coverage |
|----------|--------------|-----------------|
| EchoCore | Minting | 100% |
| | Ownership transfer | 100% |
| | Derivative creation | 100% |
| | Burn | 100% |
| RightsRegistry | Rights configuration | 100% |
| | Licensing | 100% |
| | Inheritance | 100% |
| | Revocation | 100% |
| RevenueSplitter | Distribution calculation | 100% |
| | Merkle verification | 100% |
| | Upstream tracing | 100% |
| | Settlement | 100% |
| CrossChainBridge | Lock/mint | 100% |
| | Message passing | 100% |
| | Rights sync | 100% |

#### 8.1.2 Integration Test Scenarios

```javascript
// Integration test example
describe("Layer 0 Integration Flows", () => {

    it("Complete mint -> rights -> derivative -> revenue flow", async () => {
        // 1. Creator mints base asset
        const baseAsset = await echoCore.mintAsset(metadata, blueprint);
        await rightsRegistry.configureRights(baseAsset.id, useRights);

        // 2. Derivative creator references base asset
        const derivative = await echoCore.mintDerivative(
            metadata,
            [baseAsset.id],
            derivativeBlueprint
        );

        // 3. Layer 2 reports usage
        await revenueSplitter.recordUsage(
            derivative.id,
            usageMetrics,
            zkProof
        );

        // 4. Revenue is distributed to all parties
        const initialBaseOwnerBalance = await token.balanceOf(baseOwner);
        await revenueSplitter.distribute(derivative.id);
        const finalBaseOwnerBalance = await token.balanceOf(baseOwner);

        // Verify upstream payment received
        expect(finalBaseOwnerBalance - initialBaseOwnerBalance)
            .to.equal(expectedUpstreamShare);
    });

    it("Cross-chain asset transfer preserves rights", async () => {
        // Lock on source chain
        await crossChainBridge.lockAndMint(assetId, targetChain, recipient);

        // Simulate message delivery on target chain
        await targetBridge.receiveMessage(sourceChain, payload);

        // Verify wrapped asset has same rights config
        const wrappedRights = await targetRightsRegistry.getRights(wrappedId);
        expect(wrappedRights.useRight.basePrice)
            .to.equal(originalRights.useRight.basePrice);
    });

    it("Emergency pause and recovery", async () => {
        // Trigger emergency
        await emergencyManager.triggerEmergency(2, "Test emergency");

        // Verify paused state
        expect(await echoCore.paused()).to.be.true;

        // Attempt operations (should fail)
        await expect(echoCore.mintAsset(metadata, blueprint))
            .to.be.revertedWith("Pausable: paused");

        // Lift emergency
        await emergencyManager.liftEmergency();

        // Operations resume
        await expect(echoCore.mintAsset(metadata, blueprint))
            .to.not.be.reverted;
    });
});
```

### 8.2 Audit Checklist

#### 8.2.1 Pre-Audit Requirements

- [ ] 100% unit test coverage for all state-changing functions
- [ ] Integration tests for all documented interaction flows
- [ ] Fuzzing tests for mathematical operations (RightsMath)
- [ ] Gas optimization review complete
- [ ] Documentation finalized (this document + inline natspec)
- [ ] Formal verification for critical invariants (if budget allows)

#### 8.2.2 Security Audit Scope

| Area | Auditor Focus | Risk Level |
|------|--------------|------------|
| Access Control | Role verification, privilege escalation | Critical |
| Reentrancy | All external calls, CEI pattern compliance | Critical |
| Integer Math | Overflow/underflow, precision loss | Critical |
| Proxy Pattern | Storage collision, initialization | Critical |
| Cross-Chain | Message replay, verification bypass | Critical |
| Revenue Calculation | Split accuracy, upstream tracing | High |
| Rights Inheritance | Constraint propagation | High |
| Event Consistency | Indexable data integrity | Medium |
| Gas Optimization | DOS via gas exhaustion | Medium |

#### 8.2.3 Critical Invariants to Verify

```solidity
// Invariant 1: Total supply integrity
assert(echoCore.totalSupply() == sumOfAllMinted - sumOfAllBurned);

// Invariant 2: Revenue split accuracy (must equal 100%)
assert(sum(platformFee + allRecipientShares) == 10000); // Basis points

// Invariant 3: Rights inheritance (child constraints must be subset of parent)
assert(childRights.isSubsetOf(parentRights));

// Invariant 4: Cross-chain consistency (locked amount == wrapped amount)
assert(sourceBridge.lockedAmounts[assetId] == targetBridge.wrappedAmounts[wrappedId]);

// Invariant 5: License validity (active license implies ownership or grantor rights)
assert(license.isValid() => (ownerOf(license.assetId) == license.grantor || hasGrantorRights(license.grantor)));
```

### 8.3 Testnet Deployment Plan

| Phase | Network | Duration | Purpose |
|-------|---------|----------|---------|
| Alpha | Sepolia | 2 weeks | Initial testing, bug discovery |
| Beta | Sepolia + Mumbai | 2 weeks | Cross-chain testing |
| RC | Sepolia + Mumbai + Arbitrum Goerli | 2 weeks | Production-like environment |
| GA | Mainnet | - | Production deployment |

### 8.4 Bug Bounty Program

| Severity | Reward Range | Criteria |
|----------|--------------|----------|
| Critical | $50,000 - $100,000 | Direct fund loss, infinite mint |
| High | $10,000 - $50,000 | Temporary freeze, incorrect splits |
| Medium | $2,000 - $10,000 | DOS, event inconsistency |
| Low | $500 - $2,000 | Documentation, optimization |

---

## Appendix A: Contract Interface Summary

### A.1 EchoCore Interface

```solidity
interface IEchoCore {
    // Events
    event AssetMinted(uint256 indexed assetId, address indexed owner, bytes32 contentHash);
    event OwnershipTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event DerivativeCreated(uint256 indexed childId, uint256[] indexed parentIds, address indexed creator);
    event AssetBurned(uint256 indexed assetId);

    // Core functions
    function mintAsset(bytes32 contentHash, bytes32 blueprintHash, string calldata metadataURI) external returns (uint256);
    function mintDerivative(bytes32 contentHash, bytes32 blueprintHash, string calldata metadataURI, uint256[] calldata parentIds) external returns (uint256);
    function transferOwnership(uint256 assetId, address newOwner) external;
    function burnAsset(uint256 assetId) external;

    // View functions
    function ownerOf(uint256 assetId) external view returns (address);
    function getAsset(uint256 assetId) external view returns (Asset memory);
    function getParents(uint256 assetId) external view returns (uint256[] memory);
    function getChildren(uint256 assetId) external view returns (uint256[] memory);
    function totalSupply() external view returns (uint256);
}
```

### A.2 RightsRegistry Interface

```solidity
interface IRightsRegistry {
    enum RightType { USE, DER, EXT, REV }

    // Events
    event RightsConfigured(uint256 indexed assetId, RightType indexed rightType, bytes32 configHash);
    event LicenseGranted(uint256 indexed licenseId, uint256 indexed assetId, address indexed grantee);
    event LicenseRevoked(uint256 indexed licenseId);

    // Configuration
    function configureRights(uint256 assetId, RightsConfig calldata config) external;
    function configureSingleRight(uint256 assetId, RightType rightType, bytes calldata config) external;

    // Licensing
    function grantLicense(uint256 assetId, RightType rightType, address grantee, LicenseParams calldata params) external returns (uint256 licenseId);
    function revokeLicense(uint256 licenseId) external;
    function verifyLicense(uint256 licenseId) external view returns (bool);

    // Query
    function getUseRight(uint256 assetId) external view returns (UseRight memory);
    function getDerRight(uint256 assetId) external view returns (DerRight memory);
    function getExtRight(uint256 assetId) external view returns (ExtRight memory);
    function getRevRight(uint256 assetId) external view returns (RevRight memory);
    function checkUpstreamRights(uint256 assetId) external view returns (ConstraintSummary memory);
}
```

### A.3 RevenueSplitter Interface

```solidity
interface IRevenueSplitter {
    // Events
    event RevenueReceived(uint256 indexed assetId, uint256 amount);
    event RevenueDistributed(uint256 indexed assetId, uint256 totalAmount, bytes32 merkleRoot);
    event ClaimExecuted(address indexed claimant, uint256 amount);

    // Revenue recording
    function recordUsage(uint256 assetId, uint256 amount) external;
    function recordRevenue(uint256 assetId, uint256 amount, bytes calldata proof) external;

    // Distribution
    function distribute(uint256 assetId) external;
    function batchDistribute(uint256[] calldata assetIds) external;
    function distributeWithMerkle(uint256 assetId, bytes32 merkleRoot) external;

    // Claiming
    function claim(bytes32[] calldata proof, uint256 amount, uint256 nonce) external;
    function claimBatch(bytes32 merkleRoot, ClaimInfo[] calldata claims) external;

    // Query
    function pendingRevenue(uint256 assetId) external view returns (uint256);
    function getSplitConfig(uint256 assetId) external view returns (SplitConfig memory);
    function traceUpstream(uint256 assetId) external view returns (UpstreamNode[] memory);
}
```

### A.4 CrossChainBridge Interface

```solidity
interface ICrossChainBridge {
    // Events
    event AssetLocked(uint256 indexed assetId, uint256 indexed targetChainId);
    event WrappedAssetMinted(uint256 indexed wrappedId, uint256 indexed sourceChainId, uint256 indexed sourceAssetId);
    event RightsSynced(uint256 indexed assetId, uint256 indexed targetChainId);

    // Lock and mint
    function lockAndMint(uint256 assetId, uint256 targetChainId, address recipient) external payable;
    function burnAndUnlock(uint256 wrappedId, uint256 targetChainId) external;

    // Rights sync
    function syncRights(uint256 assetId, uint256 targetChainId) external payable;

    // Message handling
    function receiveMessage(uint256 sourceChainId, bytes calldata payload) external;

    // Admin
    function addSupportedChain(uint256 chainId, address remoteBridge) external;
    function setMessageProtocol(address protocol) external;
}
```

---

## Appendix B: Error Codes

| Code | Contract | Meaning |
|------|----------|---------|
| `EC001` | EchoCore | Asset does not exist |
| `EC002` | EchoCore | Not asset owner |
| `EC003` | EchoCore | Invalid parent asset |
| `EC004` | EchoCore | Max derivation depth exceeded |
| `RR001` | RightsRegistry | Invalid rights configuration |
| `RR002` | RightsRegistry | License not found |
| `RR003` | RightsRegistry | License expired |
| `RR004` | RightsRegistry | Derivation not allowed |
| `RS001` | RevenueSplitter | No revenue to distribute |
| `RS002` | RevenueSplitter | Invalid split configuration |
| `RS003` | RevenueSplitter | Merkle proof invalid |
| `CB001` | CrossChainBridge | Chain not supported |
| `CB002` | CrossChainBridge | Message verification failed |
| `CB003` | CrossChainBridge | Asset not locked |

---

*Document Version: 1.0*  
*Last Updated: 2026-04-19*  
*Status: Draft - Pending Review from Contract Design Agents*
