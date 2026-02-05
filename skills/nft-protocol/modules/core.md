# Core Contracts

Foundational smart contracts: ERC-721 (upgradeable, RBAC, pausable, royalties) and UUPS proxy setup.

## MODULE 1: SECURE ERC-721 (UPGRADEABLE + RBAC + PAUSE + ROYALTIES)

File: `contracts/ERC721SecureUUPS.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
SECURE ERC-721 (Upgradeable / UUPS)
- AccessControl roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE, UPGRADER_ROLE
- Pausable transfers
- ERC2981 royalties
- Optional: baseURI + tokenURI storage
- Minting with supply cap
*/

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ERC721SecureUUPS is
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC2981Upgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE   = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE   = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public maxSupply;
    uint256 public totalMinted;

    string private _baseTokenURI;

    event BaseURISet(string newBaseURI);
    event MaxSupplySet(uint256 newMaxSupply);
    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        address admin_,
        address royaltyReceiver_,
        uint96 royaltyFeeNumerator_ // e.g. 500 = 5% if denominator is 10_000
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __ERC2981_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        require(admin_ != address(0), "admin=0");
        require(maxSupply_ > 0, "maxSupply=0");

        _baseTokenURI = baseURI_;
        maxSupply = maxSupply_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        if (royaltyReceiver_ != address(0) && royaltyFeeNumerator_ > 0) {
            _setDefaultRoyalty(royaltyReceiver_, royaltyFeeNumerator_);
            emit DefaultRoyaltySet(royaltyReceiver_, royaltyFeeNumerator_);
        }
    }

    // ---------------- Admin / Config ----------------

    function setBaseURI(string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMaxSupply >= totalMinted, "below minted");
        maxSupply = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(receiver != address(0), "receiver=0");
        _setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // ---------------- Minting ----------------

    function safeMint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        _enforceSupplyCap(1);
        _safeMint(to, tokenId);
        totalMinted += 1;
    }

    // Convenience mint that auto-ids (1..N). TokenURI is baseURI + tokenId.
    function safeMintAutoId(address to) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        _enforceSupplyCap(1);
        tokenId = totalMinted + 1;
        _safeMint(to, tokenId);
        totalMinted += 1;
    }

    // Optional: set per-token URI (if you prefer full tokenURI storage)
    function setTokenURI(uint256 tokenId, string calldata uri) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "no token");
        _setTokenURI(tokenId, uri);
    }

    function _enforceSupplyCap(uint256 amount) internal view {
        require(totalMinted + amount <= maxSupply, "maxSupply reached");
    }

    // ---------------- Hooks / Overrides ----------------

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        // If URIStorage has a value, use it, else default to baseURI + tokenId
        string memory stored = ERC721URIStorageUpgradeable.tokenURI(tokenId);
        if (bytes(stored).length > 0) {
            return stored;
        }
        return string.concat(_baseURI(), Strings.toString(tokenId));
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC2981Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ---------------- UUPS Authorization ----------------

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
```

---

## MODULE 2: UPGRADEABLE PROXY SETUP (HARDHAT + OZ UPGRADES)

### Installation

```bash
npm i --save-dev hardhat @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades
```

### hardhat.config.js

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.20",
};
```

### Deploy Script: `scripts/deploy_erc721_uups.js`

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  const ERC721SecureUUPS = await ethers.getContractFactory("ERC721SecureUUPS");

  const name = "SecureNFT";
  const symbol = "SNFT";
  const baseURI = "ipfs://YOUR_CID/";
  const maxSupply = 10000;
  const admin = deployer.address;

  const royaltyReceiver = deployer.address;
  const royaltyFeeNumerator = 500; // 5% (denominator 10_000)

  const proxy = await upgrades.deployProxy(
    ERC721SecureUUPS,
    [name, symbol, baseURI, maxSupply, admin, royaltyReceiver, royaltyFeeNumerator],
    { kind: "uups", initializer: "initialize" }
  );

  await proxy.waitForDeployment();

  console.log("Proxy address:", await proxy.getAddress());
  console.log("Admin (deployer):", deployer.address);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

### Upgrade Script: `scripts/upgrade_erc721_uups.js`

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = process.env.PROXY;
  if (!proxyAddress) throw new Error("Set PROXY env var");

  const ERC721SecureUUPS_V2 = await ethers.getContractFactory("ERC721SecureUUPS"); // or new V2 contract
  const upgraded = await upgrades.upgradeProxy(proxyAddress, ERC721SecureUUPS_V2);

  console.log("Upgraded proxy:", await upgraded.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

---
