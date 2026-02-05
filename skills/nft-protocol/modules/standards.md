# ERC Standards Extensions

Additional ERC standard implementations: ERC-5643 (subscription extension) and EIP-5169 (script URI for client-side execution).

---

# MODULE 60: ERC-5643 SUBSCRIPTION EXTENSION

## Subscription Extension Contract

File: `contracts/subscription/ERC5643Subscription.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title ERC5643Subscription
 * @notice ERC-5643 compliant subscription NFT standard
 */
contract ERC5643Subscription is ERC721, Ownable, ReentrancyGuard {

    // ERC-5643 events
    event SubscriptionUpdate(uint256 indexed tokenId, uint64 expiration);

    uint256 private _tokenIdCounter;

    // Subscription data
    mapping(uint256 => uint64) private _expirations;

    // Subscription plans
    struct Plan {
        string name;
        uint256 price;
        uint64 duration;
        bool active;
    }

    mapping(uint256 => Plan) public plans;
    uint256 public planCount;

    // Token to plan mapping
    mapping(uint256 => uint256) public tokenPlan;

    // Renewable flag
    bool public isRenewable = true;

    string private _baseTokenURI;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}

    // ==================== ERC-5643 Interface ====================

    /**
     * @notice Renew subscription (ERC-5643)
     */
    function renewSubscription(uint256 tokenId, uint64 duration) external payable {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        require(isRenewable, "Not renewable");

        uint256 planId = tokenPlan[tokenId];
        Plan storage plan = plans[planId];

        // Calculate price for duration
        uint256 price = (plan.price * duration) / plan.duration;
        require(msg.value >= price, "Insufficient payment");

        _extendSubscription(tokenId, duration);

        // Refund excess
        if (msg.value > price) {
            Address.sendValue(payable(msg.sender), msg.value - price);
        }
    }

    /**
     * @notice Cancel subscription (ERC-5643)
     */
    function cancelSubscription(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        // Note: This implementation doesn't provide refunds
        // Could be modified to support pro-rata refunds

        delete _expirations[tokenId];
        emit SubscriptionUpdate(tokenId, 0);
    }

    /**
     * @notice Get expiration time (ERC-5643)
     */
    function expiresAt(uint256 tokenId) external view returns (uint64) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return _expirations[tokenId];
    }

    /**
     * @notice Check if subscription is valid (ERC-5643)
     */
    function isRenewable(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return isRenewable;
    }

    // ==================== Subscription Management ====================

    /**
     * @notice Create a subscription plan
     */
    function createPlan(
        string calldata name,
        uint256 price,
        uint64 duration
    ) external onlyOwner returns (uint256) {
        uint256 planId = ++planCount;

        plans[planId] = Plan({
            name: name,
            price: price,
            duration: duration,
            active: true
        });

        return planId;
    }

    /**
     * @notice Subscribe to a plan
     */
    function subscribe(uint256 planId) external payable nonReentrant returns (uint256) {
        Plan storage plan = plans[planId];
        require(plan.active, "Plan not active");
        require(msg.value >= plan.price, "Insufficient payment");

        uint256 tokenId = ++_tokenIdCounter;

        _safeMint(msg.sender, tokenId);
        tokenPlan[tokenId] = planId;
        _expirations[tokenId] = uint64(block.timestamp) + plan.duration;

        emit SubscriptionUpdate(tokenId, _expirations[tokenId]);

        // Refund excess
        if (msg.value > plan.price) {
            Address.sendValue(payable(msg.sender), msg.value - plan.price);
        }

        return tokenId;
    }

    /**
     * @notice Check if subscription is active
     */
    function isSubscriptionActive(uint256 tokenId) public view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) return false;
        return _expirations[tokenId] > block.timestamp;
    }

    /**
     * @notice Get time remaining on subscription
     */
    function timeRemaining(uint256 tokenId) external view returns (uint64) {
        if (!isSubscriptionActive(tokenId)) return 0;
        return _expirations[tokenId] - uint64(block.timestamp);
    }

    /**
     * @notice Extend subscription
     */
    function _extendSubscription(uint256 tokenId, uint64 duration) internal {
        uint64 currentExpiration = _expirations[tokenId];
        uint64 newExpiration;

        if (currentExpiration > block.timestamp) {
            // Still active, extend from current expiration
            newExpiration = currentExpiration + duration;
        } else {
            // Expired, start from now
            newExpiration = uint64(block.timestamp) + duration;
        }

        _expirations[tokenId] = newExpiration;
        emit SubscriptionUpdate(tokenId, newExpiration);
    }

    // ==================== Admin ====================

    function setPlanActive(uint256 planId, bool active) external onlyOwner {
        plans[planId].active = active;
    }

    function setPlanPrice(uint256 planId, uint256 price) external onlyOwner {
        plans[planId].price = price;
    }

    function setRenewable(bool _isRenewable) external onlyOwner {
        isRenewable = _isRenewable;
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

    /**
     * @notice ERC-5643 interface support
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        // ERC-5643 interface ID
        return interfaceId == 0x8c65f84d || super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 61: EIP-5169 SCRIPT URI

## Script URI Extension Contract

File: `contracts/scripting/ScriptableNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ScriptableNFT
 * @notice EIP-5169 compliant NFT with client-side scripting support
 */
contract ScriptableNFT is ERC721, Ownable {

    // EIP-5169 event
    event ScriptUpdate(string[] newScriptURI);

    uint256 private _tokenIdCounter;

    // Global scripts for the collection
    string[] private _scriptURIs;

    // Per-token custom scripts (optional)
    mapping(uint256 => string[]) private _tokenScripts;

    // Script metadata
    struct ScriptInfo {
        string name;
        string description;
        string version;
        string integrity; // SRI hash
    }

    mapping(uint256 => ScriptInfo) public scriptInfos; // index => info
    uint256 public scriptCount;

    string private _baseTokenURI;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}

    // ==================== EIP-5169 Interface ====================

    /**
     * @notice Get script URIs (EIP-5169)
     */
    function scriptURI() external view returns (string[] memory) {
        return _scriptURIs;
    }

    /**
     * @notice Set script URIs (EIP-5169)
     */
    function setScriptURI(string[] memory newScriptURIs) external onlyOwner {
        _scriptURIs = newScriptURIs;
        emit ScriptUpdate(newScriptURIs);
    }

    // ==================== Extended Functionality ====================

    /**
     * @notice Add a script with metadata
     */
    function addScript(
        string calldata uri,
        string calldata name,
        string calldata description,
        string calldata version,
        string calldata integrity
    ) external onlyOwner returns (uint256) {
        _scriptURIs.push(uri);

        uint256 scriptId = scriptCount++;
        scriptInfos[scriptId] = ScriptInfo({
            name: name,
            description: description,
            version: version,
            integrity: integrity
        });

        emit ScriptUpdate(_scriptURIs);

        return scriptId;
    }

    /**
     * @notice Update a specific script
     */
    function updateScript(
        uint256 index,
        string calldata uri,
        string calldata version,
        string calldata integrity
    ) external onlyOwner {
        require(index < _scriptURIs.length, "Invalid index");

        _scriptURIs[index] = uri;
        scriptInfos[index].version = version;
        scriptInfos[index].integrity = integrity;

        emit ScriptUpdate(_scriptURIs);
    }

    /**
     * @notice Remove a script
     */
    function removeScript(uint256 index) external onlyOwner {
        require(index < _scriptURIs.length, "Invalid index");

        // Shift array
        for (uint256 i = index; i < _scriptURIs.length - 1; i++) {
            _scriptURIs[i] = _scriptURIs[i + 1];
            scriptInfos[i] = scriptInfos[i + 1];
        }
        _scriptURIs.pop();
        delete scriptInfos[_scriptURIs.length];
        scriptCount--;

        emit ScriptUpdate(_scriptURIs);
    }

    /**
     * @notice Get token-specific scripts
     */
    function tokenScriptURI(uint256 tokenId) external view returns (string[] memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        string[] memory tokenScripts = _tokenScripts[tokenId];

        // If no token-specific scripts, return collection scripts
        if (tokenScripts.length == 0) {
            return _scriptURIs;
        }

        return tokenScripts;
    }

    /**
     * @notice Set token-specific scripts (owner of token)
     */
    function setTokenScriptURI(uint256 tokenId, string[] calldata scripts) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        _tokenScripts[tokenId] = scripts;
    }

    /**
     * @notice Get script info
     */
    function getScriptInfo(uint256 index) external view returns (ScriptInfo memory) {
        require(index < scriptCount, "Invalid index");
        return scriptInfos[index];
    }

    /**
     * @notice Get all scripts with metadata
     */
    function getAllScripts() external view returns (
        string[] memory uris,
        ScriptInfo[] memory infos
    ) {
        uris = _scriptURIs;
        infos = new ScriptInfo[](_scriptURIs.length);

        for (uint256 i = 0; i < _scriptURIs.length; i++) {
            infos[i] = scriptInfos[i];
        }
    }

    // ==================== Minting ====================

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // ==================== Admin ====================

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice EIP-5169 interface support
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        // EIP-5169 interface ID: 0xa86517a1
        return interfaceId == 0xa86517a1 || super.supportsInterface(interfaceId);
    }
}
```

---
