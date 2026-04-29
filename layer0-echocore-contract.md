# EchoCore Contract Design Document

## Layer 0: Core Asset Management Contract

**Protocol**: ECHO - Distributed Value Network  
**Version**: 1.0.0  
**Solidity Version**: ^0.8.20  
**License**: MIT

---

## 1. Contract Overview

### 1.1 Purpose

EchoCore is the foundational smart contract of the ECHO Protocol's Layer 0, responsible for the lifecycle management of digital assets on the distributed value network. It implements a unique asset model that combines content verification, reproducible blueprints, and a four-dimensional rights framework.

### 1.2 Core Responsibilities

| Responsibility | Description |
|----------------|-------------|
| Asset Minting | Creation of digital assets with content hash and blueprint hash verification |
| Ownership Management | Standard ERC721-style ownership with fractional ownership extensions |
| Metadata Management | On-chain metadata storage with versioning capabilities |
| Rights Integration | Seamless integration with RightsRegistry for four-dimensional rights |
| Event Emission | Comprehensive event logging for indexer consumption (The Graph) |

### 1.3 Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    EchoCore (Proxy)                          │
│                  ┌──────────────────┐                        │
│                  │  Implementation  │                        │
│                  │    Contract     │                        │
│                  └────────┬─────────┘                        │
│                           │                                  │
│    ┌──────────────────────┼──────────────────────┐          │
│    ▼                      ▼                      ▼          │
│ ┌────────────┐      ┌──────────────┐     ┌──────────────┐    │
│ │Asset       │      │ Rights       │     │ Metadata     │    │
│ │Registry    │      │ Registry     │     │ Manager      │    │
│ │            │      │ (External)   │     │ (Embedded)   │    │
│ └────────────┘      └──────────────┘     └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Key Design Principles

1. **Immutability of Content**: Once minted, content hash and blueprint hash cannot be altered
2. **Upgradeability**: Transparent proxy pattern for logic updates without storage migration
3. **Gas Efficiency**: Packed structs, bitmaps for rights tracking, and minimal storage writes
4. **Composability**: Standard ERC721 interface with ERC2981 royalty support
5. **Security First**: Reentrancy protection, access control, and input validation

---

## 2. Data Structures

### 2.1 Core Structs

```solidity
/**
 * @notice Represents a digital asset in the ECHO network
 * @dev Packed to minimize storage slots (2 slots total)
 */
struct Asset {
    // Slot 1 (32 bytes)
    uint128 supply;              // Maximum supply for fractional assets (1 = NFT)
    uint128 minted;              // Current circulating supply
    
    // Slot 2 (32 bytes)
    uint64 createdAt;            // Block timestamp at minting
    uint64 version;              // Metadata version counter
    uint128 _reserved;           // Reserved for future use
    
    // Additional storage (Slot 3-4)
    bytes32 contentHash;         // Hash of actual content (IPFS/Arweave)
    bytes32 blueprintHash;       // Hash of creation blueprint/reproducible recipe
    address creator;             // Original creator address
    RightsConfiguration rights;  // Four-dimensional rights configuration
}

/**
 * @notice Four-dimensional rights configuration
 * @dev Each bit represents a specific right or permission
 */
struct RightsConfiguration {
    // Usage Rights (256 bits)
    uint256 usageRights;         // Bits: [access, execute, display, etc.]
    
    // Derivation Rights (256 bits)
    uint256 derivationRights;      // Bits: [remix, adapt, translate, etc.]
    
    // Extension Rights (256 bits)
    uint256 extensionRights;       // Bits: [plugin, embed, reference, etc.]
    
    // Revenue Rights (256 bits)
    uint256 revenueRights;         // Bits: [sell, license, subscribe, etc.]
    
    // Rights Registry reference
    address rightsRegistry;      // External RightsRegistry contract
    uint256 rightsTokenId;       // Token ID in RightsRegistry
}

/**
 * @notice Metadata version entry
 * @dev Stored in a mapping indexed by asset ID and version number
 */
struct MetadataVersion {
    string metadataURI;          // URI to metadata (IPFS/Arweave)
    address updatedBy;           // Address that updated this version
    uint64 updatedAt;            // Block timestamp
    bytes32 metadataHash;        // Hash for integrity verification
}

/**
 * @notice Fractional ownership record
 * @dev Used when supply > 1
 */
struct FractionalOwnership {
    uint256 balance;             // Owned amount
    uint256 locked;              // Locked amount (staking, etc.)
    uint256 lastClaimedAt;       // Last revenue distribution claim
}
```

### 2.2 Enumerations

```solidity
/**
 * @notice Asset lifecycle states
 */
enum AssetState {
    NonExistent,    // 0: Default state, asset not minted
    Active,         // 1: Normal operation
    Frozen,         // 2: Temporarily locked (dispute, etc.)
    Deprecated      // 3: Marked for obsolescence
}

/**
 * @notice Rights categories for the four-dimensional model
 */
enum RightsCategory {
    Usage,           // 0: How the asset can be used
    Derivation,      // 1: How derivative works can be created
    Extension,       // 2: How the asset can be extended/integrated
    Revenue          // 3: How revenue can be generated
}

/**
 * @notice Rights operation types
 */
enum RightsOperation {
    Grant,           // 0: Grant a right
    Revoke,          // 1: Revoke a right
    Transfer         // 2: Transfer a right to another party
}
```

### 2.3 Constants

```solidity
// Asset types (encoded in upper bits of asset ID)
uint256 constant ASSET_TYPE_NFT = 0x0000000000000000;        // Standard NFT
uint256 constant ASSET_TYPE_FRACTIONAL = 0x1000000000000000; // Fractional ownership
uint256 constant ASSET_TYPE_BUNDLE = 0x2000000000000000;     // Asset bundle

// Rights bit masks (Usage Rights)
uint256 constant RIGHT_USAGE_ACCESS = 1 << 0;
uint256 constant RIGHT_USAGE_EXECUTE = 1 << 1;
uint256 constant RIGHT_USAGE_DISPLAY = 1 << 2;
uint256 constant RIGHT_USAGE_STREAM = 1 << 3;

// Rights bit masks (Derivation Rights)
uint256 constant RIGHT_DERIVATION_REMIX = 1 << 0;
uint256 constant RIGHT_DERIVATION_ADAPT = 1 << 1;
uint256 constant RIGHT_DERIVATION_TRANSLATE = 1 << 2;
uint256 constant RIGHT_DERIVATION_MERGE = 1 << 3;

// Rights bit masks (Extension Rights)
uint256 constant RIGHT_EXTENSION_PLUGIN = 1 << 0;
uint256 constant RIGHT_EXTENSION_EMBED = 1 << 1;
uint256 constant RIGHT_EXTENSION_REFERENCE = 1 << 2;
uint256 constant RIGHT_EXTENSION_WRAPPER = 1 << 3;

// Rights bit masks (Revenue Rights)
uint256 constant RIGHT_REVENUE_SELL = 1 << 0;
uint256 constant RIGHT_REVENUE_LICENSE = 1 << 1;
uint256 constant RIGHT_REVENUE_SUBSCRIBE = 1 << 2;
uint256 constant RIGHT_REVENUE_DONATE = 1 << 3;
```

---

## 3. Function Specifications

### 3.1 Core Interface (IEchoCore)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC2981/IERC2981.sol";

interface IEchoCore is IERC721, IERC2981 {
    
    // ============ Asset Minting ============
    
    /**
     * @notice Mint a new digital asset
     * @param to Address to mint the asset to
     * @param contentHash Hash of the actual content (IPFS/Arweave CID)
     * @param blueprintHash Hash of the reproducible blueprint/recipe
     * @param metadataURI Initial metadata URI
     * @param supply Maximum supply (1 for NFT, >1 for fractional)
     * @param rightsConfig Initial rights configuration
     * @return assetId The newly minted asset ID
     * @return rightsTokenId The corresponding token ID in RightsRegistry
     * 
     * @dev Gas: ~180,000 for NFT, ~220,000 for fractional
     * @dev Security: ReentrancyGuard, onlyRole(MINTER_ROLE)
     * @dev Emits: AssetMinted, Transfer, RightsConfigured
     */
    function mintAsset(
        address to,
        bytes32 contentHash,
        bytes32 blueprintHash,
        string calldata metadataURI,
        uint128 supply,
        RightsConfiguration calldata rightsConfig
    ) external returns (uint256 assetId, uint256 rightsTokenId);
    
    /**
     * @notice Batch mint multiple assets
     * @param mints Array of mint parameters
     * @return assetIds Array of minted asset IDs
     * 
     * @dev Gas: ~150,000 per asset (optimized batching)
     * @dev Security: ReentrancyGuard, onlyRole(MINTER_ROLE)
     * @dev Emits: AssetMinted (for each), RightsConfigured (for each)
     */
    function batchMintAssets(
        MintParams[] calldata mints
    ) external returns (uint256[] memory assetIds);
    
    /**
     * @notice Mint additional supply for an existing fractional asset
     * @param assetId The asset to expand
     * @param amount Additional amount to mint
     * @param to Recipient address
     * 
     * @dev Gas: ~80,000
     * @dev Security: onlyRole(MINTER_ROLE) or creator
     * @dev Requirement: assetId must be fractional type
     * @dev Emits: SupplyExpanded, Transfer
     */
    function expandSupply(
        uint256 assetId,
        uint128 amount,
        address to
    ) external;
    
    // ============ Ownership Management ============
    
    /**
     * @notice Transfer complete ownership of an asset
     * @param from Current owner address
     * @param to New owner address
     * @param assetId Asset to transfer
     * 
     * @dev Standard ERC721 transfer with rights validation
     * @dev Gas: ~50,000
     * @dev Security: ReentrancyGuard, rights check for transfer
     * @dev Emits: Transfer, OwnershipTransferred
     */
    function transferFrom(
        address from,
        address to,
        uint256 assetId
    ) external override;
    
    /**
     * @notice Transfer fractional ownership units
     * @param assetId Fractional asset ID
     * @param to Recipient address
     * @param amount Number of units to transfer
     * 
     * @dev Gas: ~45,000
     * @dev Security: ReentrancyGuard, balance check
     * @dev Emits: FractionalTransfer
     */
    function transferFractional(
        uint256 assetId,
        address to,
        uint256 amount
    ) external;
    
    /**
     * @notice Batch transfer fractional units
     * @param transfers Array of fractional transfers
     * 
     * @dev Gas: ~35,000 per transfer (batched optimization)
     */
    function batchTransferFractional(
        FractionalTransfer[] calldata transfers
    ) external;
    
    /**
     * @notice Fractionalize an existing NFT into fractional units
     * @param assetId NFT to fractionalize
     * @param units Number of fractional units to create
     * @param recipients Initial distribution recipients
     * @param amounts Distribution amounts
     * 
     * @dev Gas: ~120,000
     * @dev Security: only owner, ReentrancyGuard
     * @dev Emits: AssetFractionalized, Transfer
     */
    function fractionalize(
        uint256 assetId,
        uint128 units,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
    
    /**
     * @notice Burn an asset or fractional units
     * @param assetId Asset to burn
     * @param amount Amount to burn (0 for complete NFT burn)
     * 
     * @dev Gas: ~40,000 (complete) / ~25,000 (partial)
     * @dev Security: ReentrancyGuard, ownership check
     * @dev Emits: AssetBurned, Transfer
     */
    function burn(
        uint256 assetId,
        uint256 amount
    ) external;
    
    /**
     * @notice Batch burn multiple assets
     * @param burns Array of burn parameters
     * 
     * @dev Gas: ~30,000 per asset
     */
    function batchBurn(
        BurnParams[] calldata burns
    ) external;
    
    // ============ Metadata Management ============
    
    /**
     * @notice Update asset metadata
     * @param assetId Asset to update
     * @param newMetadataURI New metadata URI
     * @param metadataHash Hash of new metadata for integrity
     * @return version New version number
     * 
     * @dev Gas: ~35,000
     * @dev Security: onlyRole(METADATA_MANAGER) or creator
     * @dev Emits: MetadataUpdated
     */
    function updateMetadata(
        uint256 assetId,
        string calldata newMetadataURI,
        bytes32 metadataHash
    ) external returns (uint64 version);
    
    /**
     * @notice Get current metadata URI for an asset
     * @param assetId Asset to query
     * @return URI string
     * 
     * @dev Gas: ~2,100 (view function)
     */
    function tokenURI(uint256 assetId) external view returns (string memory);
    
    /**
     * @notice Get specific metadata version
     * @param assetId Asset to query
     * @param version Version number
     * @return MetadataVersion struct
     * 
     * @dev Gas: ~2,500 (view function)
     */
    function getMetadataVersion(
        uint256 assetId,
        uint64 version
    ) external view returns (MetadataVersion memory);
    
    /**
     * @notice Get complete metadata history
     * @param assetId Asset to query
     * @return versions Array of all version numbers
     * @return metadataURIs Array of metadata URIs
     * 
     * @dev Gas: Variable based on version count
     */
    function getMetadataHistory(
        uint256 assetId
    ) external view returns (uint64[] memory versions, string[] memory metadataURIs);
    
    // ============ Rights Integration ============
    
    /**
     * @notice Configure rights for an asset
     * @param assetId Asset to configure
     * @param rightsConfig New rights configuration
     * 
     * @dev Gas: ~60,000
     * @dev Security: onlyRole(RIGHTS_MANAGER) or creator
     * @dev Emits: RightsConfigured
     */
    function configureRights(
        uint256 assetId,
        RightsConfiguration calldata rightsConfig
    ) external;
    
    /**
     * @notice Update specific rights category
     * @param assetId Asset to update
     * @param category Which rights category
     * @param rightsBitmap New rights bitmap
     * 
     * @dev Gas: ~25,000
     * @dev Emits: RightsUpdated
     */
    function updateRightsCategory(
        uint256 assetId,
        RightsCategory category,
        uint256 rightsBitmap
    ) external;
    
    /**
     * @notice Check if a specific right is granted
     * @param assetId Asset to check
     * @param category Rights category
     * @param rightBit Specific right bit to check
     * @return granted Whether the right is granted
     * 
     * @dev Gas: ~2,300 (view function)
     */
    function hasRight(
        uint256 assetId,
        RightsCategory category,
        uint256 rightBit
    ) external view returns (bool granted);
    
    /**
     * @notice Get complete rights configuration
     * @param assetId Asset to query
     * @return RightsConfiguration struct
     * 
     * @dev Gas: ~2,800 (view function)
     */
    function getRightsConfiguration(
        uint256 assetId
    ) external view returns (RightsConfiguration memory);
    
    /**
     * @notice Get the external RightsRegistry contract address
     * @return RightsRegistry contract address
     */
    function rightsRegistry() external view returns (address);
    
    // ============ Asset Queries ============
    
    /**
     * @notice Get complete asset information
     * @param assetId Asset to query
     * @return Asset struct with all data
     * 
     * @dev Gas: ~3,000 (view function)
     */
    function getAsset(uint256 assetId) external view returns (Asset memory);
    
    /**
     * @notice Get asset state
     * @param assetId Asset to query
     * @return Current AssetState
     */
    function getAssetState(uint256 assetId) external view returns (AssetState);
    
    /**
     * @notice Check if content hash exists (anti-duplicate)
     * @param contentHash Hash to check
     * @return exists Whether an asset with this content exists
     * @return existingAssetId Asset ID if exists
     */
    function contentHashExists(
        bytes32 contentHash
    ) external view returns (bool exists, uint256 existingAssetId);
    
    /**
     * @notice Verify content hash integrity
     * @param assetId Asset to verify
     * @param providedHash Hash to compare
     * @return valid Whether the hash matches
     */
    function verifyContentHash(
        uint256 assetId,
        bytes32 providedHash
    ) external view returns (bool valid);
    
    /**
     * @notice Get fractional balance
     * @param assetId Fractional asset
     * @param owner Address to query
     * @return balance Current balance
     * @return locked Locked amount
     */
    function fractionalBalance(
        uint256 assetId,
        address owner
    ) external view returns (uint256 balance, uint256 locked);
    
    /**
     * @notice Get all assets owned by an address
     * @param owner Address to query
     * @param start Starting index for pagination
     * @param limit Maximum results to return
     * @return assetIds Array of asset IDs
     * @return hasMore Whether more results exist
     * 
     * @dev Gas: Variable based on limit
     */
    function getAssetsByOwner(
        address owner,
        uint256 start,
        uint256 limit
    ) external view returns (uint256[] memory assetIds, bool hasMore);
    
    /**
     * @notice Get all assets created by an address
     * @param creator Creator address
     * @param start Starting index
     * @param limit Maximum results
     * @return assetIds Array of asset IDs
     */
    function getAssetsByCreator(
        address creator,
        uint256 start,
        uint256 limit
    ) external view returns (uint256[] memory assetIds, bool hasMore);
    
    // ============ Admin & Emergency ============
    
    /**
     * @notice Freeze an asset (emergency/admin)
     * @param assetId Asset to freeze
     * @param reason Freeze reason code
     * 
     * @dev Gas: ~25,000
     * @dev Security: onlyRole(ADMIN_ROLE)
     * @dev Emits: AssetFrozen
     */
    function freezeAsset(uint256 assetId, uint8 reason) external;
    
    /**
     * @notice Unfreeze an asset
     * @param assetId Asset to unfreeze
     * 
     * @dev Gas: ~20,000
     * @dev Security: onlyRole(ADMIN_ROLE)
     * @dev Emits: AssetUnfrozen
     */
    function unfreezeAsset(uint256 assetId) external;
    
    /**
     * @notice Set contract-level metadata (contractURI for OpenSea)
     * @param uri Contract metadata URI
     */
    function setContractURI(string calldata uri) external;
    
    /**
     * @notice Update royalty configuration
     * @param assetId Asset to update (0 for default)
     * @param receiver Royalty receiver
     * @param feeNumerator Fee numerator (basis points, 100 = 1%)
     * 
     * @dev Gas: ~25,000
     * @dev Security: only creator or admin
     */
    function setRoyaltyInfo(
        uint256 assetId,
        address receiver,
        uint96 feeNumerator
    ) external;
}
```

### 3.2 Supporting Structs (Interface Level)

```solidity
/**
 * @notice Parameters for minting operations
 */
struct MintParams {
    address to;
    bytes32 contentHash;
    bytes32 blueprintHash;
    string metadataURI;
    uint128 supply;
    RightsConfiguration rightsConfig;
}

/**
 * @notice Parameters for fractional transfers
 */
struct FractionalTransfer {
    uint256 assetId;
    address to;
    uint256 amount;
}

/**
 * @notice Parameters for burn operations
 */
struct BurnParams {
    uint256 assetId;
    uint256 amount;
}
```

---

## 4. Events

### 4.1 Core Events (For The Graph Indexing)

```solidity
/**
 * @notice Emitted when a new asset is minted
 * @param assetId The minted asset ID
 * @param creator The original creator address
 * @param owner The initial owner address
 * @param contentHash Hash of the content
 * @param blueprintHash Hash of the blueprint
 * @param supply Total supply (1 for NFT, >1 for fractional)
 * @param rightsTokenId Corresponding token in RightsRegistry
 */
event AssetMinted(
    uint256 indexed assetId,
    address indexed creator,
    address indexed owner,
    bytes32 contentHash,
    bytes32 blueprintHash,
    uint128 supply,
    uint256 rightsTokenId
);

/**
 * @notice Emitted when asset ownership is transferred
 * @param assetId The transferred asset
 * @param from Previous owner
 * @param to New owner
 * @param amount Transfer amount (1 for NFT, variable for fractional)
 */
event OwnershipTransferred(
    uint256 indexed assetId,
    address indexed from,
    address indexed to,
    uint256 amount
);

/**
 * @notice Emitted when fractional transfer occurs
 * @param assetId The fractional asset
 * @param from Sender
 * @param to Recipient
 * @param amount Units transferred
 */
event FractionalTransfer(
    uint256 indexed assetId,
    address indexed from,
    address indexed to,
    uint256 amount
);

/**
 * @notice Emitted when an asset is fractionalized
 * @param assetId The fractionalized asset
 * @param originalSupply Original supply (1)
 * @param newSupply New total units
 */
event AssetFractionalized(
    uint256 indexed assetId,
    uint128 originalSupply,
    uint128 newSupply
);

/**
 * @notice Emitted when additional supply is minted
 * @param assetId The asset
 * @param previousSupply Supply before expansion
 * @param newSupply New total supply
 * @param mintedBy Address that authorized expansion
 */
event SupplyExpanded(
    uint256 indexed assetId,
    uint128 previousSupply,
    uint128 newSupply,
    address indexed mintedBy
);

/**
 * @notice Emitted when an asset is burned
 * @param assetId The burned asset
 * @param amount Amount burned (0 for complete NFT)
 * @param burnedBy Address that burned
 */
event AssetBurned(
    uint256 indexed assetId,
    uint256 amount,
    address indexed burnedBy
);

/**
 * @notice Emitted when metadata is updated
 * @param assetId The updated asset
 * @param version New version number
 * @param metadataURI New metadata URI
 * @param metadataHash Hash of metadata
 * @param updatedBy Address that made the update
 */
event MetadataUpdated(
    uint256 indexed assetId,
    uint64 version,
    string metadataURI,
    bytes32 metadataHash,
    address indexed updatedBy
);

/**
 * @notice Emitted when rights are configured
 * @param assetId The configured asset
 * @param rightsTokenId Corresponding token in RightsRegistry
 * @param usageRights Usage rights bitmap
 * @param derivationRights Derivation rights bitmap
 * @param extensionRights Extension rights bitmap
 * @param revenueRights Revenue rights bitmap
 */
event RightsConfigured(
    uint256 indexed assetId,
    uint256 indexed rightsTokenId,
    uint256 usageRights,
    uint256 derivationRights,
    uint256 extensionRights,
    uint256 revenueRights
);

/**
 * @notice Emitted when specific rights category is updated
 * @param assetId The updated asset
 * @param category Which category was updated
 * @param previousBitmap Previous rights bitmap
 * @param newBitmap New rights bitmap
 */
event RightsUpdated(
    uint256 indexed assetId,
    RightsCategory indexed category,
    uint256 previousBitmap,
    uint256 newBitmap
);

/**
 * @notice Emitted when an asset is frozen
 * @param assetId The frozen asset
 * @param reason Freeze reason code
 * @param frozenBy Address that froze
 */
event AssetFrozen(
    uint256 indexed assetId,
    uint8 reason,
    address indexed frozenBy
);

/**
 * @notice Emitted when an asset is unfrozen
 * @param assetId The unfrozen asset
 * @param unfrozenBy Address that unfroze
 */
event AssetUnfrozen(
    uint256 indexed assetId,
    address indexed unfrozenBy
);

/**
 * @notice Emitted when asset state changes
 * @param assetId The asset
 * @param previousState Previous state
 * @param newState New state
 */
event AssetStateChanged(
    uint256 indexed assetId,
    AssetState previousState,
    AssetState newState
);

/**
 * @notice Emitted when royalty info is updated
 * @param assetId The asset (0 for default)
 * @param receiver Royalty receiver
 * @param feeNumerator Fee in basis points
 */
event RoyaltyInfoUpdated(
    uint256 indexed assetId,
    address indexed receiver,
    uint96 feeNumerator
);

/**
 * @notice Emitted when rights registry address is updated
 * @param previousRegistry Previous registry address
 * @param newRegistry New registry address
 */
event RightsRegistryUpdated(
    address indexed previousRegistry,
    address indexed newRegistry
);
```

### 4.2 The Graph Indexing Schema Reference

```graphql
type Asset @entity {
  id: ID!                          # assetId
  creator: Bytes!
  owner: Bytes!
  contentHash: Bytes!
  blueprintHash: Bytes!
  supply: BigInt!
  minted: BigInt!
  createdAt: BigInt!
  currentVersion: BigInt!
  currentMetadataURI: String!
  state: AssetState!
  rightsTokenId: BigInt!
  
  # Relations
  metadataVersions: [MetadataVersion!]! @derivedFrom(field: "asset")
  rights: RightsConfiguration!
  transfers: [OwnershipTransfer!]! @derivedFrom(field: "asset")
}

type MetadataVersion @entity {
  id: ID!                          # assetId-version
  asset: Asset!
  version: BigInt!
  metadataURI: String!
  metadataHash: Bytes!
  updatedBy: Bytes!
  updatedAt: BigInt!
}

type RightsConfiguration @entity {
  id: ID!                          # assetId-rights
  asset: Asset!
  usageRights: BigInt!
  derivationRights: BigInt!
  extensionRights: BigInt!
  revenueRights: BigInt!
  rightsRegistry: Bytes!
}

type OwnershipTransfer @entity {
  id: ID!                          # txHash-logIndex
  asset: Asset!
  from: Bytes!
  to: Bytes!
  amount: BigInt!
  timestamp: BigInt!
}
```

---

## 5. Access Control

### 5.1 Role Definitions

```solidity
// Role definitions using OpenZeppelin AccessControl
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 constant METADATA_MANAGER_ROLE = keccak256("METADATA_MANAGER_ROLE");
bytes32 constant RIGHTS_MANAGER_ROLE = keccak256("RIGHTS_MANAGER_ROLE");
bytes32 constant FROZEN_ASSET_MANAGER = keccak256("FROZEN_ASSET_MANAGER");
bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```

### 5.2 Role Permissions Matrix

| Function | DEFAULT_ADMIN | MINTER | METADATA_MANAGER | RIGHTS_MANAGER | Creator | Owner |
|----------|--------------|--------|------------------|----------------|---------|-------|
| `mintAsset` | ✓ | ✓ | ✗ | ✗ | N/A | N/A |
| `batchMintAssets` | ✓ | ✓ | ✗ | ✗ | N/A | N/A |
| `expandSupply` | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ |
| `updateMetadata` | ✓ | ✗ | ✓ | ✗ | ✓ | ✗ |
| `configureRights` | ✓ | ✗ | ✗ | ✓ | ✓ | ✗ |
| `updateRightsCategory` | ✓ | ✗ | ✗ | ✓ | ✓ | ✗ |
| `freezeAsset` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `unfreezeAsset` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `setRoyaltyInfo` | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `upgradeTo` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |

### 5.3 Implementation Notes

```solidity
/**
 * @dev Access control implementation using OpenZeppelin
 */
modifier onlyCreator(uint256 assetId) {
    require(_assets[assetId].creator == msg.sender, "EchoCore: not creator");
    _;
}

modifier onlyAssetOwner(uint256 assetId) {
    require(ownerOf(assetId) == msg.sender, "EchoCore: not owner");
    _;
}

modifier whenNotFrozen(uint256 assetId) {
    require(_assetStates[assetId] != AssetState.Frozen, "EchoCore: asset frozen");
    _;
}

modifier validAsset(uint256 assetId) {
    require(_exists(assetId), "EchoCore: asset does not exist");
    _;
}
```

---

## 6. Security Considerations

### 6.1 Reentrancy Protection

```solidity
/**
 * @notice All state-changing functions use ReentrancyGuard
 * @dev Inherited from OpenZeppelin ReentrancyGuardUpgradeable
 */

// Functions protected by nonReentrant:
// - mintAsset
// - batchMintAssets
// - expandSupply
// - transferFrom
// - transferFractional
// - fractionalize
// - burn
// - batchBurn
// - updateMetadata
// - configureRights
// - updateRightsCategory

/**
 * @dev Critical: All external calls happen AFTER state changes
 * (Checks-Effects-Interactions pattern)
 */
function mintAsset(...) external nonReentrant returns (...) {
    // 1. CHECKS
    require(...);
    
    // 2. EFFECTS (state changes)
    _assetCounter++;
    uint256 newAssetId = _assetCounter;
    _assets[newAssetId] = Asset(...);
    
    // 3. INTERACTIONS (external calls last)
    _safeMint(to, newAssetId);
    _configureRightsInRegistry(newAssetId, rightsConfig);
    
    emit AssetMinted(...);
}
```

### 6.2 Integer Overflow Protection

```solidity
/**
 * @dev All arithmetic uses Solidity ^0.8.20 built-in overflow checks
 * Additional checks for business logic:
 */

function expandSupply(uint256 assetId, uint128 amount, address to) external {
    Asset storage asset = _assets[assetId];
    
    // Prevent overflow in minted count
    require(asset.minted + amount <= asset.supply, "EchoCore: exceeds max supply");
    
    // Prevent overflow in fractional balances
    uint256 currentBalance = _fractionalBalances[assetId][to];
    require(currentBalance + amount <= type(uint256).max, "EchoCore: balance overflow");
    
    asset.minted += amount;
    _fractionalBalances[assetId][to] += amount;
}
```

### 6.3 Access Control Validation

```solidity
/**
 * @notice Content hash uniqueness verification
 * @dev Prevents duplicate content from being minted
 */
mapping(bytes32 => uint256) private _contentHashToAssetId;

function mintAsset(...) external nonReentrant onlyRole(MINTER_ROLE) {
    require(_contentHashToAssetId[contentHash] == 0, "EchoCore: content already exists");
    
    // ... mint logic
    
    _contentHashToAssetId[contentHash] = newAssetId;
}

/**
 * @notice Blueprint hash validation
 * @dev Blueprints must be non-zero for valid assets
 */
require(blueprintHash != bytes32(0), "EchoCore: blueprint required");
```

### 6.4 Signature Validation (Meta-transactions)

```solidity
/**
 * @notice EIP-712 typed data signature for meta-transactions
 * @dev Allows gasless transactions via relayers
 */
struct MintAssetRequest {
    address to;
    bytes32 contentHash;
    bytes32 blueprintHash;
    string metadataURI;
    uint128 supply;
    uint256 nonce;
    uint256 deadline;
}

bytes32 constant MINT_TYPEHASH = keccak256(
    "MintAssetRequest(address to,bytes32 contentHash,bytes32 blueprintHash,string metadataURI,uint128 supply,uint256 nonce,uint256 deadline)"
);

function mintAssetWithSignature(
    MintAssetRequest calldata request,
    bytes calldata signature
) external nonReentrant {
    require(block.timestamp <= request.deadline, "EchoCore: signature expired");
    require(_nonces[request.to] == request.nonce, "EchoCore: invalid nonce");
    
    bytes32 structHash = keccak256(abi.encode(
        MINT_TYPEHASH,
        request.to,
        request.contentHash,
        request.blueprintHash,
        keccak256(bytes(request.metadataURI)),
        request.supply,
        request.nonce,
        request.deadline
    ));
    
    address signer = ECDSA.recover(_hashTypedDataV4(structHash), signature);
    require(hasRole(MINTER_ROLE, signer), "EchoCore: invalid signer");
    
    _nonces[request.to]++;
    
    // Execute mint...
}
```

### 6.5 Upgrade Safety

```solidity
/**
 * @notice Storage layout preservation for upgrades
 * @dev New variables must be appended, never inserted or reordered
 */

// Current storage layout (V1):
// Slot 0: _initialized (bool), _initializing (bool)
// Slot 1: __gap[0] (from ContextUpgradeable)
// Slot 2-51: __gap (from ERC721Upgradeable, ERC2981Upgradeable)
// Slot 52: _rightsRegistry (address)
// Slot 53: _assetCounter (uint256)
// Slot 54: _contractURI (string storage slot 1)
// Slot 55: _contractURI (string storage slot 2 - length)
// Slot 56: _assets (mapping base)
// Slot 57: _assetStates (mapping base)
// Slot 58: _contentHashToAssetId (mapping base)
// Slot 59: _metadataVersions (mapping base)
// Slot 60: _fractionalBalances (mapping base)
// Slot 61-70: __gap[50] (reserved for future extensions)

// Example: Adding new storage in V2
// contract EchoCoreV2 is EchoCore {
//     // New variable goes here (Slot 71)
//     mapping(uint256 => uint256) public assetValue;
// }
```

### 6.6 Emergency Controls

```solidity
/**
 * @notice Circuit breaker pattern
 */
bool private _paused;

modifier whenNotPaused() {
    require(!_paused, "EchoCore: paused");
    _;
}

function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _paused = true;
    emit Paused(msg.sender);
}

function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _paused = false;
    emit Unpaused(msg.sender);
}
```

---

## 7. Integration Points

### 7.1 RightsRegistry Integration

```solidity
interface IRightsRegistry {
    /**
     * @notice Mint a rights token for a new asset
     * @param to Owner of the rights
     * @param usageRights Usage rights bitmap
     * @param derivationRights Derivation rights bitmap
     * @param extensionRights Extension rights bitmap
     * @param revenueRights Revenue rights bitmap
     * @return tokenId The minted rights token ID
     */
    function mintRightsToken(
        address to,
        uint256 usageRights,
        uint256 derivationRights,
        uint256 extensionRights,
        uint256 revenueRights
    ) external returns (uint256 tokenId);
    
    /**
     * @notice Update rights configuration
     * @param tokenId Rights token to update
     * @param category Which category to update
     * @param rightsBitmap New rights bitmap
     */
    function updateRights(
        uint256 tokenId,
        uint8 category,
        uint256 rightsBitmap
    ) external;
    
    /**
     * @notice Get rights token for an asset
     * @param assetId EchoCore asset ID
     * @return tokenId Corresponding rights token
     */
    function getRightsTokenForAsset(uint256 assetId) external view returns (uint256 tokenId);
}

/**
 * @notice EchoCore → RightsRegistry interaction flow
 */
function _configureRightsInRegistry(
    uint256 assetId,
    RightsConfiguration calldata config
) internal {
    uint256 rightsTokenId = IRightsRegistry(_rightsRegistry).mintRightsToken(
        msg.sender,
        config.usageRights,
        config.derivationRights,
        config.extensionRights,
        config.revenueRights
    );
    
    _assets[assetId].rights.rightsTokenId = rightsTokenId;
}
```

### 7.2 Revenue Distribution Integration

```solidity
interface IRevenueDistributor {
    /**
     * @notice Register an asset for revenue distribution
     * @param assetId Asset to register
     * @param recipients Revenue share recipients
     * @param shares Basis point shares (must sum to 10000)
     */
    function registerAsset(
        uint256 assetId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external;
}

/**
 * @notice Integration hook in EchoCore
 */
function mintAsset(...) external nonReentrant returns (uint256 assetId, uint256 rightsTokenId) {
    // ... mint logic ...
    
    // Auto-register for revenue if revenue rights are granted
    if (rightsConfig.revenueRights & RIGHT_REVENUE_SELL != 0) {
        address[] memory recipients = new address[](1);
        recipients[0] = to;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000; // 100% to initial owner
        
        IRevenueDistributor(_revenueDistributor).registerAsset(assetId, recipients, shares);
    }
}
```

### 7.3 External Bridge Integration (Layer 2)

```solidity
interface IAssetBridge {
    /**
     * @notice Lock asset for cross-chain transfer
     * @param assetId Asset to bridge
     * @param targetChain Destination chain ID
     * @param recipient Recipient on destination chain
     */
    function lockForBridge(
        uint256 assetId,
        uint256 targetChain,
        address recipient
    ) external;
    
    /**
     * @notice Unlock asset from cross-chain transfer
     * @param assetId Asset to unlock
     * @param sourceChain Origin chain ID
     * @param proof Bridge proof
     */
    function unlockFromBridge(
        uint256 assetId,
        uint256 sourceChain,
        bytes calldata proof
    ) external;
}
```

### 7.4 Oracle Integration (Price/Verification)

```solidity
interface IContentOracle {
    /**
     * @notice Request content hash verification
     * @param contentUri URI to verify
     * @return contentHash Computed hash
     * @return isValid Whether content is accessible and valid
     */
    function verifyContent(string calldata contentUri) external returns (bytes32 contentHash, bool isValid);
}
```

---

## 8. Deployment Guide

### 8.1 Pre-deployment Checklist

| Check | Description | Verification |
|-------|-------------|--------------|
| ☐ | Solidity version compatibility | `^0.8.20` |
| ☐ | OpenZeppelin contracts verified | v5.x |
| ☐ | Storage layout validated | Using `hardhat-storage-layout` |
| ☐ | RightsRegistry contract deployed | Address confirmed |
| ☐ | RevenueDistributor contract deployed | Address confirmed |
| ☐ | Access control roles assigned | Admin, Minter roles |
| ☐ | Emergency pause functionality tested | Unit tests pass |
| ☐ | Upgrade mechanism validated | Proxy pattern tested |
| ☐ | Gas optimization verified | Under 200k for mint |
| ☐ | The Graph manifest prepared | Events indexed |

### 8.2 Deployment Script

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {EchoCore} from "../src/EchoCore.sol";

contract DeployEchoCore is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address rightsRegistry = vm.envAddress("RIGHTS_REGISTRY");
        address revenueDistributor = vm.envAddress("REVENUE_DISTRIBUTOR");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy implementation
        EchoCore implementation = new EchoCore();
        
        // 2. Deploy proxy admin
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(admin);
        
        // 3. Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            EchoCore.initialize.selector,
            admin,              // default admin
            rightsRegistry,     // RightsRegistry address
            revenueDistributor, // RevenueDistributor address
            "ECHO Protocol Assets", // name
            "ECHO",             // symbol
            "https://echo.network/metadata/contract" // contractURI
        );
        
        // 4. Deploy transparent proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        vm.stopBroadcast();
        
        console.log("Implementation:", address(implementation));
        console.log("ProxyAdmin:", address(proxyAdmin));
        console.log("EchoCore Proxy:", address(proxy));
    }
}
```

### 8.3 Post-deployment Configuration

```solidity
/**
 * @notice Post-deployment setup script
 */
contract SetupEchoCore is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        address echoCore = vm.envAddress("ECHOCORE_PROXY");
        address minter = vm.envAddress("MINTER_ADDRESS");
        address metadataManager = vm.envAddress("METADATA_MANAGER");
        address rightsManager = vm.envAddress("RIGHTS_MANAGER");
        
        vm.startBroadcast(adminPrivateKey);
        
        IEchoCore core = IEchoCore(echoCore);
        
        // Grant roles
        core.grantRole(core.MINTER_ROLE(), minter);
        core.grantRole(core.METADATA_MANAGER_ROLE(), metadataManager);
        core.grantRole(core.RIGHTS_MANAGER_ROLE(), rightsManager);
        
        // Set default royalty (2.5%)
        core.setRoyaltyInfo(0, address(0), 250);
        
        vm.stopBroadcast();
    }
}
```

### 8.4 Upgrade Procedure

```solidity
/**
 * @notice Contract upgrade script
 */
contract UpgradeEchoCore is Script {
    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");
        address echoCoreProxy = vm.envAddress("ECHOCORE_PROXY");
        
        vm.startBroadcast(adminPrivateKey);
        
        // 1. Deploy new implementation
        EchoCoreV2 newImplementation = new EchoCoreV2();
        
        // 2. Upgrade through proxy admin
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(echoCoreProxy),
            address(newImplementation),
            "" // No reinitialization needed for V2
        );
        
        vm.stopBroadcast();
        
        console.log("New Implementation:", address(newImplementation));
        console.log("Upgrade complete");
    }
}
```

### 8.5 Contract Addresses (Example)

| Network | Contract | Address | Block |
|---------|----------|---------|-------|
| Ethereum Mainnet | EchoCore Proxy | `0x...` | 18,000,000 |
| Ethereum Mainnet | EchoCore Impl V1 | `0x...` | 18,000,000 |
| Ethereum Mainnet | ProxyAdmin | `0x...` | 18,000,000 |
| Sepolia | EchoCore Proxy | `0x...` | 5,000,000 |
| Polygon | EchoCore Proxy | `0x...` | 45,000,000 |

### 8.6 Gas Estimates

| Operation | Gas Estimate | Notes |
|-----------|--------------|-------|
| `mintAsset` (NFT) | 185,000 | Single mint |
| `mintAsset` (Fractional) | 220,000 | With rights config |
| `batchMintAssets` (10) | 1,500,000 | ~150k per asset |
| `transferFrom` | 52,000 | Standard transfer |
| `transferFractional` | 45,000 | Fractional units |
| `fractionalize` | 125,000 | NFT → Fractional |
| `burn` (complete) | 42,000 | Full NFT burn |
| `burn` (partial) | 28,000 | Fractional burn |
| `updateMetadata` | 38,000 | New version |
| `configureRights` | 65,000 | Full config |
| `updateRightsCategory` | 28,000 | Single category |
| `freezeAsset` | 26,000 | Emergency |

### 8.7 Verification Commands

```bash
# Verify implementation on Etherscan
forge verify-contract \
    --chain-id 1 \
    --watch \
    --compiler-version v0.8.20 \
    --optimizer-runs 200 \
    --constructor-args $(cast abi-encode "constructor()") \
    $IMPLEMENTATION_ADDRESS \
    src/EchoCore.sol:EchoCore

# Verify proxy on Etherscan
forge verify-contract \
    --chain-id 1 \
    --watch \
    --compiler-version v0.8.20 \
    $PROXY_ADDRESS \
    lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy
```

---

## Appendix A: Complete Contract Implementation Outline

```solidity
// contracts/EchoCore.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC2981/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./IEchoCore.sol";
import "./IRightsRegistry.sol";

contract EchoCore is 
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    UUPSUpgradeable,
    IEchoCore
{
    // ============ Storage ============
    
    address public rightsRegistry;
    address public revenueDistributor;
    uint256 private _assetCounter;
    string private _contractURI;
    
    mapping(uint256 => Asset) private _assets;
    mapping(uint256 => AssetState) private _assetStates;
    mapping(bytes32 => uint256) private _contentHashToAssetId;
    mapping(uint256 => mapping(uint64 => MetadataVersion)) private _metadataVersions;
    mapping(uint256 => mapping(address => FractionalOwnership)) private _fractionalBalances;
    mapping(address => uint256) private _nonces;
    
    // ============ Constants ============
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant METADATA_MANAGER_ROLE = keccak256("METADATA_MANAGER_ROLE");
    bytes32 public constant RIGHTS_MANAGER_ROLE = keccak256("RIGHTS_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ============ Events ============
    
    event AssetMinted(...);
    event OwnershipTransferred(...);
    // ... (all events defined in Section 4)
    
    // ============ Constructor ============
    
    constructor() {
        _disableInitializers();
    }
    
    // ============ Initialize ============
    
    function initialize(
        address admin,
        address _rightsRegistry,
        address _revenueDistributor,
        string memory name,
        string memory symbol,
        string memory contractURI_
    ) public initializer {
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC2981_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __EIP712_init(name, "1");
        __UUPSUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        rightsRegistry = _rightsRegistry;
        revenueDistributor = _revenueDistributor;
        _contractURI = contractURI_;
        _assetCounter = 0;
    }
    
    // ============ Core Functions ============
    
    function mintAsset(...) external nonReentrant whenNotPaused onlyRole(MINTER_ROLE) returns (...) {
        // Implementation per Section 3
    }
    
    // ... (all functions defined in Section 3)
    
    // ============ Internal Functions ============
    
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
    
    // ... (additional internal helpers)
    
    // ============ View Functions ============
    
    // ... (all view functions defined in Section 3)
    
    // ============ ERC165 ============
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC2981Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // ============ Gap for Storage ============
    
    uint256[50] private __gap;
}
```

---

## Appendix B: Error Codes

| Error Code | Message | Context |
|------------|---------|---------|
| EC001 | "EchoCore: not creator" | Creator-only function called by non-creator |
| EC002 | "EchoCore: not owner" | Owner-only function called by non-owner |
| EC003 | "EchoCore: asset frozen" | Operation on frozen asset |
| EC004 | "EchoCore: asset does not exist" | Invalid asset ID |
| EC005 | "EchoCore: content already exists" | Duplicate content hash |
| EC006 | "EchoCore: blueprint required" | Missing blueprint hash |
| EC007 | "EchoCore: exceeds max supply" | Expansion over supply limit |
| EC008 | "EchoCore: balance overflow" | Arithmetic overflow |
| EC009 | "EchoCore: invalid fractional amount" | Invalid fractional transfer |
| EC010 | "EchoCore: not fractional asset" | Operation on non-fractional asset |
| EC011 | "EchoCore: signature expired" | EIP-712 deadline passed |
| EC012 | "EchoCore: invalid nonce" | Replay protection triggered |
| EC013 | "EchoCore: invalid signer" | Unauthorized meta-transaction |
| EC014 | "EchoCore: paused" | Circuit breaker active |
| EC015 | "EchoCore: rights check failed" | Insufficient rights |

---

**Document Version**: 1.0.0  
**Last Updated**: 2024  
**Review Status**: Draft for Implementation
