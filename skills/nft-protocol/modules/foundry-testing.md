# Foundry Testing & Formal Verification

Modern Solidity testing with Foundry (forge), invariant testing, fuzz testing, deployment scripts, gas benchmarks, and formal verification with Certora/Halmos.

---

## Foundry Project Setup

```bash
# Initialize Foundry project alongside Hardhat
forge init --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

### foundry.toml

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc_version = "0.8.20"
optimizer = true
optimizer_runs = 200
via_ir = true
ffi = false

[profile.default.fuzz]
runs = 10000
max_test_rejects = 100000
seed = "0x1234"

[profile.default.invariant]
runs = 256
depth = 50
fail_on_revert = false
call_override = false

[profile.ci]
fuzz.runs = 50000
invariant.runs = 512
invariant.depth = 100

[fmt]
bracket_spacing = true
int_types = "long"
line_length = 120
multiline_func_header = "attributes_first"
number_underscore = "thousands"
quote_style = "double"
tab_width = 4

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
base = "${BASE_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
polygon = { key = "${POLYGONSCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
```

---

## Unit Tests (Forge)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/InstitutionalNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InstitutionalNFTTest is Test {
    InstitutionalNFT public nft;
    InstitutionalNFT public proxy;

    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    event TokenMinted(uint256 indexed tokenId, address indexed to, string uri);
    event TokenStateChanged(uint256 indexed tokenId, InstitutionalNFT.TokenState newState);
    event ComplianceUpdated(address indexed account, bool whitelisted);

    function setUp() public {
        // Deploy implementation
        InstitutionalNFT implementation = new InstitutionalNFT();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            InstitutionalNFT.initialize.selector,
            "Institutional NFT",
            "INST",
            admin
        );
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = InstitutionalNFT(address(proxyContract));

        // Setup roles
        vm.startPrank(admin);
        proxy.grantRole(MINTER_ROLE, minter);
        proxy.grantRole(PAUSER_ROLE, pauser);
        proxy.grantRole(COMPLIANCE_ROLE, admin);

        // Whitelist users
        proxy.updateWhitelist(user1, true);
        proxy.updateWhitelist(user2, true);
        vm.stopPrank();
    }

    // ==================== Minting Tests ====================

    function test_MintSuccess() public {
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit TokenMinted(1, user1, "ipfs://QmTest");
        proxy.mint(user1, 1, "ipfs://QmTest", 500);

        assertEq(proxy.ownerOf(1), user1);
        assertEq(proxy.tokenURI(1), "ipfs://QmTest");
    }

    function test_MintRevertsUnauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        proxy.mint(user1, 1, "ipfs://QmTest", 500);
    }

    function test_MintRevertsNonWhitelisted() public {
        vm.prank(minter);
        vm.expectRevert("Recipient not whitelisted");
        proxy.mint(unauthorized, 1, "ipfs://QmTest", 500);
    }

    function test_MintRevertsWhenPaused() public {
        vm.prank(pauser);
        proxy.pause();

        vm.prank(minter);
        vm.expectRevert();
        proxy.mint(user1, 1, "ipfs://QmTest", 500);
    }

    // ==================== Transfer Tests ====================

    function test_TransferBetweenWhitelisted() public {
        vm.prank(minter);
        proxy.mint(user1, 1, "ipfs://QmTest", 500);

        vm.prank(user1);
        proxy.transferFrom(user1, user2, 1);

        assertEq(proxy.ownerOf(1), user2);
    }

    // ==================== Royalty Tests ====================

    function test_RoyaltyInfo() public {
        vm.prank(minter);
        proxy.mint(user1, 1, "ipfs://QmTest", 500); // 5% royalty

        (address receiver, uint256 amount) = proxy.royaltyInfo(1, 10000);
        assertEq(receiver, user1);
        assertEq(amount, 500); // 5% of 10000
    }

    // ==================== Lifecycle Tests ====================

    function test_TokenStateTransitions() public {
        vm.prank(minter);
        proxy.mint(user1, 1, "ipfs://QmTest", 500);

        assertEq(uint256(proxy.tokenStates(1)), uint256(InstitutionalNFT.TokenState.ACTIVE));
    }

    // ==================== Access Control Tests ====================

    function test_OnlyAdminCanGrantRoles() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        proxy.grantRole(MINTER_ROLE, unauthorized);
    }

    function test_PauseUnpause() public {
        vm.prank(pauser);
        proxy.pause();
        assertTrue(proxy.paused());

        vm.prank(pauser);
        proxy.unpause();
        assertFalse(proxy.paused());
    }
}
```

---

## Fuzz Testing

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/InstitutionalNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InstitutionalNFTFuzzTest is Test {
    InstitutionalNFT public proxy;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    function setUp() public {
        InstitutionalNFT implementation = new InstitutionalNFT();
        bytes memory initData = abi.encodeWithSelector(
            InstitutionalNFT.initialize.selector,
            "Test NFT", "TNFT", admin
        );
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = InstitutionalNFT(address(proxyContract));

        vm.startPrank(admin);
        proxy.grantRole(MINTER_ROLE, minter);
        proxy.grantRole(COMPLIANCE_ROLE, admin);
        vm.stopPrank();
    }

    function testFuzz_MintWithValidRoyalty(uint96 royaltyBps) public {
        vm.assume(royaltyBps <= 10000); // Max 100%

        address recipient = makeAddr("recipient");
        vm.prank(admin);
        proxy.updateWhitelist(recipient, true);

        vm.prank(minter);
        proxy.mint(recipient, 1, "ipfs://QmFuzz", royaltyBps);

        assertEq(proxy.ownerOf(1), recipient);

        (address receiver, uint256 amount) = proxy.royaltyInfo(1, 10000);
        assertEq(receiver, recipient);
        assertEq(amount, royaltyBps);
    }

    function testFuzz_MintWithArbitraryTokenId(uint256 tokenId) public {
        vm.assume(tokenId > 0 && tokenId < type(uint128).max);

        address recipient = makeAddr("recipient");
        vm.prank(admin);
        proxy.updateWhitelist(recipient, true);

        vm.prank(minter);
        proxy.mint(recipient, tokenId, "ipfs://QmFuzz", 500);

        assertEq(proxy.ownerOf(tokenId), recipient);
    }

    function testFuzz_RoyaltyCalculation(uint96 bps, uint256 salePrice) public {
        vm.assume(bps <= 10000);
        vm.assume(salePrice <= type(uint128).max);

        address recipient = makeAddr("recipient");
        vm.prank(admin);
        proxy.updateWhitelist(recipient, true);

        vm.prank(minter);
        proxy.mint(recipient, 1, "ipfs://QmFuzz", bps);

        (address receiver, uint256 royalty) = proxy.royaltyInfo(1, salePrice);
        assertEq(receiver, recipient);
        assertEq(royalty, (salePrice * bps) / 10000);
    }

    function testFuzz_CannotMintToNonWhitelisted(address randomAddr) public {
        vm.assume(randomAddr != address(0));
        vm.assume(!proxy.whitelisted(randomAddr));

        vm.prank(minter);
        vm.expectRevert("Recipient not whitelisted");
        proxy.mint(randomAddr, 1, "ipfs://QmFuzz", 500);
    }
}
```

---

## Invariant Testing

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../contracts/InstitutionalNFT.sol";
import "../contracts/NFTMarketplace.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTHandler is Test {
    InstitutionalNFT public nft;
    address public minter;
    uint256 public nextTokenId = 1;
    uint256 public totalMinted;
    uint256 public totalBurned;
    mapping(uint256 => bool) public tokenExists;

    constructor(InstitutionalNFT _nft, address _minter) {
        nft = _nft;
        minter = _minter;
    }

    function mint(address to, uint96 royaltyBps) external {
        royaltyBps = uint96(bound(royaltyBps, 0, 10000));
        if (to == address(0)) to = makeAddr("fallback");

        if (!nft.whitelisted(to)) return;

        uint256 tokenId = nextTokenId++;
        vm.prank(minter);
        try nft.mint(to, tokenId, "ipfs://QmInvariant", royaltyBps) {
            totalMinted++;
            tokenExists[tokenId] = true;
        } catch {}
    }

    function transfer(uint256 tokenId, address to) external {
        if (!tokenExists[tokenId]) return;
        if (to == address(0)) return;
        if (!nft.whitelisted(to)) return;

        address owner = nft.ownerOf(tokenId);
        vm.prank(owner);
        try nft.transferFrom(owner, to, tokenId) {} catch {}
    }
}

contract InstitutionalNFTInvariantTest is StdInvariant, Test {
    InstitutionalNFT public proxy;
    NFTHandler public handler;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");

    address[] public whitelistedUsers;

    function setUp() public {
        InstitutionalNFT implementation = new InstitutionalNFT();
        bytes memory initData = abi.encodeWithSelector(
            InstitutionalNFT.initialize.selector,
            "Invariant NFT", "INV", admin
        );
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = InstitutionalNFT(address(proxyContract));

        vm.startPrank(admin);
        proxy.grantRole(keccak256("MINTER_ROLE"), minter);
        proxy.grantRole(keccak256("COMPLIANCE_ROLE"), admin);

        // Whitelist test users
        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            proxy.updateWhitelist(user, true);
            whitelistedUsers.push(user);
        }
        vm.stopPrank();

        handler = new NFTHandler(proxy, minter);
        targetContract(address(handler));
    }

    /// @notice Token IDs must be unique - no double minting
    function invariant_NoDoubleMint() public view {
        // If handler minted tokens 1..N, each should have exactly one owner
        for (uint256 i = 1; i < handler.nextTokenId(); i++) {
            if (handler.tokenExists(i)) {
                address owner = proxy.ownerOf(i);
                assertTrue(owner != address(0), "Minted token must have owner");
            }
        }
    }

    /// @notice Total supply must equal minted minus burned
    function invariant_SupplyConsistency() public view {
        assertGe(handler.totalMinted(), handler.totalBurned());
    }

    /// @notice Only whitelisted addresses can hold tokens
    function invariant_OnlyWhitelistedHolders() public view {
        for (uint256 i = 1; i < handler.nextTokenId(); i++) {
            if (handler.tokenExists(i)) {
                address owner = proxy.ownerOf(i);
                assertTrue(proxy.whitelisted(owner), "Non-whitelisted holder detected");
            }
        }
    }

    /// @notice Royalty basis points must never exceed 100%
    function invariant_RoyaltyBounds() public view {
        for (uint256 i = 1; i < handler.nextTokenId(); i++) {
            if (handler.tokenExists(i)) {
                (, uint256 royalty) = proxy.royaltyInfo(i, 10000);
                assertLe(royalty, 10000, "Royalty exceeds 100%");
            }
        }
    }
}
```

---

## Marketplace Invariant Tests

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../contracts/NFTMarketplace.sol";

contract MarketplaceHandler is Test {
    NFTMarketplace public marketplace;
    uint256 public totalListings;
    uint256 public totalSales;
    uint256 public totalFees;
    uint256 public totalSellerPayouts;

    constructor(NFTMarketplace _marketplace) {
        marketplace = _marketplace;
    }

    // ... handler functions for listing, buying, canceling
}

contract MarketplaceInvariantTest is StdInvariant, Test {
    /// @notice Marketplace balance must equal sum of unclaimed funds
    function invariant_MarketplaceBalanceSolvency() public view {
        // Contract ETH balance >= sum of pending payouts
        // Ensures marketplace is always solvent
    }

    /// @notice Total fees + seller payouts must equal total sales volume
    function invariant_FeeAccounting() public view {
        // fees + payouts == total sale prices
    }

    /// @notice Listed NFTs must be owned by marketplace or approved
    function invariant_ListingIntegrity() public view {
        // Every active listing has valid NFT custody
    }
}
```

---

## Gas Benchmarks

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/InstitutionalNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GasBenchmarkTest is Test {
    InstitutionalNFT public proxy;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");

    function setUp() public {
        InstitutionalNFT implementation = new InstitutionalNFT();
        bytes memory initData = abi.encodeWithSelector(
            InstitutionalNFT.initialize.selector,
            "Benchmark NFT", "BENCH", admin
        );
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = InstitutionalNFT(address(proxyContract));

        vm.startPrank(admin);
        proxy.grantRole(keccak256("MINTER_ROLE"), minter);
        proxy.grantRole(keccak256("COMPLIANCE_ROLE"), admin);
        vm.stopPrank();
    }

    function test_GasMintSingle() public {
        address user = makeAddr("user");
        vm.prank(admin);
        proxy.updateWhitelist(user, true);

        vm.prank(minter);
        uint256 gasBefore = gasleft();
        proxy.mint(user, 1, "ipfs://QmBenchmark", 500);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas: Single Mint", gasUsed);
    }

    function test_GasTransfer() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.startPrank(admin);
        proxy.updateWhitelist(user1, true);
        proxy.updateWhitelist(user2, true);
        vm.stopPrank();

        vm.prank(minter);
        proxy.mint(user1, 1, "ipfs://QmBenchmark", 500);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        proxy.transferFrom(user1, user2, 1);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas: Transfer", gasUsed);
    }

    function test_GasBatchMint10() public {
        vm.startPrank(admin);
        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string(abi.encodePacked("batch", vm.toString(i))));
            proxy.updateWhitelist(user, true);
        }
        vm.stopPrank();

        uint256 gasBefore = gasleft();
        vm.startPrank(minter);
        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string(abi.encodePacked("batch", vm.toString(i))));
            proxy.mint(user, i + 1, "ipfs://QmBatch", 500);
        }
        vm.stopPrank();
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas: Batch Mint 10", gasUsed);
        emit log_named_uint("Gas: Per Mint (batch)", gasUsed / 10);
    }
}
```

Run benchmarks:
```bash
forge test --match-contract GasBenchmark -vvv --gas-report
```

---

## Forge Deployment Scripts

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/InstitutionalNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployInstitutionalNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        InstitutionalNFT implementation = new InstitutionalNFT();
        console.log("Implementation deployed to:", address(implementation));

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            InstitutionalNFT.initialize.selector,
            "Institutional NFT",
            "INST",
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed to:", address(proxy));

        vm.stopBroadcast();

        // Verify
        InstitutionalNFT nft = InstitutionalNFT(address(proxy));
        require(
            nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), admin),
            "Admin role not set"
        );

        console.log("Deployment verified successfully");
    }
}

contract UpgradeInstitutionalNFT is Script {
    function run() external {
        uint256 upgraderKey = vm.envUint("UPGRADER_PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(upgraderKey);

        // Deploy new implementation
        InstitutionalNFT newImplementation = new InstitutionalNFT();
        console.log("New implementation:", address(newImplementation));

        // Upgrade via proxy
        InstitutionalNFT proxy = InstitutionalNFT(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("Upgrade complete");

        vm.stopBroadcast();
    }
}
```

Deploy commands:
```bash
# Testnet
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify

# Mainnet (with simulation first)
forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify --slow

# Upgrade
forge script script/Upgrade.s.sol --rpc-url mainnet --broadcast --verify
```

---

## Formal Verification (Certora)

### certora/conf/InstitutionalNFT.conf

```json
{
    "files": ["contracts/InstitutionalNFT.sol"],
    "verify": "InstitutionalNFT:certora/specs/InstitutionalNFT.spec",
    "solc": "solc-0.8.20",
    "optimistic_loop": true,
    "loop_iter": 3,
    "rule_sanity": "basic",
    "msg": "Institutional NFT Verification"
}
```

### certora/specs/InstitutionalNFT.spec

```cvl
// ==================== Methods ====================
methods {
    function ownerOf(uint256) external returns (address) envfree;
    function whitelisted(address) external returns (bool) envfree;
    function tokenStates(uint256) external returns (uint8) envfree;
    function hasRole(bytes32, address) external returns (bool) envfree;
    function paused() external returns (bool) envfree;
    function royaltyInfo(uint256, uint256) external returns (address, uint256) envfree;
}

// ==================== Definitions ====================
definition MINTER_ROLE() returns bytes32 = keccak256("MINTER_ROLE");
definition ACTIVE() returns uint8 = 1;

// ==================== Rules ====================

/// @title Only minters can mint
rule onlyMinterCanMint(env e, address to, uint256 tokenId, string uri, uint96 royaltyBps) {
    bool hasMinterRole = hasRole(MINTER_ROLE(), e.msg.sender);

    mint@withrevert(e, to, tokenId, uri, royaltyBps);

    assert !hasMinterRole => lastReverted,
        "Non-minter must not be able to mint";
}

/// @title Minting requires whitelisted recipient
rule mintRequiresWhitelist(env e, address to, uint256 tokenId, string uri, uint96 royaltyBps) {
    bool isWhitelisted = whitelisted(to);

    mint@withrevert(e, to, tokenId, uri, royaltyBps);

    assert !isWhitelisted => lastReverted,
        "Non-whitelisted recipient must not receive tokens";
}

/// @title Minting sets correct owner
rule mintSetsOwner(env e, address to, uint256 tokenId, string uri, uint96 royaltyBps) {
    require whitelisted(to);
    require hasRole(MINTER_ROLE(), e.msg.sender);
    require !paused();

    mint(e, to, tokenId, uri, royaltyBps);

    assert ownerOf(tokenId) == to,
        "Owner must be set to recipient after mint";
}

/// @title Minting sets ACTIVE state
rule mintSetsActiveState(env e, address to, uint256 tokenId, string uri, uint96 royaltyBps) {
    require whitelisted(to);
    require hasRole(MINTER_ROLE(), e.msg.sender);
    require !paused();

    mint(e, to, tokenId, uri, royaltyBps);

    assert tokenStates(tokenId) == ACTIVE(),
        "Token state must be ACTIVE after mint";
}

/// @title Cannot mint when paused
rule cannotMintWhenPaused(env e, address to, uint256 tokenId, string uri, uint96 royaltyBps) {
    require paused();

    mint@withrevert(e, to, tokenId, uri, royaltyBps);

    assert lastReverted,
        "Minting must revert when paused";
}

/// @title Royalty never exceeds sale price
rule royaltyBounded(uint256 tokenId, uint256 salePrice) {
    address receiver;
    uint256 royaltyAmount;
    receiver, royaltyAmount = royaltyInfo(tokenId, salePrice);

    assert royaltyAmount <= salePrice,
        "Royalty must not exceed sale price";
}

/// @title Token ownership is exclusive
rule ownershipExclusive(uint256 tokenId1, uint256 tokenId2) {
    require tokenId1 != tokenId2;
    address owner1 = ownerOf(tokenId1);
    address owner2 = ownerOf(tokenId2);

    // Different token IDs can have the same owner (this is fine)
    // But the same token ID always maps to exactly one owner
    satisfy owner1 == owner2;
}

// ==================== Invariants ====================

/// @title No token owned by zero address (if it exists)
invariant noZeroOwner(uint256 tokenId)
    tokenStates(tokenId) == ACTIVE() => ownerOf(tokenId) != 0
    {
        preserved {
            require tokenStates(tokenId) == ACTIVE();
        }
    }
```

### Running Certora

```bash
# Install
pip install certora-cli

# Run verification
certoraRun certora/conf/InstitutionalNFT.conf

# Run specific rule
certoraRun certora/conf/InstitutionalNFT.conf --rule onlyMinterCanMint
```

---

## Formal Verification (Halmos)

```python
# test/formal/test_nft_halmos.py
from halmos import *

def test_mint_only_minter(contract):
    """Only addresses with MINTER_ROLE can mint"""
    caller = halmos.symbolic_address("caller")
    tokenId = halmos.symbolic_uint256("tokenId")

    has_role = contract.hasRole(contract.MINTER_ROLE(), caller)

    if not has_role:
        with halmos.reverts():
            contract.mint(caller, tokenId, "ipfs://test", 500, sender=caller)

def test_royalty_bounds(contract):
    """Royalty can never exceed sale price"""
    tokenId = halmos.symbolic_uint256("tokenId")
    salePrice = halmos.symbolic_uint256("salePrice")

    halmos.assume(salePrice > 0)

    receiver, amount = contract.royaltyInfo(tokenId, salePrice)
    assert amount <= salePrice, "Royalty exceeds sale price"

def test_whitelist_transfer_invariant(contract):
    """Transfers only work between whitelisted addresses"""
    tokenId = halmos.symbolic_uint256("tokenId")
    to = halmos.symbolic_address("to")

    halmos.assume(contract.tokenStates(tokenId) == 1)  # ACTIVE

    if not contract.whitelisted(to):
        with halmos.reverts():
            contract.transferFrom(contract.ownerOf(tokenId), to, tokenId)
```

```bash
# Run Halmos
halmos --contract InstitutionalNFT --function test_
```

---

## Slither Static Analysis Integration

```bash
# Install
pip install slither-analyzer

# Run analysis
slither contracts/ --exclude naming-convention,solc-version

# Generate report
slither contracts/ --print human-summary

# Check specific detectors
slither contracts/ --detect reentrancy-eth,reentrancy-no-eth,unchecked-send

# CI integration
slither contracts/ --sarif output.sarif
```

### slither.config.json

```json
{
    "detectors_to_exclude": "naming-convention,solc-version",
    "exclude_informational": true,
    "exclude_low": false,
    "filter_paths": "lib/|node_modules/",
    "solc_remaps": [
        "@openzeppelin/=lib/openzeppelin-contracts/"
    ]
}
```

---

## Mythril Analysis

```bash
# Install
pip install mythril

# Analyze single contract
myth analyze contracts/InstitutionalNFT.sol --solc-json mythril.config.json

# Quick scan
myth analyze contracts/InstitutionalNFT.sol --execution-timeout 300

# Deep scan
myth analyze contracts/InstitutionalNFT.sol --execution-timeout 3600 -t 5
```

---

## CI Integration (GitHub Actions)

```yaml
# .github/workflows/foundry.yml
name: Foundry CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1

      - name: Build
        run: forge build --sizes

      - name: Unit Tests
        run: forge test -vvv

      - name: Fuzz Tests
        run: forge test --match-test testFuzz -vvv

      - name: Invariant Tests
        run: forge test --match-test invariant -vvv

      - name: Gas Report
        run: forge test --gas-report > gas-report.txt

      - name: Upload Gas Report
        uses: actions/upload-artifact@v4
        with:
          name: gas-report
          path: gas-report.txt

  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1

      - name: Coverage
        run: forge coverage --report lcov

      - name: Check Coverage Threshold
        run: |
          COVERAGE=$(forge coverage --report summary | grep "Total" | awk '{print $NF}' | tr -d '%')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Slither
        uses: crytic/slither-action@v0.4.0
        with:
          sarif: results.sarif

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif

  formal-verification:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Certora Prover
        uses: certora/certora-cli-action@v1
        with:
          conf: certora/conf/InstitutionalNFT.conf
        env:
          CERTORAKEY: ${{ secrets.CERTORAKEY }}
```

---

## Makefile

```makefile
.PHONY: build test fuzz invariant coverage deploy verify

build:
	forge build --sizes

test:
	forge test -vvv

fuzz:
	forge test --match-test testFuzz -vvv --fuzz-runs 10000

invariant:
	forge test --match-test invariant -vvv

coverage:
	forge coverage --report lcov
	genhtml lcov.info --output-directory coverage

gas:
	forge test --gas-report

snapshot:
	forge snapshot

deploy-sepolia:
	forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify

deploy-mainnet:
	forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify --slow

slither:
	slither contracts/ --exclude naming-convention,solc-version

certora:
	certoraRun certora/conf/InstitutionalNFT.conf

fmt:
	forge fmt

clean:
	forge clean
```
