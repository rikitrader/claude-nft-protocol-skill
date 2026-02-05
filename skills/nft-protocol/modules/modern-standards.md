# Modern Standards & Cross-Chain

Newer ERC standards (ERC-7572, ERC-7510, ERC-6900/7579), Chainlink CCIP cross-chain messaging, and modular smart account integration.

---

## MODULE: CHAINLINK CCIP (CROSS-CHAIN INTEROPERABILITY)

Chainlink Cross-Chain Interoperability Protocol for bridging NFTs and messages across chains. Alternative/complement to LayerZero.

### CCIP NFT Bridge

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IInstitutionalNFT {
    function mint(address to, uint256 tokenId, string memory uri, uint96 royaltyBps) external;
    function burn(uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract CCIPNFTBridge is CCIPReceiver, AccessControl, ReentrancyGuard {
    using Address for address payable;

    bytes32 public constant BRIDGE_ADMIN_ROLE = keccak256("BRIDGE_ADMIN_ROLE");

    IInstitutionalNFT public nft;

    // Chain selector => allowed
    mapping(uint64 => bool) public allowedChains;
    // Chain selector => bridge contract address on that chain
    mapping(uint64 => address) public bridgePeers;
    // Message ID => processed
    mapping(bytes32 => bool) public processedMessages;

    // Fee token (LINK or native)
    IERC20 public linkToken;

    // Bridge stats
    uint256 public totalBridgedOut;
    uint256 public totalBridgedIn;

    event NFTBridgedOut(
        uint256 indexed tokenId,
        address indexed from,
        uint64 destinationChain,
        bytes32 messageId
    );
    event NFTBridgedIn(
        uint256 indexed tokenId,
        address indexed to,
        uint64 sourceChain,
        bytes32 messageId
    );
    event ChainAllowed(uint64 chainSelector, bool allowed);
    event PeerSet(uint64 chainSelector, address peer);

    constructor(
        address _router,
        address _nft,
        address _linkToken
    ) CCIPReceiver(_router) {
        nft = IInstitutionalNFT(_nft);
        linkToken = IERC20(_linkToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ADMIN_ROLE, msg.sender);
    }

    // ==================== Bridge Out ====================

    function bridgeNFT(
        uint64 destinationChainSelector,
        address recipient,
        uint256 tokenId,
        bool payInLink
    ) external nonReentrant returns (bytes32 messageId) {
        require(allowedChains[destinationChainSelector], "Chain not allowed");
        require(bridgePeers[destinationChainSelector] != address(0), "No peer on destination");
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");

        // Get token metadata before burning
        string memory uri = nft.tokenURI(tokenId);

        // Burn on source chain
        nft.burn(tokenId);

        // Build CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bridgePeers[destinationChainSelector]),
            data: abi.encode(tokenId, recipient, uri),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 500_000})
            ),
            feeToken: payInLink ? address(linkToken) : address(0)
        });

        // Get fee
        uint256 fee = IRouterClient(getRouter()).getFee(
            destinationChainSelector,
            message
        );

        if (payInLink) {
            linkToken.transferFrom(msg.sender, address(this), fee);
            linkToken.approve(getRouter(), fee);
            messageId = IRouterClient(getRouter()).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            require(msg.value >= fee, "Insufficient fee");
            messageId = IRouterClient(getRouter()).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
            // Refund excess
            if (msg.value > fee) {
                Address.sendValue(payable(msg.sender), msg.value - fee);
            }
        }

        totalBridgedOut++;
        emit NFTBridgedOut(tokenId, msg.sender, destinationChainSelector, messageId);
    }

    // ==================== Bridge In (Receive) ====================

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override nonReentrant {
        require(!processedMessages[message.messageId], "Already processed");

        uint64 sourceChain = message.sourceChainSelector;
        address sender = abi.decode(message.sender, (address));

        require(allowedChains[sourceChain], "Source chain not allowed");
        require(sender == bridgePeers[sourceChain], "Invalid sender");

        processedMessages[message.messageId] = true;

        // Decode payload
        (uint256 tokenId, address recipient, string memory uri) = abi.decode(
            message.data,
            (uint256, address, string)
        );

        // Mint on destination chain
        nft.mint(recipient, tokenId, uri, 500); // Default 5% royalty

        totalBridgedIn++;
        emit NFTBridgedIn(tokenId, recipient, sourceChain, message.messageId);
    }

    // ==================== Fee Estimation ====================

    function estimateBridgeFee(
        uint64 destinationChainSelector,
        uint256 tokenId,
        address recipient,
        bool payInLink
    ) external view returns (uint256) {
        string memory uri = nft.tokenURI(tokenId);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bridgePeers[destinationChainSelector]),
            data: abi.encode(tokenId, recipient, uri),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 500_000})
            ),
            feeToken: payInLink ? address(linkToken) : address(0)
        });

        return IRouterClient(getRouter()).getFee(destinationChainSelector, message);
    }

    // ==================== Admin ====================

    function setAllowedChain(uint64 chainSelector, bool allowed)
        external onlyRole(BRIDGE_ADMIN_ROLE)
    {
        allowedChains[chainSelector] = allowed;
        emit ChainAllowed(chainSelector, allowed);
    }

    function setBridgePeer(uint64 chainSelector, address peer)
        external onlyRole(BRIDGE_ADMIN_ROLE)
    {
        bridgePeers[chainSelector] = peer;
        emit PeerSet(chainSelector, peer);
    }
}
```

### CCIP Chain Selectors

```
CCIP Chain Selectors (Mainnet):
├── Ethereum:       5009297550715157269
├── Polygon:        4051577828743386545
├── Avalanche:      6433500567565415381
├── Arbitrum:       4949039107694359620
├── Optimism:       3734403246176062136
├── Base:           15971525489660198786
└── BSC:            11344663589394136015

CCIP Chain Selectors (Testnet):
├── Sepolia:        16015286601757825753
├── Mumbai:         12532609583862916517
├── Fuji:           14767482510784806043
└── Base Goerli:    5790810961207155433
```

---

## MODULE: ERC-7572 (CONTRACT-LEVEL METADATA)

Standard for contract-level metadata, enabling rich descriptions, logos, and social links for NFT collections.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC7572 {
    event ContractURIUpdated();
    function contractURI() external view returns (string memory);
}

contract ERC7572ContractMetadata is IERC7572, AccessControl {
    string private _contractURI;

    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    constructor(string memory initialURI) {
        _contractURI = initialURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(METADATA_ADMIN_ROLE, msg.sender);
    }

    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    function setContractURI(string memory newURI)
        external
        onlyRole(METADATA_ADMIN_ROLE)
    {
        _contractURI = newURI;
        emit ContractURIUpdated();
    }
}
```

### Contract Metadata JSON Schema

```json
{
    "name": "Institutional NFT Collection",
    "description": "Institutional-grade NFTs for real-world asset tokenization",
    "image": "ipfs://QmCollectionImage.../logo.png",
    "banner_image": "ipfs://QmBanner.../banner.png",
    "featured_image": "ipfs://QmFeatured.../featured.png",
    "external_link": "https://protocol.example.com",
    "collaborators": ["0xAddress1", "0xAddress2"],
    "social_urls": {
        "twitter": "https://twitter.com/protocol",
        "discord": "https://discord.gg/protocol",
        "website": "https://protocol.example.com"
    }
}
```

---

## MODULE: ERC-7510 (CROSS-CONTRACT NFT REFERENCE)

Enables NFTs to reference other NFTs across contracts, creating parent-child relationships.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC7510 {
    struct NFTReference {
        address contractAddress;
        uint256 tokenId;
    }

    event ReferenceAdded(
        uint256 indexed tokenId,
        address indexed refContract,
        uint256 indexed refTokenId
    );
    event ReferenceRemoved(
        uint256 indexed tokenId,
        address indexed refContract,
        uint256 indexed refTokenId
    );

    function referenceOf(uint256 tokenId)
        external view returns (NFTReference[] memory);
    function addReference(uint256 tokenId, NFTReference calldata ref) external;
    function removeReference(uint256 tokenId, uint256 index) external;
}

contract ERC7510CrossReference is IERC7510 {
    // tokenId => references
    mapping(uint256 => NFTReference[]) private _references;
    // tokenId => ref hash => exists
    mapping(uint256 => mapping(bytes32 => bool)) private _referenceExists;

    function referenceOf(uint256 tokenId)
        external view override returns (NFTReference[] memory)
    {
        return _references[tokenId];
    }

    function addReference(uint256 tokenId, NFTReference calldata ref)
        external override
    {
        // Must be token owner (implement ownership check)
        bytes32 refHash = keccak256(abi.encode(ref.contractAddress, ref.tokenId));
        require(!_referenceExists[tokenId][refHash], "Reference exists");

        // Verify referenced NFT exists
        try IERC721(ref.contractAddress).ownerOf(ref.tokenId) returns (address) {
            _references[tokenId].push(ref);
            _referenceExists[tokenId][refHash] = true;
            emit ReferenceAdded(tokenId, ref.contractAddress, ref.tokenId);
        } catch {
            revert("Referenced NFT does not exist");
        }
    }

    function removeReference(uint256 tokenId, uint256 index)
        external override
    {
        // Must be token owner
        NFTReference[] storage refs = _references[tokenId];
        require(index < refs.length, "Index out of bounds");

        bytes32 refHash = keccak256(abi.encode(refs[index].contractAddress, refs[index].tokenId));

        emit ReferenceRemoved(tokenId, refs[index].contractAddress, refs[index].tokenId);

        // Swap and pop
        refs[index] = refs[refs.length - 1];
        refs.pop();
        _referenceExists[tokenId][refHash] = false;
    }
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}
```

---

## MODULE: ERC-6900 / ERC-7579 (MODULAR SMART ACCOUNTS)

Modular account abstraction extending ERC-4337 with plugin architecture.

### ERC-7579 Modular Account with NFT Module

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC-7579 module interface
interface IModule {
    function onInstall(bytes calldata data) external;
    function onUninstall(bytes calldata data) external;
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}

/// @notice Module type IDs per ERC-7579
/// 1 = Validator, 2 = Executor, 3 = Fallback, 4 = Hook

/// @notice NFT Management Module for ERC-7579 accounts
/// Allows smart accounts to manage NFT portfolios with rules
contract NFTManagerModule is IModule {
    uint256 public constant MODULE_TYPE = 2; // Executor module

    struct NFTRule {
        uint256 maxHoldings;         // Max NFTs this account can hold
        uint256 maxValuePerNFT;      // Max ETH value per NFT purchase
        bool autoAcceptAirdrops;     // Auto-accept or require approval
        address[] approvedCollections; // Whitelist of NFT collections
    }

    // Account => rules
    mapping(address => NFTRule) public accountRules;
    // Account => installed
    mapping(address => bool) public installed;

    event ModuleInstalled(address indexed account);
    event ModuleUninstalled(address indexed account);
    event RulesUpdated(address indexed account);
    event NFTPurchaseExecuted(
        address indexed account,
        address indexed collection,
        uint256 tokenId,
        uint256 price
    );

    function onInstall(bytes calldata data) external override {
        require(!installed[msg.sender], "Already installed");
        installed[msg.sender] = true;

        if (data.length > 0) {
            NFTRule memory rules = abi.decode(data, (NFTRule));
            accountRules[msg.sender] = rules;
        }

        emit ModuleInstalled(msg.sender);
    }

    function onUninstall(bytes calldata) external override {
        require(installed[msg.sender], "Not installed");
        delete accountRules[msg.sender];
        installed[msg.sender] = false;
        emit ModuleUninstalled(msg.sender);
    }

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE;
    }

    function updateRules(NFTRule calldata newRules) external {
        require(installed[msg.sender], "Module not installed");
        accountRules[msg.sender] = newRules;
        emit RulesUpdated(msg.sender);
    }

    /// @notice Execute NFT purchase through the smart account
    function executeNFTPurchase(
        address marketplace,
        address collection,
        uint256 tokenId,
        uint256 price,
        bytes calldata purchaseCalldata
    ) external {
        require(installed[msg.sender], "Module not installed");

        NFTRule storage rules = accountRules[msg.sender];
        require(price <= rules.maxValuePerNFT, "Exceeds max value per NFT");
        require(_isApprovedCollection(rules, collection), "Collection not approved");

        // Execute purchase via account
        (bool success, ) = marketplace.call{value: price}(purchaseCalldata);
        require(success, "Purchase failed");

        emit NFTPurchaseExecuted(msg.sender, collection, tokenId, price);
    }

    function _isApprovedCollection(
        NFTRule storage rules,
        address collection
    ) internal view returns (bool) {
        if (rules.approvedCollections.length == 0) return true; // No whitelist = all allowed

        for (uint256 i = 0; i < rules.approvedCollections.length; i++) {
            if (rules.approvedCollections[i] == collection) return true;
        }
        return false;
    }
}

/// @notice NFT Validator Module - validates NFT-related transactions
contract NFTValidatorModule is IModule {
    uint256 public constant MODULE_TYPE = 1; // Validator module

    // Account => collection => spending limit (wei)
    mapping(address => mapping(address => uint256)) public spendingLimits;
    // Account => collection => spent this period
    mapping(address => mapping(address => uint256)) public currentSpending;
    // Account => last reset timestamp
    mapping(address => uint256) public lastReset;
    // Reset period (default 1 day)
    uint256 public constant RESET_PERIOD = 1 days;

    mapping(address => bool) public installed;

    function onInstall(bytes calldata) external override {
        installed[msg.sender] = true;
        lastReset[msg.sender] = block.timestamp;
    }

    function onUninstall(bytes calldata) external override {
        installed[msg.sender] = false;
    }

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE;
    }

    function setSpendingLimit(address collection, uint256 limit) external {
        require(installed[msg.sender], "Not installed");
        spendingLimits[msg.sender][collection] = limit;
    }

    function validateSpending(
        address account,
        address collection,
        uint256 amount
    ) external view returns (bool) {
        if (!installed[account]) return true;

        uint256 limit = spendingLimits[account][collection];
        if (limit == 0) return true; // No limit set

        uint256 spent = currentSpending[account][collection];

        // Check if period should reset
        if (block.timestamp >= lastReset[account] + RESET_PERIOD) {
            spent = 0;
        }

        return (spent + amount) <= limit;
    }
}
```

### Integration with ERC-4337 Bundler

```solidity
/// @notice UserOperation with NFT module execution
/// Build the UserOp calldata to execute NFT operations through the modular account

// Install NFT module
bytes memory installData = abi.encodeWithSelector(
    IAccount.installModule.selector,
    2, // Executor type
    address(nftManagerModule),
    abi.encode(NFTManagerModule.NFTRule({
        maxHoldings: 100,
        maxValuePerNFT: 10 ether,
        autoAcceptAirdrops: false,
        approvedCollections: new address[](0)
    }))
);

// Execute NFT purchase through module
bytes memory purchaseData = abi.encodeWithSelector(
    NFTManagerModule.executeNFTPurchase.selector,
    marketplace,
    collection,
    tokenId,
    price,
    abi.encodeWithSelector(IMarketplace.buy.selector, tokenId)
);
```

---

## MODULE: ERC-7628 (NFT METADATA JSON SCHEMA VALIDATION)

On-chain validation of NFT metadata structure.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Validates required metadata fields exist
contract MetadataValidator {
    struct MetadataRequirement {
        string[] requiredFields;
        string[] requiredTraitTypes;
        bool requireImage;
        bool requireLegalProperties;
    }

    mapping(address => MetadataRequirement) public collectionRequirements;

    function setRequirements(
        address collection,
        MetadataRequirement calldata requirements
    ) external {
        // Only collection admin can set
        collectionRequirements[collection] = requirements;
    }

    /// @notice Validate metadata hash matches expected schema
    /// @dev Off-chain validation, on-chain hash commitment
    function commitMetadataHash(
        uint256 tokenId,
        bytes32 metadataHash
    ) external {
        // Store hash for later verification
        // Allows proving metadata hasn't been tampered with
    }
}
```

---

## Standards Quick Reference

| Standard | Purpose | Status |
|----------|---------|--------|
| ERC-721 | Unique NFTs | Final |
| ERC-1155 | Multi-token | Final |
| ERC-2981 | Royalties | Final |
| ERC-4337 | Account Abstraction | Final |
| ERC-4907 | Rental NFTs | Final |
| ERC-5192 | Soulbound | Final |
| ERC-5643 | Subscription | Final |
| ERC-6551 | Token-Bound Accounts | Final |
| ERC-6900 | Modular Accounts | Draft |
| ERC-7572 | Contract Metadata | Draft |
| ERC-7510 | Cross-Contract Ref | Draft |
| ERC-7579 | Modular Smart Accounts | Draft |
| ERC-998 | Composable NFTs | Final |
| EIP-5169 | Script URI | Draft |

---

## Chainlink CCIP vs LayerZero Comparison

```
Feature Comparison:
┌─────────────────────┬──────────────────┬──────────────────┐
│ Feature             │ Chainlink CCIP   │ LayerZero        │
├─────────────────────┼──────────────────┼──────────────────┤
│ Security Model      │ DON + Risk Mgmt  │ Ultra Light Node │
│ Decentralization    │ High (Chainlink) │ Medium           │
│ Chains Supported    │ 12+              │ 30+              │
│ Token Transfers     │ Native support   │ Via OFT standard │
│ Arbitrary Messages  │ Yes              │ Yes              │
│ Fee Token           │ LINK or Native   │ Native           │
│ Rate Limiting       │ Built-in         │ Manual           │
│ Programmable        │ Token Pool model │ OApp framework   │
│ Best For            │ High-value, DeFi │ Wide chain reach │
└─────────────────────┴──────────────────┴──────────────────┘

Recommendation:
- Use CCIP for high-value institutional NFT bridges (stronger security guarantees)
- Use LayerZero for consumer NFTs needing widest chain support
- Consider both for redundancy in critical infrastructure
```
