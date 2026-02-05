# Security & Testing

Security audit checklist and comprehensive test suite for NFT protocol contracts.

---

# MODULE 13: SECURITY AUDIT CHECKLIST

## Pre-Audit Checklist

```
+--------------------------------------------------------------------+
|                    SECURITY AUDIT CHECKLIST                          |
+--------------------------------------------------------------------+

STATIC ANALYSIS (Run before any deployment)
|- [ ] Slither: slither . --print human-summary
|- [ ] Mythril: myth analyze contracts/*.sol
|- [ ] Solhint: solhint 'contracts/**/*.sol'
|- [ ] Aderyn: aderyn .
|- [ ] Gas report: forge test --gas-report

ACCESS CONTROL
|- [ ] All admin functions have proper role checks
|- [ ] Role hierarchy is correctly configured
|- [ ] DEFAULT_ADMIN_ROLE is protected
|- [ ] Timelock on sensitive operations
|- [ ] Multisig required for critical functions
|- [ ] No hardcoded admin addresses

REENTRANCY
|- [ ] ReentrancyGuard on all external functions with transfers
|- [ ] CEI pattern (Checks-Effects-Interactions) followed
|- [ ] No callbacks before state changes
|- [ ] Cross-function reentrancy considered
|- [ ] Read-only reentrancy in view functions checked

ARITHMETIC
|- [ ] Using Solidity 0.8+ with built-in overflow checks
|- [ ] Division before multiplication avoided
|- [ ] Precision loss in calculations reviewed
|- [ ] Large number multiplication checked for overflow
|- [ ] Zero division prevented

INPUT VALIDATION
|- [ ] All external inputs validated
|- [ ] Array length limits enforced
|- [ ] Address(0) checks
|- [ ] Bounds checking on arrays
|- [ ] Enum validation

EXTERNAL CALLS
|- [ ] Return values checked
|- [ ] Low-level calls use proper error handling
|- [ ] Untrusted contracts identified and handled
|- [ ] Oracle data freshness checked
|- [ ] Callback attacks considered

STATE MANAGEMENT
|- [ ] Storage vs memory usage correct
|- [ ] State consistency across functions
|- [ ] Initialization protection (initializer modifier)
|- [ ] Storage collision in upgradeable contracts prevented
|- [ ] Events emitted for all state changes

UPGRADE SAFETY
|- [ ] Storage layout preserved between versions
|- [ ] New state variables added at end
|- [ ] No constructor logic (use initialize)
|- [ ] Upgrade authorization properly protected
|- [ ] Rollback plan documented

ERC COMPLIANCE
|- [ ] ERC-721: All required functions implemented
|- [ ] ERC-721: Proper events emitted
|- [ ] ERC-2981: Royalty calculations correct
|- [ ] supportsInterface returns correct values
|- [ ] Token URI format valid

GAS OPTIMIZATION
|- [ ] Loops bounded
|- [ ] Storage reads minimized (cache in memory)
|- [ ] Batch operations where possible
|- [ ] calldata instead of memory for external functions
|- [ ] Unnecessary storage writes avoided

BUSINESS LOGIC
|- [ ] Fee calculations correct
|- [ ] Royalty splits sum to expected total
|- [ ] Auction timing logic sound
|- [ ] Liquidation thresholds appropriate
|- [ ] Edge cases (0 amounts, max values) handled
```

## Slither Configuration

File: `slither.config.json`

```json
{
  "detectors_to_exclude": [
    "naming-convention",
    "solc-version"
  ],
  "filter_paths": [
    "node_modules",
    "lib"
  ],
  "exclude_informational": false,
  "exclude_low": false,
  "exclude_medium": false,
  "exclude_high": false
}
```

## Common Vulnerability Patterns

```solidity
// ==================== BAD PATTERNS TO AVOID ====================

// BAD: Reentrancy vulnerability
function withdrawBad() external {
    uint256 amount = balances[msg.sender];
    // UNSAFE: External call before state change AND uses low-level call
    (bool success, ) = msg.sender.call{value: amount}("");  // External call first
    require(success);
    balances[msg.sender] = 0;  // State change after
}

// GOOD: CEI pattern with Address.sendValue
import "@openzeppelin/contracts/utils/Address.sol";

function withdrawGood() external nonReentrant {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // State change first
    Address.sendValue(payable(msg.sender), amount);
}

// BAD: Unbounded loop
function processAllBad(address[] calldata users) external {
    for (uint256 i = 0; i < users.length; i++) {
        // Can run out of gas
        _process(users[i]);
    }
}

// GOOD: Bounded loop with pagination
function processAllGood(address[] calldata users, uint256 start, uint256 count) external {
    uint256 end = start + count;
    if (end > users.length) end = users.length;
    for (uint256 i = start; i < end; i++) {
        _process(users[i]);
    }
}

// BAD: Missing zero address check
function setAdminBad(address newAdmin) external onlyOwner {
    admin = newAdmin;  // Could set to address(0)
}

// GOOD: With validation
function setAdminGood(address newAdmin) external onlyOwner {
    require(newAdmin != address(0), "Invalid address");
    admin = newAdmin;
    emit AdminChanged(newAdmin);
}

// BAD: Precision loss
function calculateBad(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
    return a / b * c;  // Division first loses precision
}

// GOOD: Multiply first
function calculateGood(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
    return a * c / b;  // Multiply first
}

// BAD: Frontrunning vulnerable
function claimRewardBad(bytes32 hash) external {
    require(hash == keccak256(abi.encodePacked(msg.sender, rewardAmount)));
    // Attacker can see hash in mempool and front-run
    _sendReward(msg.sender);
}

// GOOD: Commit-reveal scheme
function commitClaim(bytes32 commitment) external {
    commitments[msg.sender] = commitment;
    commitTime[msg.sender] = block.timestamp;
}

function revealClaim(uint256 amount, bytes32 secret) external {
    require(block.timestamp >= commitTime[msg.sender] + 1 hours);
    require(keccak256(abi.encodePacked(msg.sender, amount, secret)) == commitments[msg.sender]);
    _sendReward(msg.sender, amount);
}
```

## Audit Firm Recommendations

```
TIER 1 (Comprehensive)
|- Trail of Bits
|- OpenZeppelin
|- Consensys Diligence
|- Spearbit

TIER 2 (Specialized)
|- Cyfrin
|- Code4rena (competitive)
|- Sherlock (competitive)
|- Cantina

AUTOMATED TOOLS
|- Slither (static analysis)
|- Mythril (symbolic execution)
|- Echidna (fuzzing)
|- Foundry invariant tests
|- Aderyn (Cyfrin's tool)
```

---

# MODULE 17: COMPLETE TEST SUITE

## Foundry Setup

File: `foundry.toml`

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["node_modules", "lib"]
remappings = [
    "@openzeppelin/=node_modules/@openzeppelin/",
    "@chainlink/=node_modules/@chainlink/",
]
optimizer = true
optimizer_runs = 200
via_ir = true
ffi = true
fs_permissions = [{ access = "read-write", path = "./" }]

[profile.default.fuzz]
runs = 1000
max_test_rejects = 100000

[profile.default.invariant]
runs = 256
depth = 32
fail_on_revert = false

[profile.ci]
fuzz = { runs = 10000 }
invariant = { runs = 512 }
```

## Foundry Unit Tests

File: `test/foundry/ERC721SecureUUPS.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/ERC721SecureUUPS.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC721SecureUUPSTest is Test {
    ERC721SecureUUPS public implementation;
    ERC721SecureUUPS public nft;

    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event TokenMinted(uint256 indexed tokenId, address indexed to, string uri);

    function setUp() public {
        // Deploy implementation
        implementation = new ERC721SecureUUPS();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            ERC721SecureUUPS.initialize.selector,
            "TestNFT",
            "TNFT",
            "ipfs://base/",
            1000, // maxSupply
            admin,
            admin, // royaltyReceiver
            500    // 5% royalty
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        nft = ERC721SecureUUPS(address(proxy));

        // Setup roles
        vm.startPrank(admin);
        nft.grantRole(MINTER_ROLE, minter);
        vm.stopPrank();
    }

    // ==================== Minting Tests ====================

    function test_MintAutoId() public {
        vm.prank(minter);
        uint256 tokenId = nft.safeMintAutoId(user1);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalMinted(), 1);
    }

    function test_MintMultiple() public {
        vm.startPrank(minter);
        for (uint256 i = 0; i < 10; i++) {
            nft.safeMintAutoId(user1);
        }
        vm.stopPrank();

        assertEq(nft.totalMinted(), 10);
        assertEq(nft.balanceOf(user1), 10);
    }

    function test_RevertMintWhenNotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.safeMintAutoId(user1);
    }

    function test_RevertMintWhenMaxSupplyReached() public {
        vm.prank(admin);
        nft.setMaxSupply(2);

        vm.startPrank(minter);
        nft.safeMintAutoId(user1);
        nft.safeMintAutoId(user1);

        vm.expectRevert("maxSupply reached");
        nft.safeMintAutoId(user1);
        vm.stopPrank();
    }

    // ==================== Transfer Tests ====================

    function test_Transfer() public {
        vm.prank(minter);
        nft.safeMintAutoId(user1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    function test_RevertTransferWhenPaused() public {
        vm.prank(minter);
        nft.safeMintAutoId(user1);

        vm.prank(admin);
        nft.pause();

        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        nft.transferFrom(user1, user2, 1);
    }

    // ==================== Royalty Tests ====================

    function test_RoyaltyInfo() public {
        vm.prank(minter);
        nft.safeMintAutoId(user1);

        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10000);

        assertEq(receiver, admin);
        assertEq(amount, 500); // 5% of 10000
    }

    function test_UpdateRoyalty() public {
        vm.prank(admin);
        nft.setDefaultRoyalty(user2, 1000); // 10%

        vm.prank(minter);
        nft.safeMintAutoId(user1);

        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10000);

        assertEq(receiver, user2);
        assertEq(amount, 1000);
    }

    // ==================== URI Tests ====================

    function test_TokenURI() public {
        vm.prank(minter);
        nft.safeMintAutoId(user1);

        string memory uri = nft.tokenURI(1);
        assertEq(uri, "ipfs://base/1");
    }

    function test_CustomTokenURI() public {
        vm.prank(minter);
        nft.safeMintAutoId(user1);

        vm.prank(minter);
        nft.setTokenURI(1, "ipfs://custom/1.json");

        string memory uri = nft.tokenURI(1);
        assertEq(uri, "ipfs://custom/1.json");
    }

    // ==================== Fuzz Tests ====================

    function testFuzz_MintToAddress(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0); // Not a contract

        vm.prank(minter);
        uint256 tokenId = nft.safeMintAutoId(to);

        assertEq(nft.ownerOf(tokenId), to);
    }

    function testFuzz_RoyaltyCalculation(uint256 salePrice) public {
        vm.assume(salePrice > 0 && salePrice < type(uint256).max / 10000);

        vm.prank(minter);
        nft.safeMintAutoId(user1);

        (, uint256 amount) = nft.royaltyInfo(1, salePrice);

        assertEq(amount, (salePrice * 500) / 10000);
    }
}
```

## Foundry Invariant Tests

File: `test/foundry/invariant/NFTInvariant.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../../contracts/ERC721SecureUUPS.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTHandler is Test {
    ERC721SecureUUPS public nft;
    address[] public actors;
    uint256 public ghost_mintCount;
    uint256 public ghost_transferCount;

    constructor(ERC721SecureUUPS _nft) {
        nft = _nft;
        for (uint256 i = 0; i < 10; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function mint(uint256 actorSeed) external {
        address to = actors[actorSeed % actors.length];

        vm.prank(nft.getRoleMember(nft.MINTER_ROLE(), 0));
        try nft.safeMintAutoId(to) {
            ghost_mintCount++;
        } catch {}
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 tokenId) external {
        if (nft.totalMinted() == 0) return;

        tokenId = bound(tokenId, 1, nft.totalMinted());
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];

        if (from == to) return;

        try nft.ownerOf(tokenId) returns (address owner) {
            if (owner != from) return;

            vm.prank(from);
            try nft.transferFrom(from, to, tokenId) {
                ghost_transferCount++;
            } catch {}
        } catch {}
    }
}

contract NFTInvariantTest is StdInvariant, Test {
    ERC721SecureUUPS public nft;
    NFTHandler public handler;

    function setUp() public {
        // Deploy
        ERC721SecureUUPS implementation = new ERC721SecureUUPS();
        bytes memory initData = abi.encodeWithSelector(
            ERC721SecureUUPS.initialize.selector,
            "TestNFT", "TNFT", "ipfs://", 10000,
            address(this), address(this), 500
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        nft = ERC721SecureUUPS(address(proxy));

        // Setup handler
        handler = new NFTHandler(nft);
        nft.grantRole(nft.MINTER_ROLE(), address(handler));

        targetContract(address(handler));
    }

    /// @dev Total minted should never exceed max supply
    function invariant_supplyNeverExceedsMax() public view {
        assertLe(nft.totalMinted(), nft.maxSupply());
    }

    /// @dev Total minted should equal ghost count
    function invariant_mintCountConsistent() public view {
        assertEq(nft.totalMinted(), handler.ghost_mintCount());
    }

    /// @dev Every minted token should have an owner
    function invariant_allTokensHaveOwner() public view {
        for (uint256 i = 1; i <= nft.totalMinted(); i++) {
            assertTrue(nft.ownerOf(i) != address(0));
        }
    }
}
```

## Marketplace Tests

File: `test/foundry/NFTMarketplace.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/NFTMarketplace.sol";
import "../../contracts/ERC721SecureUUPS.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    ERC721SecureUUPS public nft;

    address public admin = makeAddr("admin");
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    uint256 constant LISTING_PRICE = 1 ether;
    uint256 constant LISTING_DURATION = 7 days;

    function setUp() public {
        // Deploy NFT
        ERC721SecureUUPS implementation = new ERC721SecureUUPS();
        bytes memory initData = abi.encodeWithSelector(
            ERC721SecureUUPS.initialize.selector,
            "TestNFT", "TNFT", "ipfs://", 10000,
            admin, admin, 500
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        nft = ERC721SecureUUPS(address(proxy));

        // Deploy marketplace
        marketplace = new NFTMarketplace(admin);

        // Setup
        vm.prank(admin);
        nft.grantRole(nft.MINTER_ROLE(), admin);

        vm.prank(admin);
        nft.safeMintAutoId(seller);

        vm.deal(buyer, 100 ether);

        // Approve marketplace
        vm.prank(seller);
        nft.setApprovalForAll(address(marketplace), true);
    }

    function test_CreateListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            address(nft),
            1,
            LISTING_PRICE,
            uint64(LISTING_DURATION)
        );

        assertEq(listingId, 1);

        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.seller, seller);
        assertEq(listing.price, LISTING_PRICE);
        assertTrue(listing.isActive);
    }

    function test_Buy() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            address(nft), 1, LISTING_PRICE, uint64(LISTING_DURATION)
        );

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buy{value: LISTING_PRICE}(listingId);

        assertEq(nft.ownerOf(1), buyer);
        assertFalse(marketplace.getListing(listingId).isActive);
        assertGt(seller.balance, sellerBalanceBefore);
    }

    function test_CancelListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            address(nft), 1, LISTING_PRICE, uint64(LISTING_DURATION)
        );

        vm.prank(seller);
        marketplace.cancelListing(listingId);

        assertFalse(marketplace.getListing(listingId).isActive);
    }

    function test_RevertBuyWrongPrice() public {
        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            address(nft), 1, LISTING_PRICE, uint64(LISTING_DURATION)
        );

        vm.prank(buyer);
        vm.expectRevert("Wrong price");
        marketplace.buy{value: 0.5 ether}(listingId);
    }

    function test_Auction() public {
        vm.prank(seller);
        uint256 auctionId = marketplace.createAuction(
            address(nft),
            1,
            0.5 ether,  // start price
            1 ether,    // reserve
            uint64(LISTING_DURATION),
            NFTMarketplace.AuctionType.English
        );

        // Place bids
        address bidder1 = makeAddr("bidder1");
        address bidder2 = makeAddr("bidder2");
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);

        vm.prank(bidder1);
        marketplace.placeBid{value: 0.5 ether}(auctionId);

        vm.prank(bidder2);
        marketplace.placeBid{value: 0.6 ether}(auctionId);

        // Check bidder1 was refunded
        assertEq(bidder1.balance, 10 ether);

        // End auction
        vm.warp(block.timestamp + LISTING_DURATION + 1);
        marketplace.endAuction(auctionId);

        // Bidder2 didn't meet reserve, NFT returns to seller
        assertEq(nft.ownerOf(1), seller);
    }

    function testFuzz_ListingPrice(uint256 price) public {
        vm.assume(price > 0 && price < 1000000 ether);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            address(nft), 1, price, uint64(LISTING_DURATION)
        );

        assertEq(marketplace.getListing(listingId).price, price);
    }
}
```

## Lending Tests

File: `test/foundry/NFTLending.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/NFTLending.sol";
import "../../contracts/ERC721SecureUUPS.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTLendingTest is Test {
    NFTLending public lending;
    ERC721SecureUUPS public nft;

    address public admin = makeAddr("admin");
    address public lender = makeAddr("lender");
    address public borrower = makeAddr("borrower");

    uint256 constant LOAN_AMOUNT = 1 ether;
    uint256 constant INTEREST_RATE = 1000; // 10% APR
    uint64 constant LOAN_DURATION = 30 days;

    function setUp() public {
        // Deploy NFT
        ERC721SecureUUPS implementation = new ERC721SecureUUPS();
        bytes memory initData = abi.encodeWithSelector(
            ERC721SecureUUPS.initialize.selector,
            "TestNFT", "TNFT", "ipfs://", 10000,
            admin, admin, 500
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        nft = ERC721SecureUUPS(address(proxy));

        // Deploy lending
        lending = new NFTLending(admin);

        // Setup
        vm.prank(admin);
        nft.grantRole(nft.MINTER_ROLE(), admin);

        vm.prank(admin);
        nft.safeMintAutoId(borrower);

        vm.prank(admin);
        lending.setAllowedCollateral(address(nft), true);

        vm.deal(lender, 100 ether);
        vm.deal(borrower, 10 ether);

        // Approve lending contract
        vm.prank(borrower);
        nft.setApprovalForAll(address(lending), true);
    }

    function test_CreateLoanOffer() public {
        vm.prank(lender);
        uint256 offerId = lending.createLoanOffer{value: LOAN_AMOUNT}(
            LOAN_AMOUNT,
            INTEREST_RATE,
            LOAN_DURATION,
            7 days // offer validity
        );

        assertEq(offerId, 1);
    }

    function test_Borrow() public {
        // Create offer
        vm.prank(lender);
        uint256 offerId = lending.createLoanOffer{value: LOAN_AMOUNT}(
            LOAN_AMOUNT, INTEREST_RATE, LOAN_DURATION, 7 days
        );

        uint256 borrowerBalanceBefore = borrower.balance;

        // Borrow
        vm.prank(borrower);
        uint256 loanId = lending.borrow(offerId, address(nft), 1);

        assertEq(loanId, 1);
        assertEq(nft.ownerOf(1), address(lending)); // NFT in escrow
        assertEq(borrower.balance, borrowerBalanceBefore + LOAN_AMOUNT);
    }

    function test_Repay() public {
        // Setup loan
        vm.prank(lender);
        uint256 offerId = lending.createLoanOffer{value: LOAN_AMOUNT}(
            LOAN_AMOUNT, INTEREST_RATE, LOAN_DURATION, 7 days
        );

        vm.prank(borrower);
        uint256 loanId = lending.borrow(offerId, address(nft), 1);

        // Time passes (30 days)
        vm.warp(block.timestamp + 30 days);

        // Calculate repayment
        uint256 owed = lending.getOutstandingBalance(loanId);

        // Repay
        vm.prank(borrower);
        lending.repay{value: owed}(loanId);

        // NFT returned to borrower
        assertEq(nft.ownerOf(1), borrower);
    }

    function test_Liquidate() public {
        // Setup loan
        vm.prank(lender);
        uint256 offerId = lending.createLoanOffer{value: LOAN_AMOUNT}(
            LOAN_AMOUNT, INTEREST_RATE, LOAN_DURATION, 7 days
        );

        vm.prank(borrower);
        uint256 loanId = lending.borrow(offerId, address(nft), 1);

        // Time passes beyond duration
        vm.warp(block.timestamp + LOAN_DURATION + 1);

        // Liquidate
        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        lending.liquidate(loanId);

        // NFT goes to liquidator
        assertEq(nft.ownerOf(1), liquidator);
    }

    function testFuzz_InterestAccrual(uint256 timeElapsed) public {
        vm.assume(timeElapsed > 0 && timeElapsed <= 365 days);

        vm.prank(lender);
        uint256 offerId = lending.createLoanOffer{value: LOAN_AMOUNT}(
            LOAN_AMOUNT, INTEREST_RATE, LOAN_DURATION, 7 days
        );

        vm.prank(borrower);
        uint256 loanId = lending.borrow(offerId, address(nft), 1);

        vm.warp(block.timestamp + timeElapsed);

        uint256 owed = lending.getOutstandingBalance(loanId);
        uint256 expectedInterest = (LOAN_AMOUNT * INTEREST_RATE * timeElapsed) / (365 days * 10000);

        assertApproxEqAbs(owed, LOAN_AMOUNT + expectedInterest, 1e15); // 0.001 ETH tolerance
    }
}
```

## Mock Contracts

File: `test/mocks/MockERC721.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        _tokenIdCounter++;
        _safeMint(to, _tokenIdCounter);
        return _tokenIdCounter;
    }

    function mintBatch(address to, uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            _tokenIdCounter++;
            _safeMint(to, _tokenIdCounter);
        }
    }
}
```

File: `test/mocks/MockPriceOracle.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockPriceOracle {
    mapping(address => mapping(uint256 => uint256)) public prices;

    function setPrice(address nftContract, uint256 tokenId, uint256 price) external {
        prices[nftContract][tokenId] = price;
    }

    function getPrice(address nftContract, uint256 tokenId) external view returns (uint256) {
        return prices[nftContract][tokenId];
    }
}
```

File: `test/mocks/MockChainlinkFeed.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockChainlinkFeed {
    int256 private _price;
    uint8 private _decimals;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
    }

    function setPrice(int256 price) external {
        _price = price;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }
}
```

---
