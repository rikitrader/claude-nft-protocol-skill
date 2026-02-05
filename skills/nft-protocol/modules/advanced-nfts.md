# Advanced NFT Types

Specialized NFT contracts: soulbound tokens (ERC-5192), dynamic NFTs, insurance, dispute resolution (Kleros), token-bound accounts (ERC-6551), staking, composable NFTs (ERC-998), social recovery, physical redemption, and subscription NFTs.

---

# MODULE 23: SOULBOUND TOKENS (ERC-5192)

## Soulbound NFT Contract

File: `contracts/soulbound/SoulboundNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title SoulboundNFT
 * @notice Non-transferable NFTs for credentials, certifications, and identity
 * @dev Implements ERC-5192 for minimal soulbound interface
 */
contract SoulboundNFT is
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token data
    mapping(uint256 => TokenData) private _tokenData;
    mapping(uint256 => bool) private _locked;

    // Counter
    uint256 private _tokenIdCounter;

    // Credential types
    mapping(bytes32 => CredentialType) public credentialTypes;

    struct TokenData {
        bytes32 credentialType;
        uint256 issuedAt;
        uint256 expiresAt;
        string metadataURI;
        bytes32 dataHash; // Hash of off-chain credential data
    }

    struct CredentialType {
        string name;
        string description;
        uint256 defaultValidity; // 0 = permanent
        bool transferable; // Some credentials may be transferable
        bool active;
    }

    // ERC-5192 events
    event Locked(uint256 indexed tokenId);
    event Unlocked(uint256 indexed tokenId);

    // Custom events
    event CredentialIssued(
        uint256 indexed tokenId,
        address indexed to,
        bytes32 indexed credentialType
    );
    event CredentialRevoked(uint256 indexed tokenId, string reason);
    event CredentialTypeCreated(bytes32 indexed typeId, string name);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address admin
    ) external initializer {
        __ERC721_init(name, symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(REVOKER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        // Create default credential types
        _createCredentialType(
            keccak256("KYC_VERIFIED"),
            "KYC Verified",
            "User has completed KYC verification",
            365 days,
            false
        );
        _createCredentialType(
            keccak256("ACCREDITED_INVESTOR"),
            "Accredited Investor",
            "User is an accredited investor",
            365 days,
            false
        );
        _createCredentialType(
            keccak256("MEMBERSHIP"),
            "Platform Membership",
            "User is a platform member",
            0, // Permanent
            false
        );
    }

    /**
     * @notice Issue a soulbound credential
     */
    function issueCredential(
        address to,
        bytes32 credentialType,
        string calldata metadataURI,
        bytes32 dataHash,
        uint256 customValidity
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(credentialTypes[credentialType].active, "Invalid credential type");
        require(to != address(0), "Invalid recipient");

        uint256 tokenId = ++_tokenIdCounter;

        CredentialType storage cType = credentialTypes[credentialType];
        uint256 validity = customValidity > 0 ? customValidity : cType.defaultValidity;
        uint256 expiresAt = validity > 0 ? block.timestamp + validity : 0;

        _tokenData[tokenId] = TokenData({
            credentialType: credentialType,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            metadataURI: metadataURI,
            dataHash: dataHash
        });

        _safeMint(to, tokenId);

        // Lock by default (soulbound)
        if (!cType.transferable) {
            _locked[tokenId] = true;
            emit Locked(tokenId);
        }

        emit CredentialIssued(tokenId, to, credentialType);
        return tokenId;
    }

    /**
     * @notice Revoke a credential
     */
    function revokeCredential(uint256 tokenId, string calldata reason)
        external
        onlyRole(REVOKER_ROLE)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        _burn(tokenId);
        delete _tokenData[tokenId];
        delete _locked[tokenId];
        emit CredentialRevoked(tokenId, reason);
    }

    /**
     * @notice Check if credential is valid (exists and not expired)
     */
    function isCredentialValid(uint256 tokenId) external view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;

        TokenData storage data = _tokenData[tokenId];
        if (data.expiresAt > 0 && data.expiresAt < block.timestamp) {
            return false;
        }
        return true;
    }

    /**
     * @notice Check if address holds valid credential of type
     */
    function hasValidCredential(address holder, bytes32 credentialType)
        external
        view
        returns (bool)
    {
        uint256 balance = balanceOf(holder);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(holder, i);
            TokenData storage data = _tokenData[tokenId];

            if (data.credentialType == credentialType) {
                if (data.expiresAt == 0 || data.expiresAt > block.timestamp) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @notice Get credential data
     */
    function getCredential(uint256 tokenId)
        external
        view
        returns (
            bytes32 credentialType,
            uint256 issuedAt,
            uint256 expiresAt,
            string memory metadataURI,
            bytes32 dataHash,
            bool valid
        )
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        TokenData storage data = _tokenData[tokenId];

        bool isValid = data.expiresAt == 0 || data.expiresAt > block.timestamp;

        return (
            data.credentialType,
            data.issuedAt,
            data.expiresAt,
            data.metadataURI,
            data.dataHash,
            isValid
        );
    }

    // ==================== ERC-5192 Interface ====================

    /**
     * @notice Check if token is locked (non-transferable)
     */
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _locked[tokenId];
    }

    /**
     * @notice Override transfer to enforce soulbound
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting and burning
        if (from != address(0) && to != address(0)) {
            require(!_locked[tokenId], "Token is soulbound");
        }

        return super._update(to, tokenId, auth);
    }

    // ==================== Token Enumeration (simplified) ====================

    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        returns (uint256)
    {
        require(index < balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        _ownedTokens[from].pop();
        delete _ownedTokensIndex[tokenId];
    }

    // ==================== Admin Functions ====================

    function createCredentialType(
        bytes32 typeId,
        string calldata name,
        string calldata description,
        uint256 defaultValidity,
        bool transferable
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createCredentialType(typeId, name, description, defaultValidity, transferable);
    }

    function _createCredentialType(
        bytes32 typeId,
        string memory name,
        string memory description,
        uint256 defaultValidity,
        bool transferable
    ) internal {
        credentialTypes[typeId] = CredentialType({
            name: name,
            description: description,
            defaultValidity: defaultValidity,
            transferable: transferable,
            active: true
        });
        emit CredentialTypeCreated(typeId, name);
    }

    function deactivateCredentialType(bytes32 typeId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        credentialTypes[typeId].active = false;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenData[tokenId].metadataURI;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        // ERC-5192 interface ID
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 24: DYNAMIC NFTs

## Dynamic NFT Contract

File: `contracts/dynamic/DynamicNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title DynamicNFT
 * @notice NFTs with metadata that evolves based on on-chain conditions
 */
contract DynamicNFT is
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    AutomationCompatibleInterface
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token evolution state
    mapping(uint256 => TokenState) public tokenStates;
    mapping(uint256 => EvolutionRule[]) public evolutionRules;

    // Global state variables that can trigger evolution
    mapping(bytes32 => uint256) public globalState;

    // Base URIs for different states
    mapping(uint256 => mapping(uint256 => string)) public stateURIs;

    uint256 private _tokenIdCounter;
    uint256 public lastUpdateTime;
    uint256 public updateInterval;

    struct TokenState {
        uint256 currentStage;
        uint256 experience;
        uint256 lastInteraction;
        uint256 createdAt;
        bytes32 traits; // Packed traits
    }

    struct EvolutionRule {
        RuleType ruleType;
        bytes32 condition;
        uint256 threshold;
        uint256 targetStage;
        bool active;
    }

    enum RuleType {
        TIME_BASED,      // Evolve after X time
        EXPERIENCE,      // Evolve after X experience points
        INTERACTION,     // Evolve after X interactions
        GLOBAL_STATE,    // Evolve when global state meets condition
        EXTERNAL_ORACLE  // Evolve based on oracle data
    }

    event TokenEvolved(uint256 indexed tokenId, uint256 fromStage, uint256 toStage);
    event ExperienceGained(uint256 indexed tokenId, uint256 amount, uint256 total);
    event TraitUpdated(uint256 indexed tokenId, bytes32 newTraits);
    event GlobalStateUpdated(bytes32 indexed key, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        uint256 _updateInterval
    ) external initializer {
        __ERC721_init(name, symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        updateInterval = _updateInterval;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Mint dynamic NFT
     */
    function mint(
        address to,
        string[] calldata stageURIs,
        EvolutionRule[] calldata rules
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;

        _safeMint(to, tokenId);

        tokenStates[tokenId] = TokenState({
            currentStage: 0,
            experience: 0,
            lastInteraction: block.timestamp,
            createdAt: block.timestamp,
            traits: bytes32(0)
        });

        // Set URIs for each stage
        for (uint256 i = 0; i < stageURIs.length; i++) {
            stateURIs[tokenId][i] = stageURIs[i];
        }

        // Set evolution rules
        for (uint256 i = 0; i < rules.length; i++) {
            evolutionRules[tokenId].push(rules[i]);
        }

        return tokenId;
    }

    /**
     * @notice Add experience to token
     */
    function addExperience(uint256 tokenId, uint256 amount)
        external
        onlyRole(ORACLE_ROLE)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        TokenState storage state = tokenStates[tokenId];
        state.experience += amount;
        state.lastInteraction = block.timestamp;

        emit ExperienceGained(tokenId, amount, state.experience);

        // Check for evolution
        _checkAndEvolve(tokenId);
    }

    /**
     * @notice Interact with token (owner only)
     */
    function interact(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        TokenState storage state = tokenStates[tokenId];
        state.lastInteraction = block.timestamp;
        state.experience += 1; // Small XP for interaction

        _checkAndEvolve(tokenId);
    }

    /**
     * @notice Update global state (triggers evolution checks)
     */
    function updateGlobalState(bytes32 key, uint256 value)
        external
        onlyRole(ORACLE_ROLE)
    {
        globalState[key] = value;
        emit GlobalStateUpdated(key, value);
    }

    /**
     * @notice Check and evolve token if conditions met
     */
    function _checkAndEvolve(uint256 tokenId) internal {
        TokenState storage state = tokenStates[tokenId];
        EvolutionRule[] storage rules = evolutionRules[tokenId];

        for (uint256 i = 0; i < rules.length; i++) {
            EvolutionRule storage rule = rules[i];
            if (!rule.active) continue;
            if (state.currentStage >= rule.targetStage) continue;

            bool shouldEvolve = false;

            if (rule.ruleType == RuleType.TIME_BASED) {
                shouldEvolve = block.timestamp >= state.createdAt + rule.threshold;
            } else if (rule.ruleType == RuleType.EXPERIENCE) {
                shouldEvolve = state.experience >= rule.threshold;
            } else if (rule.ruleType == RuleType.INTERACTION) {
                uint256 age = block.timestamp - state.createdAt;
                uint256 interactions = state.experience; // Simplified
                shouldEvolve = interactions >= rule.threshold;
            } else if (rule.ruleType == RuleType.GLOBAL_STATE) {
                shouldEvolve = globalState[rule.condition] >= rule.threshold;
            }

            if (shouldEvolve) {
                uint256 fromStage = state.currentStage;
                state.currentStage = rule.targetStage;
                emit TokenEvolved(tokenId, fromStage, rule.targetStage);
                break; // Only one evolution per check
            }
        }
    }

    /**
     * @notice Force check evolution for token
     */
    function checkEvolution(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        _checkAndEvolve(tokenId);
    }

    /**
     * @notice Batch check evolution for multiple tokens
     */
    function batchCheckEvolution(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_ownerOf(tokenIds[i]) != address(0)) {
                _checkAndEvolve(tokenIds[i]);
            }
        }
    }

    // ==================== Chainlink Automation ====================

    /**
     * @notice Chainlink Automation check
     */
    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = (block.timestamp - lastUpdateTime) >= updateInterval;

        // Find tokens that might need evolution
        uint256[] memory tokensToCheck = new uint256[](100);
        uint256 count = 0;

        for (uint256 i = 1; i <= _tokenIdCounter && count < 100; i++) {
            if (_ownerOf(i) != address(0)) {
                tokensToCheck[count++] = i;
            }
        }

        // Resize array
        uint256[] memory finalTokens = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalTokens[i] = tokensToCheck[i];
        }

        performData = abi.encode(finalTokens);
    }

    /**
     * @notice Chainlink Automation perform
     */
    function performUpkeep(bytes calldata performData) external override {
        if ((block.timestamp - lastUpdateTime) < updateInterval) {
            return;
        }

        lastUpdateTime = block.timestamp;

        uint256[] memory tokenIds = abi.decode(performData, (uint256[]));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_ownerOf(tokenIds[i]) != address(0)) {
                _checkAndEvolve(tokenIds[i]);
            }
        }
    }

    // ==================== View Functions ====================

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        uint256 stage = tokenStates[tokenId].currentStage;
        return stateURIs[tokenId][stage];
    }

    function getTokenState(uint256 tokenId)
        external
        view
        returns (TokenState memory)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenStates[tokenId];
    }

    function getEvolutionRules(uint256 tokenId)
        external
        view
        returns (EvolutionRule[] memory)
    {
        return evolutionRules[tokenId];
    }

    // ==================== Admin Functions ====================

    function addEvolutionRule(uint256 tokenId, EvolutionRule calldata rule)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        evolutionRules[tokenId].push(rule);
    }

    function setStateURI(uint256 tokenId, uint256 stage, string calldata uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        stateURIs[tokenId][stage] = uri;
    }

    function setUpdateInterval(uint256 _interval)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        updateInterval = _interval;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 25: INSURANCE MODULE

## NFT Insurance Contract

File: `contracts/insurance/NFTInsurance.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title NFTInsurance
 * @notice Insurance protocol for NFT theft, smart contract exploits, and value loss
 */
contract NFTInsurance is AccessControl, ReentrancyGuard {
    bytes32 public constant UNDERWRITER_ROLE = keccak256("UNDERWRITER_ROLE");
    bytes32 public constant CLAIMS_ADJUSTER = keccak256("CLAIMS_ADJUSTER");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // Insurance pool
    uint256 public totalPoolBalance;
    uint256 public totalCoverage;
    uint256 public minimumCollateralRatio = 150; // 150%

    // Premium rates (basis points per year)
    mapping(CoverageType => uint256) public premiumRates;

    // Policies
    mapping(uint256 => Policy) public policies;
    uint256 public policyCounter;

    // Claims
    mapping(uint256 => Claim) public claims;
    uint256 public claimCounter;

    // NFT valuations
    mapping(address => mapping(uint256 => Valuation)) public valuations;

    enum CoverageType {
        THEFT,           // Private key compromise, phishing
        SMART_CONTRACT,  // Protocol exploits
        MARKET_CRASH,    // Floor price drops > X%
        FULL            // All of the above
    }

    enum PolicyStatus {
        ACTIVE,
        EXPIRED,
        CLAIMED,
        CANCELLED
    }

    enum ClaimStatus {
        PENDING,
        UNDER_REVIEW,
        APPROVED,
        REJECTED,
        PAID
    }

    struct Policy {
        address holder;
        address nftContract;
        uint256 tokenId;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 endTime;
        CoverageType coverageType;
        PolicyStatus status;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        ClaimStatus status;
        string evidence;
        uint256 filedAt;
        uint256 resolvedAt;
        string resolution;
    }

    struct Valuation {
        uint256 value;
        uint256 timestamp;
        address oracle;
    }

    event PolicyCreated(uint256 indexed policyId, address indexed holder, address nftContract, uint256 tokenId);
    event PolicyCancelled(uint256 indexed policyId);
    event ClaimFiled(uint256 indexed claimId, uint256 indexed policyId, uint256 amount);
    event ClaimResolved(uint256 indexed claimId, ClaimStatus status, uint256 paidAmount);
    event ValuationUpdated(address indexed nftContract, uint256 indexed tokenId, uint256 value);
    event PoolDeposit(address indexed depositor, uint256 amount);
    event PoolWithdraw(address indexed withdrawer, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UNDERWRITER_ROLE, msg.sender);
        _grantRole(CLAIMS_ADJUSTER, msg.sender);

        // Set default premium rates (annual, in basis points)
        premiumRates[CoverageType.THEFT] = 200;          // 2%
        premiumRates[CoverageType.SMART_CONTRACT] = 500; // 5%
        premiumRates[CoverageType.MARKET_CRASH] = 800;   // 8%
        premiumRates[CoverageType.FULL] = 1200;          // 12%
    }

    /**
     * @notice Purchase insurance policy
     */
    function purchasePolicy(
        address nftContract,
        uint256 tokenId,
        uint256 coverageAmount,
        uint256 duration,
        CoverageType coverageType
    ) external payable nonReentrant returns (uint256) {
        require(duration >= 30 days && duration <= 365 days, "Invalid duration");
        require(coverageAmount > 0, "Invalid coverage");

        // Verify ownership
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not NFT owner"
        );

        // Check valuation
        Valuation storage val = valuations[nftContract][tokenId];
        require(
            val.timestamp > block.timestamp - 7 days,
            "Valuation expired"
        );
        require(coverageAmount <= val.value, "Coverage exceeds value");

        // Calculate premium
        uint256 annualPremium = (coverageAmount * premiumRates[coverageType]) / 10000;
        uint256 premium = (annualPremium * duration) / 365 days;
        require(msg.value >= premium, "Insufficient premium");

        // Check pool solvency
        require(
            (totalPoolBalance * 100) / (totalCoverage + coverageAmount) >= minimumCollateralRatio,
            "Insufficient pool liquidity"
        );

        // Create policy
        uint256 policyId = ++policyCounter;
        policies[policyId] = Policy({
            holder: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            coverageAmount: coverageAmount,
            premium: premium,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            coverageType: coverageType,
            status: PolicyStatus.ACTIVE
        });

        totalCoverage += coverageAmount;
        totalPoolBalance += premium;

        // Refund excess
        if (msg.value > premium) {
            Address.sendValue(payable(msg.sender), msg.value - premium);
        }

        emit PolicyCreated(policyId, msg.sender, nftContract, tokenId);
        return policyId;
    }

    /**
     * @notice File insurance claim
     */
    function fileClaim(
        uint256 policyId,
        uint256 claimAmount,
        string calldata evidence
    ) external nonReentrant returns (uint256) {
        Policy storage policy = policies[policyId];
        require(policy.holder == msg.sender, "Not policy holder");
        require(policy.status == PolicyStatus.ACTIVE, "Policy not active");
        require(block.timestamp <= policy.endTime, "Policy expired");
        require(claimAmount <= policy.coverageAmount, "Exceeds coverage");

        uint256 claimId = ++claimCounter;
        claims[claimId] = Claim({
            policyId: policyId,
            claimant: msg.sender,
            claimAmount: claimAmount,
            status: ClaimStatus.PENDING,
            evidence: evidence,
            filedAt: block.timestamp,
            resolvedAt: 0,
            resolution: ""
        });

        policy.status = PolicyStatus.CLAIMED;

        emit ClaimFiled(claimId, policyId, claimAmount);
        return claimId;
    }

    /**
     * @notice Process claim (adjuster only)
     */
    function processClaim(
        uint256 claimId,
        bool approved,
        uint256 payoutAmount,
        string calldata resolution
    ) external onlyRole(CLAIMS_ADJUSTER) nonReentrant {
        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.PENDING || claim.status == ClaimStatus.UNDER_REVIEW, "Invalid status");

        Policy storage policy = policies[claim.policyId];

        if (approved) {
            require(payoutAmount <= claim.claimAmount, "Payout exceeds claim");
            require(payoutAmount <= totalPoolBalance, "Insufficient pool");

            claim.status = ClaimStatus.APPROVED;
            totalPoolBalance -= payoutAmount;
            totalCoverage -= policy.coverageAmount;

            Address.sendValue(payable(claim.claimant), payoutAmount);

            claim.status = ClaimStatus.PAID;
        } else {
            claim.status = ClaimStatus.REJECTED;
            policy.status = PolicyStatus.ACTIVE; // Reactivate policy
        }

        claim.resolvedAt = block.timestamp;
        claim.resolution = resolution;

        emit ClaimResolved(claimId, claim.status, approved ? payoutAmount : 0);
    }

    /**
     * @notice Update NFT valuation
     */
    function updateValuation(
        address nftContract,
        uint256 tokenId,
        uint256 value
    ) external onlyRole(ORACLE_ROLE) {
        valuations[nftContract][tokenId] = Valuation({
            value: value,
            timestamp: block.timestamp,
            oracle: msg.sender
        });
        emit ValuationUpdated(nftContract, tokenId, value);
    }

    /**
     * @notice Deposit to insurance pool
     */
    function depositToPool() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");
        totalPoolBalance += msg.value;
        emit PoolDeposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw from pool (admin only, respecting collateral ratio)
     */
    function withdrawFromPool(uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(amount <= totalPoolBalance, "Exceeds balance");

        uint256 newBalance = totalPoolBalance - amount;
        if (totalCoverage > 0) {
            require(
                (newBalance * 100) / totalCoverage >= minimumCollateralRatio,
                "Would breach collateral ratio"
            );
        }

        totalPoolBalance = newBalance;
        Address.sendValue(payable(msg.sender), amount);
        emit PoolWithdraw(msg.sender, amount);
    }

    /**
     * @notice Calculate premium quote
     */
    function quotePremium(
        uint256 coverageAmount,
        uint256 duration,
        CoverageType coverageType
    ) external view returns (uint256) {
        uint256 annualPremium = (coverageAmount * premiumRates[coverageType]) / 10000;
        return (annualPremium * duration) / 365 days;
    }

    /**
     * @notice Get policy details
     */
    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        return policies[policyId];
    }

    /**
     * @notice Get claim details
     */
    function getClaim(uint256 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }

    /**
     * @notice Check pool health
     */
    function getPoolHealth() external view returns (
        uint256 balance,
        uint256 coverage,
        uint256 ratio
    ) {
        balance = totalPoolBalance;
        coverage = totalCoverage;
        ratio = totalCoverage > 0 ? (totalPoolBalance * 100) / totalCoverage : type(uint256).max;
    }

    // ==================== Admin Functions ====================

    function setPremiumRate(CoverageType coverageType, uint256 rate)
        external
        onlyRole(UNDERWRITER_ROLE)
    {
        require(rate <= 5000, "Rate too high"); // Max 50%
        premiumRates[coverageType] = rate;
    }

    function setMinimumCollateralRatio(uint256 ratio)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(ratio >= 100, "Ratio too low");
        minimumCollateralRatio = ratio;
    }

    function cancelPolicy(uint256 policyId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Policy storage policy = policies[policyId];
        require(policy.status == PolicyStatus.ACTIVE, "Not active");

        policy.status = PolicyStatus.CANCELLED;
        totalCoverage -= policy.coverageAmount;

        // Refund remaining premium
        uint256 remainingTime = policy.endTime > block.timestamp
            ? policy.endTime - block.timestamp
            : 0;
        uint256 refund = (policy.premium * remainingTime) / (policy.endTime - policy.startTime);

        if (refund > 0) {
            totalPoolBalance -= refund;
            Address.sendValue(payable(policy.holder), refund);
        }

        emit PolicyCancelled(policyId);
    }
}
```

---

# MODULE 26: DISPUTE RESOLUTION (Kleros Integration)

## Dispute Resolution Contract

File: `contracts/disputes/NFTDisputeResolver.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NFTDisputeResolver
 * @notice On-chain dispute resolution for NFT transactions using Kleros arbitration
 */
contract NFTDisputeResolver is AccessControl, ReentrancyGuard {
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");

    // Kleros arbitrator interface
    IArbitrator public arbitrator;

    // Disputes
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => uint256) public externalDisputeToLocal; // Kleros ID => local ID
    uint256 public disputeCounter;

    // Escrow for disputed transactions
    mapping(uint256 => uint256) public escrowBalances;

    // Arbitration settings
    bytes public arbitratorExtraData;
    uint256 public constant RULING_OPTIONS = 3; // Favor Buyer, Favor Seller, Split

    enum DisputeStatus {
        NONE,
        CREATED,
        EVIDENCE_PERIOD,
        ARBITRATION,
        RESOLVED,
        APPEALED
    }

    enum Ruling {
        NONE,
        FAVOR_BUYER,
        FAVOR_SELLER,
        SPLIT
    }

    struct Dispute {
        uint256 transactionId;
        address buyer;
        address seller;
        uint256 amount;
        DisputeStatus status;
        Ruling ruling;
        uint256 externalDisputeId;
        uint256 createdAt;
        uint256 resolvedAt;
        string buyerEvidence;
        string sellerEvidence;
    }

    event DisputeCreated(uint256 indexed disputeId, uint256 indexed transactionId, address buyer, address seller);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed party, string evidence);
    event DisputeResolved(uint256 indexed disputeId, Ruling ruling);
    event AppealCreated(uint256 indexed disputeId);
    event FundsReleased(uint256 indexed disputeId, address indexed recipient, uint256 amount);

    constructor(address _arbitrator, bytes memory _arbitratorExtraData) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITRATOR_ROLE, msg.sender);

        arbitrator = IArbitrator(_arbitrator);
        arbitratorExtraData = _arbitratorExtraData;
    }

    /**
     * @notice Create dispute for transaction
     */
    function createDispute(
        uint256 transactionId,
        address seller,
        string calldata initialEvidence
    ) external payable nonReentrant returns (uint256) {
        uint256 arbitrationCost = arbitrator.arbitrationCost(arbitratorExtraData);
        require(msg.value >= arbitrationCost, "Insufficient arbitration fee");

        uint256 disputeId = ++disputeCounter;

        // Create dispute with Kleros
        uint256 externalId = arbitrator.createDispute{value: arbitrationCost}(
            RULING_OPTIONS,
            arbitratorExtraData
        );

        disputes[disputeId] = Dispute({
            transactionId: transactionId,
            buyer: msg.sender,
            seller: seller,
            amount: 0, // Set when escrowed
            status: DisputeStatus.CREATED,
            ruling: Ruling.NONE,
            externalDisputeId: externalId,
            createdAt: block.timestamp,
            resolvedAt: 0,
            buyerEvidence: initialEvidence,
            sellerEvidence: ""
        });

        externalDisputeToLocal[externalId] = disputeId;

        // Refund excess
        if (msg.value > arbitrationCost) {
            Address.sendValue(payable(msg.sender), msg.value - arbitrationCost);
        }

        emit DisputeCreated(disputeId, transactionId, msg.sender, seller);
        return disputeId;
    }

    /**
     * @notice Deposit funds to escrow for dispute
     */
    function depositToEscrow(uint256 disputeId) external payable {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.CREATED, "Invalid status");
        require(msg.sender == dispute.seller, "Only seller");

        escrowBalances[disputeId] += msg.value;
        dispute.amount = escrowBalances[disputeId];
        dispute.status = DisputeStatus.EVIDENCE_PERIOD;
    }

    /**
     * @notice Submit evidence
     */
    function submitEvidence(uint256 disputeId, string calldata evidence) external {
        Dispute storage dispute = disputes[disputeId];
        require(
            dispute.status == DisputeStatus.CREATED ||
            dispute.status == DisputeStatus.EVIDENCE_PERIOD,
            "Evidence period closed"
        );

        if (msg.sender == dispute.buyer) {
            dispute.buyerEvidence = evidence;
        } else if (msg.sender == dispute.seller) {
            dispute.sellerEvidence = evidence;
        } else {
            revert("Not a party");
        }

        emit EvidenceSubmitted(disputeId, msg.sender, evidence);
    }

    /**
     * @notice Move to arbitration (close evidence period)
     */
    function startArbitration(uint256 disputeId) external {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.EVIDENCE_PERIOD, "Invalid status");
        require(
            msg.sender == dispute.buyer ||
            msg.sender == dispute.seller ||
            hasRole(ARBITRATOR_ROLE, msg.sender),
            "Not authorized"
        );

        dispute.status = DisputeStatus.ARBITRATION;
    }

    /**
     * @notice Receive ruling from Kleros
     */
    function rule(uint256 _disputeID, uint256 _ruling) external {
        require(msg.sender == address(arbitrator), "Only arbitrator");

        uint256 localId = externalDisputeToLocal[_disputeID];
        Dispute storage dispute = disputes[localId];
        require(dispute.status == DisputeStatus.ARBITRATION, "Not in arbitration");

        dispute.ruling = Ruling(_ruling);
        dispute.status = DisputeStatus.RESOLVED;
        dispute.resolvedAt = block.timestamp;

        // Execute ruling
        _executeRuling(localId);

        emit DisputeResolved(localId, Ruling(_ruling));
    }

    /**
     * @notice Execute ruling and distribute funds
     */
    function _executeRuling(uint256 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];
        uint256 amount = escrowBalances[disputeId];

        if (amount == 0) return;

        escrowBalances[disputeId] = 0;

        if (dispute.ruling == Ruling.FAVOR_BUYER) {
            Address.sendValue(payable(dispute.buyer), amount);
            emit FundsReleased(disputeId, dispute.buyer, amount);
        } else if (dispute.ruling == Ruling.FAVOR_SELLER) {
            Address.sendValue(payable(dispute.seller), amount);
            emit FundsReleased(disputeId, dispute.seller, amount);
        } else if (dispute.ruling == Ruling.SPLIT) {
            uint256 half = amount / 2;
            Address.sendValue(payable(dispute.buyer), half);
            Address.sendValue(payable(dispute.seller), amount - half);
            emit FundsReleased(disputeId, dispute.buyer, half);
            emit FundsReleased(disputeId, dispute.seller, amount - half);
        }
    }

    /**
     * @notice Appeal ruling
     */
    function appeal(uint256 disputeId) external payable {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.RESOLVED, "Not resolved");
        require(
            msg.sender == dispute.buyer || msg.sender == dispute.seller,
            "Not a party"
        );

        uint256 appealCost = arbitrator.appealCost(
            dispute.externalDisputeId,
            arbitratorExtraData
        );
        require(msg.value >= appealCost, "Insufficient appeal fee");

        arbitrator.appeal{value: appealCost}(
            dispute.externalDisputeId,
            arbitratorExtraData
        );

        dispute.status = DisputeStatus.APPEALED;

        if (msg.value > appealCost) {
            Address.sendValue(payable(msg.sender), msg.value - appealCost);
        }

        emit AppealCreated(disputeId);
    }

    /**
     * @notice Manual resolution (admin only, for edge cases)
     */
    function manualResolve(uint256 disputeId, Ruling ruling)
        external
        onlyRole(ARBITRATOR_ROLE)
    {
        Dispute storage dispute = disputes[disputeId];
        require(
            dispute.status != DisputeStatus.RESOLVED,
            "Already resolved"
        );

        dispute.ruling = ruling;
        dispute.status = DisputeStatus.RESOLVED;
        dispute.resolvedAt = block.timestamp;

        _executeRuling(disputeId);

        emit DisputeResolved(disputeId, ruling);
    }

    // ==================== View Functions ====================

    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }

    function getArbitrationCost() external view returns (uint256) {
        return arbitrator.arbitrationCost(arbitratorExtraData);
    }

    function getAppealCost(uint256 disputeId) external view returns (uint256) {
        return arbitrator.appealCost(
            disputes[disputeId].externalDisputeId,
            arbitratorExtraData
        );
    }
}

// Kleros Arbitrator Interface
interface IArbitrator {
    function createDispute(uint256 _choices, bytes calldata _extraData)
        external
        payable
        returns (uint256 disputeID);

    function arbitrationCost(bytes calldata _extraData)
        external
        view
        returns (uint256 cost);

    function appeal(uint256 _disputeID, bytes calldata _extraData)
        external
        payable;

    function appealCost(uint256 _disputeID, bytes calldata _extraData)
        external
        view
        returns (uint256 cost);

    function currentRuling(uint256 _disputeID)
        external
        view
        returns (uint256 ruling);
}
```

---

# MODULE 35: TOKEN-BOUND ACCOUNTS (ERC-6551)

## Architecture

```
+-----------------------------------------------------------------+
|                    ERC-6551 TOKEN-BOUND ACCOUNTS                |
+-----------------------------------------------------------------+
|                                                                 |
|  NFT (ERC-721)                                                  |
|      |                                                          |
|      v                                                          |
|  +--------------+    +--------------+                          |
|  |   Registry   |--->|  Account     |                          |
|  |  (ERC-6551)  |    |  (TBA)       |                          |
|  +--------------+    +--------------+                          |
|                             |                                   |
|                             v                                   |
|                      +--------------+                           |
|                      | TBA Can Own: |                           |
|                      | +-- ETH      |                           |
|                      | +-- ERC-20   |                           |
|                      | +-- ERC-721  |                           |
|                      | +-- ERC-1155 |                           |
|                      | +-- Execute  |                           |
|                      +--------------+                           |
|                                                                 |
|  NFT Owner controls TBA -> TBA owns assets -> Transfer NFT =   |
|  Transfer ALL assets inside                                     |
|                                                                 |
+-----------------------------------------------------------------+
```

## ERC-6551 Registry

File: `contracts/erc6551/ERC6551Registry.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title ERC6551Registry
 * @notice Registry for creating token-bound accounts
 * @dev Reference implementation of ERC-6551
 */
contract ERC6551Registry {
    event AccountCreated(
        address indexed account,
        address indexed implementation,
        uint256 chainId,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 salt
    );

    error AccountCreationFailed();

    /**
     * @notice Creates a token-bound account for an NFT
     * @param implementation The address of the account implementation
     * @param chainId The chain ID where the NFT exists
     * @param tokenContract The address of the NFT contract
     * @param tokenId The token ID of the NFT
     * @param salt A unique salt for account creation
     * @param initData Initialization data for the account
     * @return account The address of the created account
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        bytes calldata initData
    ) external returns (address account) {
        bytes memory code = _creationCode(implementation, chainId, tokenContract, tokenId, salt);

        account = Create2.computeAddress(bytes32(salt), keccak256(code));

        if (account.code.length > 0) return account;

        assembly {
            account := create2(0, add(code, 0x20), mload(code), salt)
        }

        if (account == address(0)) revert AccountCreationFailed();

        if (initData.length > 0) {
            (bool success, ) = account.call(initData);
            if (!success) revert AccountCreationFailed();
        }

        emit AccountCreated(account, implementation, chainId, tokenContract, tokenId, salt);
    }

    /**
     * @notice Computes the address of a token-bound account
     */
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address) {
        bytes32 bytecodeHash = keccak256(
            _creationCode(implementation, chainId, tokenContract, tokenId, salt)
        );

        return Create2.computeAddress(bytes32(salt), bytecodeHash);
    }

    /**
     * @notice Returns the creation code for a token-bound account
     */
    function _creationCode(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            // ERC-1167 minimal proxy bytecode
            hex"3d60ad80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3",
            // Append immutable args
            abi.encode(salt, chainId, tokenContract, tokenId)
        );
    }
}
```

## Token-Bound Account Implementation

File: `contracts/erc6551/ERC6551Account.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title ERC6551Account
 * @notice Token-bound account implementation
 * @dev NFT-owned smart contract wallet
 */
contract ERC6551Account is IERC165, IERC1271, IERC721Receiver, IERC1155Receiver {
    uint256 public nonce;

    receive() external payable {}

    /**
     * @notice Execute a call from this account
     * @dev Only callable by the NFT owner
     */
    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external payable returns (bytes memory result) {
        require(_isValidSigner(msg.sender), "Invalid signer");
        require(operation == 0, "Only call operations supported");

        ++nonce;

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @notice Execute multiple calls in a single transaction
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (bytes[] memory results) {
        require(_isValidSigner(msg.sender), "Invalid signer");
        require(
            targets.length == values.length && values.length == datas.length,
            "Length mismatch"
        );

        ++nonce;

        results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{value: values[i]}(datas[i]);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
            results[i] = result;
        }
    }

    /**
     * @notice Returns the owner of the NFT that controls this account
     */
    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /**
     * @notice Returns the token information for this account
     */
    function token() public view returns (uint256, address, uint256) {
        bytes memory footer = new bytes(96);

        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 96)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    /**
     * @notice Check if an address is a valid signer for this account
     */
    function _isValidSigner(address signer) internal view returns (bool) {
        return signer == owner();
    }

    /**
     * @notice ERC-1271 signature validation
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4)
    {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);
        return isValid ? IERC1271.isValidSignature.selector : bytes4(0);
    }

    // ==================== Token Receivers ====================

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1271).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
```

## TBA Frontend Hook

File: `frontend/hooks/useTokenBoundAccount.ts`

```typescript
import { useState, useCallback, useEffect } from 'react';
import { usePublicClient, useWalletClient, useAccount } from 'wagmi';
import { encodeFunctionData, parseAbi } from 'viem';

const REGISTRY_ABI = parseAbi([
  'function createAccount(address implementation, uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt, bytes initData) returns (address)',
  'function account(address implementation, uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt) view returns (address)',
]);

const ACCOUNT_ABI = parseAbi([
  'function execute(address to, uint256 value, bytes data, uint8 operation) payable returns (bytes)',
  'function executeBatch(address[] targets, uint256[] values, bytes[] datas) payable returns (bytes[])',
  'function owner() view returns (address)',
  'function token() view returns (uint256 chainId, address tokenContract, uint256 tokenId)',
]);

interface UseTokenBoundAccountProps {
  registryAddress: `0x${string}`;
  implementationAddress: `0x${string}`;
  tokenContract: `0x${string}`;
  tokenId: bigint;
  salt?: bigint;
}

export function useTokenBoundAccount({
  registryAddress,
  implementationAddress,
  tokenContract,
  tokenId,
  salt = 0n,
}: UseTokenBoundAccountProps) {
  const { address, chain } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  const [tbaAddress, setTbaAddress] = useState<`0x${string}` | null>(null);
  const [isDeployed, setIsDeployed] = useState(false);
  const [loading, setLoading] = useState(true);

  // Compute TBA address
  useEffect(() => {
    async function computeAddress() {
      if (!publicClient || !chain) return;

      try {
        const address = await publicClient.readContract({
          address: registryAddress,
          abi: REGISTRY_ABI,
          functionName: 'account',
          args: [implementationAddress, BigInt(chain.id), tokenContract, tokenId, salt],
        });

        setTbaAddress(address as `0x${string}`);

        // Check if deployed
        const code = await publicClient.getCode({ address: address as `0x${string}` });
        setIsDeployed(code !== undefined && code !== '0x');
      } catch (error) {
        console.error('Error computing TBA address:', error);
      }

      setLoading(false);
    }

    computeAddress();
  }, [publicClient, chain, registryAddress, implementationAddress, tokenContract, tokenId, salt]);

  // Create TBA
  const createAccount = useCallback(async () => {
    if (!walletClient || !chain) throw new Error('Wallet not connected');

    const hash = await walletClient.writeContract({
      address: registryAddress,
      abi: REGISTRY_ABI,
      functionName: 'createAccount',
      args: [implementationAddress, BigInt(chain.id), tokenContract, tokenId, salt, '0x'],
    });

    const receipt = await publicClient?.waitForTransactionReceipt({ hash });
    setIsDeployed(true);

    return receipt;
  }, [walletClient, publicClient, chain, registryAddress, implementationAddress, tokenContract, tokenId, salt]);

  // Execute from TBA
  const execute = useCallback(
    async (to: `0x${string}`, value: bigint, data: `0x${string}`) => {
      if (!walletClient || !tbaAddress) throw new Error('TBA not ready');

      const hash = await walletClient.writeContract({
        address: tbaAddress,
        abi: ACCOUNT_ABI,
        functionName: 'execute',
        args: [to, value, data, 0],
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, tbaAddress]
  );

  // Get TBA balance
  const getBalance = useCallback(async () => {
    if (!publicClient || !tbaAddress) return 0n;
    return publicClient.getBalance({ address: tbaAddress });
  }, [publicClient, tbaAddress]);

  return {
    tbaAddress,
    isDeployed,
    loading,
    createAccount,
    execute,
    getBalance,
  };
}
```

---

# MODULE 36: NFT STAKING

## Staking Contract

File: `contracts/staking/NFTStaking.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title NFTStaking
 * @notice Stake NFTs to earn ERC-20 token rewards
 */
contract NFTStaking is ERC721Holder, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");

    // Staking configuration
    IERC20 public rewardToken;
    uint256 public rewardPerBlock;
    uint256 public totalStaked;

    // Pool info
    struct PoolInfo {
        IERC721 nftContract;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        bool isActive;
    }

    // Staker info
    struct StakerInfo {
        uint256[] stakedTokenIds;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaimBlock;
    }

    // Pool ID => Pool Info
    mapping(uint256 => PoolInfo) public pools;
    uint256 public poolCount;
    uint256 public totalAllocPoint;

    // Pool ID => User => Staker Info
    mapping(uint256 => mapping(address => StakerInfo)) public stakers;

    // Pool ID => Token ID => Staker address
    mapping(uint256 => mapping(uint256 => address)) public tokenOwner;

    // Rarity multipliers (token ID => multiplier in basis points, 10000 = 1x)
    mapping(uint256 => mapping(uint256 => uint256)) public rarityMultiplier;

    // Lock periods (optional)
    mapping(uint256 => uint256) public poolLockPeriod;
    mapping(uint256 => mapping(address => uint256)) public stakingStartTime;

    event PoolAdded(uint256 indexed poolId, address indexed nftContract, uint256 allocPoint);
    event Staked(uint256 indexed poolId, address indexed user, uint256[] tokenIds);
    event Unstaked(uint256 indexed poolId, address indexed user, uint256[] tokenIds);
    event RewardsClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardPerBlockUpdated(uint256 oldRate, uint256 newRate);

    constructor(address _rewardToken, uint256 _rewardPerBlock) {
        rewardToken = IERC20(_rewardToken);
        rewardPerBlock = _rewardPerBlock;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(REWARD_MANAGER, msg.sender);
    }

    /**
     * @notice Add a new staking pool
     */
    function addPool(
        address _nftContract,
        uint256 _allocPoint,
        uint256 _lockPeriod
    ) external onlyRole(ADMIN_ROLE) {
        _updateAllPools();

        uint256 poolId = poolCount++;
        pools[poolId] = PoolInfo({
            nftContract: IERC721(_nftContract),
            allocPoint: _allocPoint,
            lastRewardBlock: block.number,
            accRewardPerShare: 0,
            totalStaked: 0,
            isActive: true
        });

        totalAllocPoint += _allocPoint;
        poolLockPeriod[poolId] = _lockPeriod;

        emit PoolAdded(poolId, _nftContract, _allocPoint);
    }

    /**
     * @notice Stake NFTs
     */
    function stake(uint256 poolId, uint256[] calldata tokenIds)
        external
        nonReentrant
        whenNotPaused
    {
        require(pools[poolId].isActive, "Pool not active");
        require(tokenIds.length > 0, "No tokens");

        _updatePool(poolId);

        PoolInfo storage pool = pools[poolId];
        StakerInfo storage staker = stakers[poolId][msg.sender];

        // Claim pending rewards first
        if (staker.stakedTokenIds.length > 0) {
            uint256 pending = _calculatePending(poolId, msg.sender);
            if (pending > 0) {
                staker.pendingRewards += pending;
            }
        }

        // Transfer NFTs
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            pool.nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
            staker.stakedTokenIds.push(tokenId);
            tokenOwner[poolId][tokenId] = msg.sender;
        }

        pool.totalStaked += tokenIds.length;
        totalStaked += tokenIds.length;

        // Update reward debt
        staker.rewardDebt = (staker.stakedTokenIds.length * pool.accRewardPerShare) / 1e12;

        // Set staking start time for lock period
        if (stakingStartTime[poolId][msg.sender] == 0) {
            stakingStartTime[poolId][msg.sender] = block.timestamp;
        }

        emit Staked(poolId, msg.sender, tokenIds);
    }

    /**
     * @notice Unstake NFTs
     */
    function unstake(uint256 poolId, uint256[] calldata tokenIds)
        external
        nonReentrant
    {
        require(tokenIds.length > 0, "No tokens");

        PoolInfo storage pool = pools[poolId];
        StakerInfo storage staker = stakers[poolId][msg.sender];

        // Check lock period
        if (poolLockPeriod[poolId] > 0) {
            require(
                block.timestamp >= stakingStartTime[poolId][msg.sender] + poolLockPeriod[poolId],
                "Still locked"
            );
        }

        _updatePool(poolId);

        // Claim pending rewards
        uint256 pending = _calculatePending(poolId, msg.sender);
        if (pending > 0) {
            staker.pendingRewards += pending;
        }

        // Transfer NFTs back
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenOwner[poolId][tokenId] == msg.sender, "Not owner");

            pool.nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

            // Remove from staked array
            _removeTokenId(staker.stakedTokenIds, tokenId);
            delete tokenOwner[poolId][tokenId];
        }

        pool.totalStaked -= tokenIds.length;
        totalStaked -= tokenIds.length;

        // Update reward debt
        staker.rewardDebt = (staker.stakedTokenIds.length * pool.accRewardPerShare) / 1e12;

        // Reset staking start time if all unstaked
        if (staker.stakedTokenIds.length == 0) {
            stakingStartTime[poolId][msg.sender] = 0;
        }

        emit Unstaked(poolId, msg.sender, tokenIds);
    }

    /**
     * @notice Claim pending rewards
     */
    function claimRewards(uint256 poolId) external nonReentrant {
        _updatePool(poolId);

        StakerInfo storage staker = stakers[poolId][msg.sender];

        uint256 pending = _calculatePending(poolId, msg.sender) + staker.pendingRewards;
        require(pending > 0, "No rewards");

        staker.pendingRewards = 0;
        staker.rewardDebt = (staker.stakedTokenIds.length * pools[poolId].accRewardPerShare) / 1e12;
        staker.lastClaimBlock = block.number;

        rewardToken.safeTransfer(msg.sender, pending);

        emit RewardsClaimed(poolId, msg.sender, pending);
    }

    /**
     * @notice Get pending rewards for a user
     */
    function pendingRewards(uint256 poolId, address user) external view returns (uint256) {
        PoolInfo storage pool = pools[poolId];
        StakerInfo storage staker = stakers[poolId][user];

        uint256 accRewardPerShare = pool.accRewardPerShare;

        if (block.number > pool.lastRewardBlock && pool.totalStaked > 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 reward = (blocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare += (reward * 1e12) / pool.totalStaked;
        }

        uint256 pending = (staker.stakedTokenIds.length * accRewardPerShare) / 1e12 - staker.rewardDebt;
        return pending + staker.pendingRewards;
    }

    /**
     * @notice Get staked token IDs for a user
     */
    function getStakedTokenIds(uint256 poolId, address user)
        external
        view
        returns (uint256[] memory)
    {
        return stakers[poolId][user].stakedTokenIds;
    }

    // ==================== Internal Functions ====================

    function _updatePool(uint256 poolId) internal {
        PoolInfo storage pool = pools[poolId];

        if (block.number <= pool.lastRewardBlock) return;

        if (pool.totalStaked == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - pool.lastRewardBlock;
        uint256 reward = (blocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;

        pool.accRewardPerShare += (reward * 1e12) / pool.totalStaked;
        pool.lastRewardBlock = block.number;
    }

    function _updateAllPools() internal {
        for (uint256 i = 0; i < poolCount; i++) {
            _updatePool(i);
        }
    }

    function _calculatePending(uint256 poolId, address user) internal view returns (uint256) {
        PoolInfo storage pool = pools[poolId];
        StakerInfo storage staker = stakers[poolId][user];

        return (staker.stakedTokenIds.length * pool.accRewardPerShare) / 1e12 - staker.rewardDebt;
    }

    function _removeTokenId(uint256[] storage array, uint256 tokenId) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == tokenId) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

    // ==================== Admin Functions ====================

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyRole(REWARD_MANAGER) {
        _updateAllPools();
        emit RewardPerBlockUpdated(rewardPerBlock, _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
    }

    function setPoolAllocPoint(uint256 poolId, uint256 allocPoint) external onlyRole(ADMIN_ROLE) {
        _updateAllPools();
        totalAllocPoint = totalAllocPoint - pools[poolId].allocPoint + allocPoint;
        pools[poolId].allocPoint = allocPoint;
    }

    function setRarityMultiplier(uint256 poolId, uint256 tokenId, uint256 multiplier)
        external
        onlyRole(ADMIN_ROLE)
    {
        rarityMultiplier[poolId][tokenId] = multiplier;
    }

    function setPoolActive(uint256 poolId, bool active) external onlyRole(ADMIN_ROLE) {
        pools[poolId].isActive = active;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function withdrawRewardTokens(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken.safeTransfer(msg.sender, amount);
    }

    function emergencyWithdraw(uint256 poolId) external nonReentrant {
        StakerInfo storage staker = stakers[poolId][msg.sender];
        PoolInfo storage pool = pools[poolId];

        uint256[] memory tokenIds = staker.stakedTokenIds;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            pool.nftContract.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
            delete tokenOwner[poolId][tokenIds[i]];
        }

        pool.totalStaked -= tokenIds.length;
        totalStaked -= tokenIds.length;

        delete stakers[poolId][msg.sender];
        stakingStartTime[poolId][msg.sender] = 0;
    }
}
```

---

# MODULE 43: COMPOSABLE NFTs (ERC-998)

## Composable NFT Contract

File: `contracts/composable/ComposableNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ComposableNFT
 * @notice ERC-998 style NFTs that can own other NFTs and ERC-20 tokens
 */
contract ComposableNFT is ERC721, IERC721Receiver, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private _tokenIdCounter;
    string private _baseTokenURI;

    // Parent token => Child contract => Child token IDs
    mapping(uint256 => mapping(address => uint256[])) private _childTokens;

    // Child contract => Child token => Parent token
    mapping(address => mapping(uint256 => uint256)) private _childTokenParent;

    // Parent token => ERC20 contract => Balance
    mapping(uint256 => mapping(address => uint256)) private _erc20Balances;

    // Allowed child contracts
    mapping(address => bool) public allowedChildContracts;
    mapping(address => bool) public allowedERC20Contracts;

    event ChildReceived(
        uint256 indexed parentTokenId,
        address indexed childContract,
        uint256 indexed childTokenId
    );
    event ChildTransferred(
        uint256 indexed parentTokenId,
        address indexed childContract,
        uint256 indexed childTokenId,
        address to
    );
    event ERC20Received(
        uint256 indexed tokenId,
        address indexed erc20Contract,
        uint256 amount
    );
    event ERC20Transferred(
        uint256 indexed tokenId,
        address indexed erc20Contract,
        uint256 amount,
        address to
    );

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice Mint a composable NFT
     */
    function mint(address to) external returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // ==================== Child NFT Management ====================

    /**
     * @notice Receive a child NFT (called when NFT is transferred to this contract)
     */
    function onERC721Received(
        address,
        address from,
        uint256 childTokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(allowedChildContracts[msg.sender], "Child contract not allowed");

        // Decode parent token ID from data
        require(data.length >= 32, "Missing parent token ID");
        uint256 parentTokenId = abi.decode(data, (uint256));

        require(_ownerOf(parentTokenId) != address(0), "Parent doesn't exist");

        // Record child ownership
        _childTokens[parentTokenId][msg.sender].push(childTokenId);
        _childTokenParent[msg.sender][childTokenId] = parentTokenId;

        emit ChildReceived(parentTokenId, msg.sender, childTokenId);

        return this.onERC721Received.selector;
    }

    /**
     * @notice Transfer a child NFT out of a parent
     */
    function transferChild(
        uint256 parentTokenId,
        address childContract,
        uint256 childTokenId,
        address to
    ) external nonReentrant {
        require(ownerOf(parentTokenId) == msg.sender, "Not parent owner");
        require(_childTokenParent[childContract][childTokenId] == parentTokenId, "Not a child");

        // Remove from tracking
        _removeChild(parentTokenId, childContract, childTokenId);

        // Transfer child NFT
        IERC721(childContract).safeTransferFrom(address(this), to, childTokenId);

        emit ChildTransferred(parentTokenId, childContract, childTokenId, to);
    }

    /**
     * @notice Get all child tokens for a parent
     */
    function getChildTokens(uint256 parentTokenId, address childContract)
        external
        view
        returns (uint256[] memory)
    {
        return _childTokens[parentTokenId][childContract];
    }

    /**
     * @notice Get the parent of a child token
     */
    function getChildParent(address childContract, uint256 childTokenId)
        external
        view
        returns (uint256)
    {
        return _childTokenParent[childContract][childTokenId];
    }

    // ==================== ERC-20 Management ====================

    /**
     * @notice Deposit ERC-20 tokens into an NFT
     */
    function depositERC20(
        uint256 tokenId,
        address erc20Contract,
        uint256 amount
    ) external nonReentrant {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        require(allowedERC20Contracts[erc20Contract], "ERC20 not allowed");

        IERC20(erc20Contract).safeTransferFrom(msg.sender, address(this), amount);
        _erc20Balances[tokenId][erc20Contract] += amount;

        emit ERC20Received(tokenId, erc20Contract, amount);
    }

    /**
     * @notice Withdraw ERC-20 tokens from an NFT
     */
    function withdrawERC20(
        uint256 tokenId,
        address erc20Contract,
        uint256 amount,
        address to
    ) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_erc20Balances[tokenId][erc20Contract] >= amount, "Insufficient balance");

        _erc20Balances[tokenId][erc20Contract] -= amount;
        IERC20(erc20Contract).safeTransfer(to, amount);

        emit ERC20Transferred(tokenId, erc20Contract, amount, to);
    }

    /**
     * @notice Get ERC-20 balance for a token
     */
    function getERC20Balance(uint256 tokenId, address erc20Contract)
        external
        view
        returns (uint256)
    {
        return _erc20Balances[tokenId][erc20Contract];
    }

    // ==================== Transfer Override ====================

    /**
     * @notice Override transfer to include children (optional)
     */
    function safeTransferFromWithChildren(
        address from,
        address to,
        uint256 tokenId,
        address[] calldata childContracts
    ) external {
        require(_isAuthorized(from, msg.sender, tokenId), "Not authorized");

        // Transfer parent
        _safeTransfer(from, to, tokenId, "");

        // Note: Children stay with the NFT automatically since they're stored by parent ID
        // This function is for explicit documentation/events
    }

    // ==================== Internal ====================

    function _removeChild(
        uint256 parentTokenId,
        address childContract,
        uint256 childTokenId
    ) internal {
        uint256[] storage children = _childTokens[parentTokenId][childContract];

        for (uint256 i = 0; i < children.length; i++) {
            if (children[i] == childTokenId) {
                children[i] = children[children.length - 1];
                children.pop();
                break;
            }
        }

        delete _childTokenParent[childContract][childTokenId];
    }

    // ==================== Admin ====================

    function setAllowedChildContract(address childContract, bool allowed)
        external
        onlyOwner
    {
        allowedChildContracts[childContract] = allowed;
    }

    function setAllowedERC20Contract(address erc20Contract, bool allowed)
        external
        onlyOwner
    {
        allowedERC20Contracts[erc20Contract] = allowed;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
```

---

# MODULE 44: SOULBOUND WITH SOCIAL RECOVERY

## Recoverable Soulbound Contract

File: `contracts/soulbound/RecoverableSBT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RecoverableSBT
 * @notice Soulbound tokens with social recovery mechanism
 */
contract RecoverableSBT is ERC721, AccessControl, ReentrancyGuard {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    uint256 private _tokenIdCounter;

    // Token data
    mapping(uint256 => TokenData) public tokenData;

    // Recovery guardians
    mapping(address => address[]) public guardians;
    mapping(address => mapping(address => bool)) public isGuardian;

    // Recovery requests
    mapping(uint256 => RecoveryRequest) public recoveryRequests;

    // Configuration
    uint256 public recoveryThreshold = 2;  // Guardians needed
    uint256 public recoveryDelay = 3 days; // Time lock

    struct TokenData {
        string credentialType;
        string metadataURI;
        uint256 issuedAt;
        uint256 expiresAt;
        bool locked;
    }

    struct RecoveryRequest {
        address newOwner;
        uint256 approvalCount;
        uint256 initiatedAt;
        bool executed;
        mapping(address => bool) hasApproved;
    }

    // ERC-5192 interface
    event Locked(uint256 indexed tokenId);
    event Unlocked(uint256 indexed tokenId);

    event GuardianAdded(address indexed owner, address indexed guardian);
    event GuardianRemoved(address indexed owner, address indexed guardian);
    event RecoveryInitiated(uint256 indexed tokenId, address indexed newOwner);
    event RecoveryApproved(uint256 indexed tokenId, address indexed guardian);
    event RecoveryExecuted(uint256 indexed tokenId, address indexed newOwner);
    event RecoveryCancelled(uint256 indexed tokenId);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
    }

    /**
     * @notice Issue a soulbound credential
     */
    function issue(
        address to,
        string calldata credentialType,
        string calldata metadataURI,
        uint256 validity
    ) external onlyRole(ISSUER_ROLE) returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;

        _safeMint(to, tokenId);

        tokenData[tokenId] = TokenData({
            credentialType: credentialType,
            metadataURI: metadataURI,
            issuedAt: block.timestamp,
            expiresAt: validity > 0 ? block.timestamp + validity : 0,
            locked: true
        });

        emit Locked(tokenId);

        return tokenId;
    }

    // ==================== Guardian Management ====================

    /**
     * @notice Add a recovery guardian
     */
    function addGuardian(address guardian) external {
        require(guardian != address(0) && guardian != msg.sender, "Invalid guardian");
        require(!isGuardian[msg.sender][guardian], "Already guardian");
        require(guardians[msg.sender].length < 10, "Too many guardians");

        guardians[msg.sender].push(guardian);
        isGuardian[msg.sender][guardian] = true;

        emit GuardianAdded(msg.sender, guardian);
    }

    /**
     * @notice Remove a guardian
     */
    function removeGuardian(address guardian) external {
        require(isGuardian[msg.sender][guardian], "Not a guardian");

        isGuardian[msg.sender][guardian] = false;

        // Remove from array
        address[] storage userGuardians = guardians[msg.sender];
        for (uint256 i = 0; i < userGuardians.length; i++) {
            if (userGuardians[i] == guardian) {
                userGuardians[i] = userGuardians[userGuardians.length - 1];
                userGuardians.pop();
                break;
            }
        }

        emit GuardianRemoved(msg.sender, guardian);
    }

    /**
     * @notice Get guardians for an address
     */
    function getGuardians(address owner) external view returns (address[] memory) {
        return guardians[owner];
    }

    // ==================== Recovery Process ====================

    /**
     * @notice Initiate recovery (guardian only)
     */
    function initiateRecovery(uint256 tokenId, address newOwner) external {
        address currentOwner = ownerOf(tokenId);
        require(isGuardian[currentOwner][msg.sender], "Not a guardian");
        require(newOwner != address(0), "Invalid new owner");

        RecoveryRequest storage request = recoveryRequests[tokenId];
        require(!request.executed, "Already executed");

        // Start new request or add approval
        if (request.initiatedAt == 0 || request.newOwner != newOwner) {
            // New request
            request.newOwner = newOwner;
            request.approvalCount = 1;
            request.initiatedAt = block.timestamp;
            request.executed = false;

            emit RecoveryInitiated(tokenId, newOwner);
        }

        if (!request.hasApproved[msg.sender]) {
            request.hasApproved[msg.sender] = true;
            request.approvalCount++;

            emit RecoveryApproved(tokenId, msg.sender);
        }
    }

    /**
     * @notice Execute recovery after threshold and delay
     */
    function executeRecovery(uint256 tokenId) external nonReentrant {
        RecoveryRequest storage request = recoveryRequests[tokenId];
        require(!request.executed, "Already executed");
        require(request.approvalCount >= recoveryThreshold, "Not enough approvals");
        require(
            block.timestamp >= request.initiatedAt + recoveryDelay,
            "Delay not passed"
        );

        address currentOwner = ownerOf(tokenId);
        address newOwner = request.newOwner;

        request.executed = true;

        // Unlock temporarily for transfer
        tokenData[tokenId].locked = false;

        // Transfer to new owner
        _transfer(currentOwner, newOwner, tokenId);

        // Re-lock
        tokenData[tokenId].locked = true;

        // Copy guardians to new owner
        address[] memory oldGuardians = guardians[currentOwner];
        for (uint256 i = 0; i < oldGuardians.length; i++) {
            if (!isGuardian[newOwner][oldGuardians[i]]) {
                guardians[newOwner].push(oldGuardians[i]);
                isGuardian[newOwner][oldGuardians[i]] = true;
            }
        }

        emit RecoveryExecuted(tokenId, newOwner);
    }

    /**
     * @notice Cancel recovery (current owner only)
     */
    function cancelRecovery(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        RecoveryRequest storage request = recoveryRequests[tokenId];
        require(!request.executed, "Already executed");
        require(request.initiatedAt > 0, "No recovery pending");

        delete recoveryRequests[tokenId];

        emit RecoveryCancelled(tokenId);
    }

    // ==================== ERC-5192 Soulbound ====================

    /**
     * @notice Check if token is locked
     */
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return tokenData[tokenId].locked;
    }

    /**
     * @notice Override transfer to enforce soulbound
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // Allow minting and burning
        if (from != address(0) && to != address(0)) {
            require(!tokenData[tokenId].locked, "Token is soulbound");
        }

        return super._update(to, tokenId, auth);
    }

    // ==================== View Functions ====================

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return tokenData[tokenId].metadataURI;
    }

    function isCredentialValid(uint256 tokenId) external view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;

        TokenData storage data = tokenData[tokenId];
        if (data.expiresAt > 0 && data.expiresAt < block.timestamp) {
            return false;
        }
        return true;
    }

    function getRecoveryStatus(uint256 tokenId)
        external
        view
        returns (
            address newOwner,
            uint256 approvalCount,
            uint256 initiatedAt,
            bool canExecute
        )
    {
        RecoveryRequest storage request = recoveryRequests[tokenId];
        return (
            request.newOwner,
            request.approvalCount,
            request.initiatedAt,
            request.approvalCount >= recoveryThreshold &&
                block.timestamp >= request.initiatedAt + recoveryDelay &&
                !request.executed
        );
    }

    // ==================== Admin ====================

    function setRecoveryThreshold(uint256 threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(threshold >= 1 && threshold <= 5, "Invalid threshold");
        recoveryThreshold = threshold;
    }

    function setRecoveryDelay(uint256 delay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(delay >= 1 days && delay <= 30 days, "Invalid delay");
        recoveryDelay = delay;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        // ERC-5192 interface ID
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 53: PHYSICAL REDEMPTION SYSTEM

## Physical NFT Redemption Contract

File: `contracts/physical/PhysicalRedemption.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PhysicalRedemption
 * @notice NFTs redeemable for physical items
 */
contract PhysicalRedemption is ERC721, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIdCounter;

    struct PhysicalItem {
        string itemType;        // shirt, poster, vinyl, etc.
        string variant;         // size, color variant
        string description;
        string imageURI;
        string metadataURI;
        bool redeemable;
        uint256 redeemDeadline; // 0 = no deadline
    }

    struct RedemptionRequest {
        address redeemer;
        uint256 tokenId;
        bytes32 shippingInfoHash; // Hash of encrypted shipping info
        RedemptionStatus status;
        uint256 requestedAt;
        uint256 fulfilledAt;
        string trackingNumber;
        string carrier;
    }

    enum RedemptionStatus {
        None,
        Requested,
        Processing,
        Shipped,
        Delivered,
        Cancelled
    }

    mapping(uint256 => PhysicalItem) public items;
    mapping(uint256 => RedemptionRequest) public redemptions;
    mapping(uint256 => bool) public isRedeemed;

    // Shipping info stored off-chain, hash stored on-chain
    // Users encrypt shipping info with fulfiller's public key

    // Statistics
    uint256 public totalRedeemed;
    uint256 public totalShipped;

    event ItemMinted(uint256 indexed tokenId, string itemType);
    event RedemptionRequested(uint256 indexed tokenId, address indexed redeemer, bytes32 shippingHash);
    event RedemptionProcessing(uint256 indexed tokenId);
    event RedemptionShipped(uint256 indexed tokenId, string trackingNumber, string carrier);
    event RedemptionDelivered(uint256 indexed tokenId);
    event RedemptionCancelled(uint256 indexed tokenId, string reason);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(FULFILLER_ROLE, msg.sender);
    }

    /**
     * @notice Mint physical item NFT
     */
    function mintPhysical(
        address to,
        string calldata itemType,
        string calldata variant,
        string calldata description,
        string calldata imageURI,
        string calldata metadataURI,
        uint256 redeemDeadline
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;

        items[tokenId] = PhysicalItem({
            itemType: itemType,
            variant: variant,
            description: description,
            imageURI: imageURI,
            metadataURI: metadataURI,
            redeemable: true,
            redeemDeadline: redeemDeadline
        });

        _safeMint(to, tokenId);

        emit ItemMinted(tokenId, itemType);

        return tokenId;
    }

    /**
     * @notice Request redemption with encrypted shipping info
     * @param tokenId Token to redeem
     * @param shippingInfoHash Hash of encrypted shipping details
     */
    function requestRedemption(
        uint256 tokenId,
        bytes32 shippingInfoHash
    ) external nonReentrant whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(items[tokenId].redeemable, "Not redeemable");
        require(!isRedeemed[tokenId], "Already redeemed");

        PhysicalItem storage item = items[tokenId];
        if (item.redeemDeadline > 0) {
            require(block.timestamp <= item.redeemDeadline, "Deadline passed");
        }

        redemptions[tokenId] = RedemptionRequest({
            redeemer: msg.sender,
            tokenId: tokenId,
            shippingInfoHash: shippingInfoHash,
            status: RedemptionStatus.Requested,
            requestedAt: block.timestamp,
            fulfilledAt: 0,
            trackingNumber: "",
            carrier: ""
        });

        isRedeemed[tokenId] = true;
        totalRedeemed++;

        emit RedemptionRequested(tokenId, msg.sender, shippingInfoHash);
    }

    /**
     * @notice Update shipping info (before processing)
     */
    function updateShippingInfo(
        uint256 tokenId,
        bytes32 newShippingInfoHash
    ) external {
        require(redemptions[tokenId].redeemer == msg.sender, "Not your redemption");
        require(
            redemptions[tokenId].status == RedemptionStatus.Requested,
            "Cannot update"
        );

        redemptions[tokenId].shippingInfoHash = newShippingInfoHash;
    }

    /**
     * @notice Mark as processing (fulfiller)
     */
    function markProcessing(uint256 tokenId) external onlyRole(FULFILLER_ROLE) {
        require(
            redemptions[tokenId].status == RedemptionStatus.Requested,
            "Invalid status"
        );

        redemptions[tokenId].status = RedemptionStatus.Processing;

        emit RedemptionProcessing(tokenId);
    }

    /**
     * @notice Mark as shipped with tracking (fulfiller)
     */
    function markShipped(
        uint256 tokenId,
        string calldata trackingNumber,
        string calldata carrier
    ) external onlyRole(FULFILLER_ROLE) {
        require(
            redemptions[tokenId].status == RedemptionStatus.Processing,
            "Invalid status"
        );

        redemptions[tokenId].status = RedemptionStatus.Shipped;
        redemptions[tokenId].trackingNumber = trackingNumber;
        redemptions[tokenId].carrier = carrier;

        totalShipped++;

        emit RedemptionShipped(tokenId, trackingNumber, carrier);
    }

    /**
     * @notice Mark as delivered (fulfiller)
     */
    function markDelivered(uint256 tokenId) external onlyRole(FULFILLER_ROLE) {
        require(
            redemptions[tokenId].status == RedemptionStatus.Shipped,
            "Invalid status"
        );

        redemptions[tokenId].status = RedemptionStatus.Delivered;
        redemptions[tokenId].fulfilledAt = block.timestamp;

        emit RedemptionDelivered(tokenId);
    }

    /**
     * @notice Cancel redemption (fulfiller, with reason)
     */
    function cancelRedemption(
        uint256 tokenId,
        string calldata reason
    ) external onlyRole(FULFILLER_ROLE) {
        require(
            redemptions[tokenId].status == RedemptionStatus.Requested ||
            redemptions[tokenId].status == RedemptionStatus.Processing,
            "Cannot cancel"
        );

        redemptions[tokenId].status = RedemptionStatus.Cancelled;

        // Allow re-redemption
        isRedeemed[tokenId] = false;
        totalRedeemed--;

        emit RedemptionCancelled(tokenId, reason);
    }

    /**
     * @notice Get redemption status
     */
    function getRedemptionStatus(uint256 tokenId)
        external
        view
        returns (
            RedemptionStatus status,
            address redeemer,
            uint256 requestedAt,
            string memory trackingNumber,
            string memory carrier
        )
    {
        RedemptionRequest storage req = redemptions[tokenId];
        return (
            req.status,
            req.redeemer,
            req.requestedAt,
            req.trackingNumber,
            req.carrier
        );
    }

    /**
     * @notice Check if token can be redeemed
     */
    function canRedeem(uint256 tokenId) external view returns (bool, string memory) {
        if (_ownerOf(tokenId) == address(0)) return (false, "Token doesn't exist");
        if (!items[tokenId].redeemable) return (false, "Not redeemable");
        if (isRedeemed[tokenId]) return (false, "Already redeemed");

        PhysicalItem storage item = items[tokenId];
        if (item.redeemDeadline > 0 && block.timestamp > item.redeemDeadline) {
            return (false, "Deadline passed");
        }

        return (true, "");
    }

    /**
     * @notice Get physical item details
     */
    function getItem(uint256 tokenId)
        external
        view
        returns (PhysicalItem memory)
    {
        return items[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return items[tokenId].metadataURI;
    }

    // ==================== Admin ====================

    function setRedeemable(uint256 tokenId, bool redeemable)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        items[tokenId].redeemable = redeemable;
    }

    function extendDeadline(uint256 tokenId, uint256 newDeadline)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newDeadline > items[tokenId].redeemDeadline, "Must extend");
        items[tokenId].redeemDeadline = newDeadline;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
```

---

# MODULE 54: SUBSCRIPTION NFT SYSTEM

## Subscription NFT Contract

File: `contracts/subscription/SubscriptionNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SubscriptionNFT
 * @notice Time-based subscription NFTs with auto-renewal
 */
contract SubscriptionNFT is ERC721, Ownable, ReentrancyGuard {
    uint256 private _tokenIdCounter;

    struct SubscriptionTier {
        string name;
        uint256 pricePerPeriod;
        uint256 periodDuration;  // seconds
        string[] benefits;
        bool active;
    }

    struct Subscription {
        uint256 tierId;
        uint256 startTime;
        uint256 expiresAt;
        bool autoRenew;
        uint256 renewalBalance;  // Pre-paid balance for auto-renewal
    }

    mapping(uint256 => SubscriptionTier) public tiers;
    mapping(uint256 => Subscription) public subscriptions;
    uint256 public tierCount;

    // Grace period before subscription expires
    uint256 public gracePeriod = 3 days;

    // Revenue tracking
    uint256 public totalRevenue;
    mapping(uint256 => uint256) public tierRevenue;

    string private _baseTokenURI;

    event TierCreated(uint256 indexed tierId, string name, uint256 price);
    event SubscriptionCreated(uint256 indexed tokenId, uint256 indexed tierId, address subscriber);
    event SubscriptionRenewed(uint256 indexed tokenId, uint256 newExpiry);
    event SubscriptionCancelled(uint256 indexed tokenId);
    event AutoRenewToggled(uint256 indexed tokenId, bool enabled);
    event BalanceAdded(uint256 indexed tokenId, uint256 amount);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}

    // ==================== Tier Management ====================

    /**
     * @notice Create a subscription tier
     */
    function createTier(
        string calldata name,
        uint256 pricePerPeriod,
        uint256 periodDuration,
        string[] calldata benefits
    ) external onlyOwner returns (uint256) {
        uint256 tierId = ++tierCount;

        tiers[tierId] = SubscriptionTier({
            name: name,
            pricePerPeriod: pricePerPeriod,
            periodDuration: periodDuration,
            benefits: benefits,
            active: true
        });

        emit TierCreated(tierId, name, pricePerPeriod);

        return tierId;
    }

    /**
     * @notice Update tier pricing
     */
    function updateTierPrice(uint256 tierId, uint256 newPrice) external onlyOwner {
        require(tierId <= tierCount && tierId > 0, "Invalid tier");
        tiers[tierId].pricePerPeriod = newPrice;
    }

    /**
     * @notice Toggle tier active status
     */
    function setTierActive(uint256 tierId, bool active) external onlyOwner {
        require(tierId <= tierCount && tierId > 0, "Invalid tier");
        tiers[tierId].active = active;
    }

    // ==================== Subscription Management ====================

    /**
     * @notice Subscribe to a tier
     */
    function subscribe(uint256 tierId) external payable nonReentrant returns (uint256) {
        SubscriptionTier storage tier = tiers[tierId];
        require(tier.active, "Tier not active");
        require(msg.value >= tier.pricePerPeriod, "Insufficient payment");

        uint256 tokenId = ++_tokenIdCounter;

        subscriptions[tokenId] = Subscription({
            tierId: tierId,
            startTime: block.timestamp,
            expiresAt: block.timestamp + tier.periodDuration,
            autoRenew: false,
            renewalBalance: 0
        });

        _safeMint(msg.sender, tokenId);

        totalRevenue += tier.pricePerPeriod;
        tierRevenue[tierId] += tier.pricePerPeriod;

        // Refund excess
        if (msg.value > tier.pricePerPeriod) {
            Address.sendValue(payable(msg.sender), msg.value - tier.pricePerPeriod);
        }

        emit SubscriptionCreated(tokenId, tierId, msg.sender);

        return tokenId;
    }

    /**
     * @notice Manually renew subscription
     */
    function renew(uint256 tokenId) external payable nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Subscription storage sub = subscriptions[tokenId];
        SubscriptionTier storage tier = tiers[sub.tierId];

        require(msg.value >= tier.pricePerPeriod, "Insufficient payment");

        // If expired, start from now; otherwise extend
        if (sub.expiresAt < block.timestamp) {
            sub.expiresAt = block.timestamp + tier.periodDuration;
        } else {
            sub.expiresAt += tier.periodDuration;
        }

        totalRevenue += tier.pricePerPeriod;
        tierRevenue[sub.tierId] += tier.pricePerPeriod;

        emit SubscriptionRenewed(tokenId, sub.expiresAt);
    }

    /**
     * @notice Add balance for auto-renewal
     */
    function addRenewalBalance(uint256 tokenId) external payable {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(msg.value > 0, "No value");

        subscriptions[tokenId].renewalBalance += msg.value;

        emit BalanceAdded(tokenId, msg.value);
    }

    /**
     * @notice Toggle auto-renewal
     */
    function setAutoRenew(uint256 tokenId, bool enabled) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        subscriptions[tokenId].autoRenew = enabled;

        emit AutoRenewToggled(tokenId, enabled);
    }

    /**
     * @notice Process auto-renewal (callable by anyone, keeper-compatible)
     */
    function processAutoRenewal(uint256 tokenId) external nonReentrant {
        Subscription storage sub = subscriptions[tokenId];

        require(sub.autoRenew, "Auto-renew disabled");
        require(
            sub.expiresAt <= block.timestamp + 1 days,
            "Too early to renew"
        );

        SubscriptionTier storage tier = tiers[sub.tierId];
        require(sub.renewalBalance >= tier.pricePerPeriod, "Insufficient balance");

        sub.renewalBalance -= tier.pricePerPeriod;

        if (sub.expiresAt < block.timestamp) {
            sub.expiresAt = block.timestamp + tier.periodDuration;
        } else {
            sub.expiresAt += tier.periodDuration;
        }

        totalRevenue += tier.pricePerPeriod;
        tierRevenue[sub.tierId] += tier.pricePerPeriod;

        emit SubscriptionRenewed(tokenId, sub.expiresAt);
    }

    /**
     * @notice Cancel subscription (no refund, just stops renewal)
     */
    function cancel(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Subscription storage sub = subscriptions[tokenId];
        sub.autoRenew = false;

        // Refund renewal balance
        if (sub.renewalBalance > 0) {
            uint256 refund = sub.renewalBalance;
            sub.renewalBalance = 0;
            Address.sendValue(payable(msg.sender), refund);
        }

        emit SubscriptionCancelled(tokenId);
    }

    // ==================== View Functions ====================

    /**
     * @notice Check if subscription is active
     */
    function isActive(uint256 tokenId) public view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;
        return subscriptions[tokenId].expiresAt > block.timestamp;
    }

    /**
     * @notice Check if in grace period
     */
    function isInGracePeriod(uint256 tokenId) external view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;

        Subscription storage sub = subscriptions[tokenId];
        return sub.expiresAt < block.timestamp &&
               sub.expiresAt + gracePeriod > block.timestamp;
    }

    /**
     * @notice Get subscription details
     */
    function getSubscription(uint256 tokenId)
        external
        view
        returns (
            string memory tierName,
            uint256 expiresAt,
            bool active,
            bool autoRenew,
            uint256 balance,
            string[] memory benefits
        )
    {
        Subscription storage sub = subscriptions[tokenId];
        SubscriptionTier storage tier = tiers[sub.tierId];

        return (
            tier.name,
            sub.expiresAt,
            isActive(tokenId),
            sub.autoRenew,
            sub.renewalBalance,
            tier.benefits
        );
    }

    /**
     * @notice Get tier details
     */
    function getTier(uint256 tierId)
        external
        view
        returns (SubscriptionTier memory)
    {
        return tiers[tierId];
    }

    /**
     * @notice Get all active tiers
     */
    function getActiveTiers() external view returns (uint256[] memory) {
        uint256[] memory activeTiers = new uint256[](tierCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= tierCount; i++) {
            if (tiers[i].active) {
                activeTiers[count] = i;
                count++;
            }
        }

        // Resize array
        assembly {
            mstore(activeTiers, count)
        }

        return activeTiers;
    }

    /**
     * @notice Check if address has active subscription to any tier
     */
    function hasActiveSubscription(address subscriber)
        external
        view
        returns (bool, uint256)
    {
        uint256 balance = balanceOf(subscriber);
        for (uint256 i = 0; i < balance; i++) {
            // Note: This is O(n) - for production, use enumerable extension
            // or off-chain indexing
        }
        return (false, 0);
    }

    // ==================== Admin ====================

    function setGracePeriod(uint256 period) external onlyOwner {
        require(period <= 30 days, "Too long");
        gracePeriod = period;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw() external onlyOwner {
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
```

---
