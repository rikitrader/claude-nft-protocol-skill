# DeFi & Finance

NFT financialization: fractionalization vaults, lending/borrowing, rental protocols, royalty routing, streaming payments, AMM pools, floor price oracles, and peer-to-pool lending.

---

## MODULE 3: FRACTIONALIZATION VAULT (NFT -> ERC20 FRACTIONS + BUYOUT)

File: `contracts/FractionalVault.sol`

Features:
- Holds 1 NFT (ERC-721)
- Mints ERC-20 fractions to the depositor
- Allows buyout: someone pays a price → NFT transfers to buyer
- Sale proceeds become claimable pro-rata by fraction holders

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
FRACTIONAL VAULT (simple, production-friendly baseline)
- depositNFT(): vault takes custody of NFT, mints ERC20 fractions to depositor
- startBuyout(price): sets buyout price
- buyout(): buyer pays ETH, receives NFT; ETH is claimable by fraction holders
- claimProceeds(): holders burn fractions to claim ETH pro-rata

NOTES:
- This is a clean baseline. For "real" deployments add: timelocks, oracle pricing,
  allowlist/compliance gates, upgradeability, and better auction mechanisms.
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FractionalVault is ERC20, IERC721Receiver, ReentrancyGuard {
    using Address for address payable;

    IERC721 public immutable nft;
    uint256 public immutable nftTokenId;

    address public curator;           // initial depositor / manager
    bool public deposited;            // NFT deposited?
    bool public buyoutActive;
    uint256 public buyoutPriceWei;    // total ETH required to buy NFT

    uint256 public saleProceedsWei;   // ETH proceeds from buyout (claim pool)
    uint256 public snapshotSupply;    // Fixed supply snapshot at buyout time (prevents rounding attack)

    event Deposited(address indexed curator, uint256 fractionsMinted);
    event BuyoutStarted(uint256 priceWei);
    event BoughtOut(address indexed buyer, uint256 priceWei);
    event Claimed(address indexed holder, uint256 burnedFractions, uint256 ethOut);

    constructor(
        address nft_,
        uint256 tokenId_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        require(nft_ != address(0), "nft=0");
        nft = IERC721(nft_);
        nftTokenId = tokenId_;
    }

    // 1) Deposit NFT and mint fractions to curator
    function depositNFT(uint256 fractionsToMint, address curator_) external nonReentrant {
        require(!deposited, "already deposited");
        require(fractionsToMint > 0, "fractions=0");
        require(curator_ != address(0), "curator=0");

        curator = curator_;
        deposited = true;

        // Transfer NFT into vault
        nft.transferFrom(msg.sender, address(this), nftTokenId);

        // Mint fractions
        _mint(curator_, fractionsToMint);

        emit Deposited(curator_, fractionsToMint);
    }

    // 2) Curator sets a buyout price
    function startBuyout(uint256 priceWei) external {
        require(deposited, "not deposited");
        require(msg.sender == curator, "not curator");
        require(!buyoutActive, "buyout active");
        require(priceWei > 0, "price=0");

        buyoutActive = true;
        buyoutPriceWei = priceWei;

        emit BuyoutStarted(priceWei);
    }

    // 3) Anyone can buyout by paying price; NFT transfers to buyer
    function buyout() external payable nonReentrant {
        require(buyoutActive, "no buyout");
        require(msg.value == buyoutPriceWei, "wrong value");
        require(saleProceedsWei == 0, "already sold");

        // Snapshot supply at buyout time to prevent rounding attack
        snapshotSupply = totalSupply();
        saleProceedsWei = msg.value;
        buyoutActive = false;

        nft.safeTransferFrom(address(this), msg.sender, nftTokenId);

        emit BoughtOut(msg.sender, msg.value);
    }

    // 4) Fraction holders burn fractions and claim ETH pro-rata
    function claimProceeds(uint256 burnAmount) external nonReentrant {
        require(saleProceedsWei > 0, "no proceeds");
        require(burnAmount > 0, "burn=0");
        require(snapshotSupply > 0, "snapshot=0");
        require(balanceOf(msg.sender) >= burnAmount, "insufficient balance");

        // Use snapshotSupply (fixed at buyout) to prevent manipulation
        uint256 ethOut = (saleProceedsWei * burnAmount) / snapshotSupply;
        require(ethOut > 0, "ethOut=0");

        _burn(msg.sender, burnAmount);

        Address.sendValue(payable(msg.sender), ethOut);

        emit Claimed(msg.sender, burnAmount, ethOut);
    }

    // Accept NFT safeTransfer
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
```

---

# MODULE 7: NFT LENDING (COLLATERAL + LOANS)

File: `contracts/NFTLending.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
NFT LENDING PROTOCOL
- NFT as collateral
- Loan origination with terms
- Interest accrual (simple interest)
- Liquidation mechanism
- Oracle integration for valuation
- Partial repayments
*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IPriceOracle {
    function getPrice(address nftContract, uint256 tokenId) external view returns (uint256);
}

contract NFTLending is ReentrancyGuard, Pausable, Ownable {
    using Address for address payable;

    // ==================== Structs ====================

    struct Loan {
        address borrower;
        address lender;              // Added: lender address for repayment
        address nftContract;
        uint256 tokenId;
        uint256 principal;           // Loan amount
        uint256 interestRateBps;     // Annual interest rate (basis points)
        uint256 accruedInterest;
        uint64 startTime;
        uint64 duration;             // Loan duration in seconds
        uint64 lastAccrualTime;
        LoanStatus status;
    }

    struct LoanOffer {
        address lender;
        uint256 principal;
        uint256 interestRateBps;
        uint64 duration;
        uint64 expiresAt;
        bool isActive;
    }

    enum LoanStatus { None, Active, Repaid, Defaulted, Liquidated }

    // ==================== State ====================

    uint256 public loanCounter;
    uint256 public offerCounter;

    mapping(uint256 => Loan) public loans;
    mapping(uint256 => LoanOffer) public loanOffers;

    // NFT => tokenId => active loan ID
    mapping(address => mapping(uint256 => uint256)) public activeLoanId;

    // Lender balances (claimable)
    mapping(address => uint256) public lenderBalances;

    // Protocol settings
    uint256 public protocolFeeBps = 100; // 1% of interest
    uint256 public maxLTVBps = 5000;     // 50% max loan-to-value
    uint256 public liquidationThresholdBps = 8000; // 80% of loan value

    IPriceOracle public priceOracle;
    address public feeRecipient;

    // Allowed NFT contracts (whitelist)
    mapping(address => bool) public allowedCollateral;

    // ==================== Events ====================

    event LoanOfferCreated(uint256 indexed offerId, address indexed lender, uint256 principal, uint256 interestRateBps);
    event LoanOfferCancelled(uint256 indexed offerId);
    event LoanOriginated(uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 principal);
    event LoanRepaid(uint256 indexed loanId, uint256 totalRepaid);
    event LoanDefaulted(uint256 indexed loanId);
    event LoanLiquidated(uint256 indexed loanId, address liquidator);
    event CollateralWhitelisted(address indexed nftContract, bool allowed);

    // ==================== Constructor ====================

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    // ==================== Loan Offers (Lender Side) ====================

    function createLoanOffer(
        uint256 principal,
        uint256 interestRateBps,
        uint64 duration,
        uint64 offerDuration
    ) external payable whenNotPaused nonReentrant returns (uint256 offerId) {
        require(msg.value == principal, "Must deposit principal");
        require(principal > 0, "Principal must be > 0");
        require(duration > 0, "Duration must be > 0");

        offerCounter++;
        offerId = offerCounter;

        loanOffers[offerId] = LoanOffer({
            lender: msg.sender,
            principal: principal,
            interestRateBps: interestRateBps,
            duration: duration,
            expiresAt: uint64(block.timestamp) + offerDuration,
            isActive: true
        });

        emit LoanOfferCreated(offerId, msg.sender, principal, interestRateBps);
    }

    function cancelLoanOffer(uint256 offerId) external nonReentrant {
        LoanOffer storage offer = loanOffers[offerId];
        require(offer.isActive, "Not active");
        require(offer.lender == msg.sender, "Not lender");

        offer.isActive = false;
        payable(msg.sender).sendValue(offer.principal);

        emit LoanOfferCancelled(offerId);
    }

    // ==================== Borrower Functions ====================

    function borrow(
        uint256 offerId,
        address nftContract,
        uint256 tokenId
    ) external whenNotPaused nonReentrant returns (uint256 loanId) {
        require(allowedCollateral[nftContract], "Collateral not allowed");

        LoanOffer storage offer = loanOffers[offerId];
        require(offer.isActive, "Offer not active");
        require(block.timestamp < offer.expiresAt, "Offer expired");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");

        // Check LTV if oracle available
        if (address(priceOracle) != address(0)) {
            uint256 nftValue = priceOracle.getPrice(nftContract, tokenId);
            uint256 maxLoan = (nftValue * maxLTVBps) / 10000;
            require(offer.principal <= maxLoan, "LTV too high");
        }

        // Deactivate offer
        offer.isActive = false;

        // Transfer NFT to contract (collateral)
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Create loan
        loanCounter++;
        loanId = loanCounter;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: offer.lender,
            nftContract: nftContract,
            tokenId: tokenId,
            principal: offer.principal,
            interestRateBps: offer.interestRateBps,
            accruedInterest: 0,
            startTime: uint64(block.timestamp),
            duration: offer.duration,
            lastAccrualTime: uint64(block.timestamp),
            status: LoanStatus.Active
        });

        activeLoanId[nftContract][tokenId] = loanId;

        // Transfer principal to borrower
        payable(msg.sender).sendValue(offer.principal);

        emit LoanOriginated(loanId, msg.sender, offer.lender, offer.principal);
    }

    function repay(uint256 loanId) external payable whenNotPaused nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(loan.borrower == msg.sender, "Not borrower");

        // Accrue interest
        _accrueInterest(loanId);

        uint256 totalOwed = loan.principal + loan.accruedInterest;
        require(msg.value >= totalOwed, "Insufficient repayment");

        loan.status = LoanStatus.Repaid;
        delete activeLoanId[loan.nftContract][loan.tokenId];

        // Return collateral
        IERC721(loan.nftContract).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Protocol fee
        uint256 protocolFee = (loan.accruedInterest * protocolFeeBps) / 10000;
        if (protocolFee > 0 && feeRecipient != address(0)) {
            payable(feeRecipient).sendValue(protocolFee);
        }

        // Credit lender (they can withdraw later)
        lenderBalances[loan.lender] += totalOwed - protocolFee;

        // Refund excess
        if (msg.value > totalOwed) {
            payable(msg.sender).sendValue(msg.value - totalOwed);
        }

        emit LoanRepaid(loanId, totalOwed);
    }

    // ==================== Liquidation ====================

    function liquidate(uint256 loanId) external whenNotPaused nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active");

        // Check if loan is past due
        bool isPastDue = block.timestamp > loan.startTime + loan.duration;

        // Check if underwater (if oracle available)
        // Underwater = debt exceeds threshold % of collateral value
        bool isUnderwater = false;
        if (address(priceOracle) != address(0)) {
            _accrueInterest(loanId);
            uint256 totalOwed = loan.principal + loan.accruedInterest;
            uint256 nftValue = priceOracle.getPrice(loan.nftContract, loan.tokenId);
            require(nftValue > 0, "Oracle returned 0");
            // Underwater if totalOwed > nftValue * liquidationThreshold / 10000
            uint256 maxDebt = (nftValue * liquidationThresholdBps) / 10000;
            isUnderwater = totalOwed > maxDebt;
        }

        require(isPastDue || isUnderwater, "Cannot liquidate");

        loan.status = LoanStatus.Liquidated;
        delete activeLoanId[loan.nftContract][loan.tokenId];

        // Transfer NFT to liquidator (or lender)
        // In production, this would go through an auction
        IERC721(loan.nftContract).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        emit LoanLiquidated(loanId, msg.sender);
    }

    // ==================== Interest Accrual ====================

    function _accrueInterest(uint256 loanId) internal {
        Loan storage loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return;

        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        if (timeElapsed == 0) return;

        // Simple interest: principal * rate * time / (365 days * 10000)
        uint256 interest = (loan.principal * loan.interestRateBps * timeElapsed) / (365 days * 10000);
        loan.accruedInterest += interest;
        loan.lastAccrualTime = uint64(block.timestamp);
    }

    function getOutstandingBalance(uint256 loanId) external view returns (uint256) {
        Loan storage loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return 0;

        uint256 timeElapsed = block.timestamp - loan.lastAccrualTime;
        uint256 pendingInterest = (loan.principal * loan.interestRateBps * timeElapsed) / (365 days * 10000);

        return loan.principal + loan.accruedInterest + pendingInterest;
    }

    // ==================== Lender Withdrawal ====================

    function withdrawLenderBalance() external nonReentrant {
        uint256 balance = lenderBalances[msg.sender];
        require(balance > 0, "No balance");

        lenderBalances[msg.sender] = 0;
        payable(msg.sender).sendValue(balance);
    }

    // ==================== Admin ====================

    function setAllowedCollateral(address nftContract, bool allowed) external onlyOwner {
        allowedCollateral[nftContract] = allowed;
        emit CollateralWhitelisted(nftContract, allowed);
    }

    function setPriceOracle(address oracle) external onlyOwner {
        priceOracle = IPriceOracle(oracle);
    }

    function setProtocolFee(uint256 feeBps) external onlyOwner {
        require(feeBps <= 1000, "Fee too high");
        protocolFeeBps = feeBps;
    }

    function setMaxLTV(uint256 ltvBps) external onlyOwner {
        maxLTVBps = ltvBps;
    }

    function setLiquidationThreshold(uint256 thresholdBps) external onlyOwner {
        liquidationThresholdBps = thresholdBps;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
```

---

# MODULE 8: NFT RENTAL (ERC-4907)

File: `contracts/NFTRental.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
NFT RENTAL PROTOCOL (ERC-4907 Compatible)
- Time-bound rental
- Yield distribution to owner
- Automatic expiration
- Rental marketplace
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// ERC-4907 Interface
interface IERC4907 {
    event UpdateUser(uint256 indexed tokenId, address indexed user, uint64 expires);
    function setUser(uint256 tokenId, address user, uint64 expires) external;
    function userOf(uint256 tokenId) external view returns (address);
    function userExpires(uint256 tokenId) external view returns (uint256);
}

contract NFTRental is ReentrancyGuard, Ownable {
    using Address for address payable;

    struct RentalListing {
        address owner;
        address nftContract;
        uint256 tokenId;
        uint256 pricePerDay;
        uint64 minDuration;
        uint64 maxDuration;
        bool isActive;
    }

    struct ActiveRental {
        address renter;
        address owner;
        address nftContract;
        uint256 tokenId;
        uint256 totalPaid;
        uint64 startTime;
        uint64 endTime;
        bool isActive;
    }

    uint256 public listingCounter;
    uint256 public rentalCounter;

    mapping(uint256 => RentalListing) public listings;
    mapping(uint256 => ActiveRental) public rentals;
    mapping(address => mapping(uint256 => uint256)) public activeListingId;
    mapping(address => mapping(uint256 => uint256)) public activeRentalId;

    uint256 public protocolFeeBps = 250; // 2.5%
    address public feeRecipient;

    event Listed(uint256 indexed listingId, address indexed owner, address nftContract, uint256 tokenId, uint256 pricePerDay);
    event Rented(uint256 indexed rentalId, address indexed renter, uint256 listingId, uint64 duration);
    event RentalEnded(uint256 indexed rentalId);
    event ListingCancelled(uint256 indexed listingId);

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    function createListing(
        address nftContract,
        uint256 tokenId,
        uint256 pricePerDay,
        uint64 minDuration,
        uint64 maxDuration
    ) external nonReentrant returns (uint256 listingId) {
        require(pricePerDay > 0, "Price must be > 0");
        require(maxDuration >= minDuration, "Invalid duration range");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) == address(this),
            "Not approved"
        );

        listingCounter++;
        listingId = listingCounter;

        listings[listingId] = RentalListing({
            owner: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            pricePerDay: pricePerDay,
            minDuration: minDuration,
            maxDuration: maxDuration,
            isActive: true
        });

        activeListingId[nftContract][tokenId] = listingId;

        emit Listed(listingId, msg.sender, nftContract, tokenId, pricePerDay);
    }

    function rent(uint256 listingId, uint64 durationDays) external payable nonReentrant returns (uint256 rentalId) {
        RentalListing storage listing = listings[listingId];
        require(listing.isActive, "Listing not active");
        require(durationDays >= listing.minDuration, "Duration too short");
        require(durationDays <= listing.maxDuration, "Duration too long");

        uint256 totalPrice = listing.pricePerDay * durationDays;
        require(msg.value >= totalPrice, "Insufficient payment");

        // Transfer NFT to this contract if ERC-4907 is not supported
        // For ERC-4907 tokens, just set the user
        IERC721 nft = IERC721(listing.nftContract);

        // Check if ERC-4907 supported
        bool supportsRental = _supportsERC4907(listing.nftContract);

        if (supportsRental) {
            // Set user via ERC-4907
            uint64 expires = uint64(block.timestamp + (durationDays * 1 days));
            IERC4907(listing.nftContract).setUser(listing.tokenId, msg.sender, expires);
        } else {
            // Transfer NFT to renter (simple rental)
            nft.transferFrom(listing.owner, msg.sender, listing.tokenId);
        }

        rentalCounter++;
        rentalId = rentalCounter;

        rentals[rentalId] = ActiveRental({
            renter: msg.sender,
            owner: listing.owner,
            nftContract: listing.nftContract,
            tokenId: listing.tokenId,
            totalPaid: totalPrice,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + (durationDays * 1 days)),
            isActive: true
        });

        activeRentalId[listing.nftContract][listing.tokenId] = rentalId;
        listing.isActive = false; // Deactivate listing while rented

        // Handle payment
        uint256 protocolFee = (totalPrice * protocolFeeBps) / 10000;
        uint256 ownerPayment = totalPrice - protocolFee;

        if (protocolFee > 0 && feeRecipient != address(0)) {
            payable(feeRecipient).sendValue(protocolFee);
        }
        payable(listing.owner).sendValue(ownerPayment);

        // Refund excess
        if (msg.value > totalPrice) {
            payable(msg.sender).sendValue(msg.value - totalPrice);
        }

        emit Rented(rentalId, msg.sender, listingId, durationDays);
    }

    function endRental(uint256 rentalId) external nonReentrant {
        ActiveRental storage rental = rentals[rentalId];
        require(rental.isActive, "Rental not active");
        require(block.timestamp >= rental.endTime, "Rental not expired");

        rental.isActive = false;
        delete activeRentalId[rental.nftContract][rental.tokenId];

        // For non-ERC4907 tokens, transfer back to owner
        if (!_supportsERC4907(rental.nftContract)) {
            IERC721(rental.nftContract).transferFrom(rental.renter, rental.owner, rental.tokenId);
        }

        emit RentalEnded(rentalId);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        RentalListing storage listing = listings[listingId];
        require(listing.isActive, "Not active");
        require(listing.owner == msg.sender, "Not owner");

        listing.isActive = false;
        delete activeListingId[listing.nftContract][listing.tokenId];

        emit ListingCancelled(listingId);
    }

    function _supportsERC4907(address nftContract) internal view returns (bool) {
        try IERC165(nftContract).supportsInterface(type(IERC4907).interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function isRented(address nftContract, uint256 tokenId) external view returns (bool) {
        uint256 rentalId = activeRentalId[nftContract][tokenId];
        if (rentalId == 0) return false;
        ActiveRental storage rental = rentals[rentalId];
        return rental.isActive && block.timestamp < rental.endTime;
    }

    function setProtocolFee(uint256 feeBps) external onlyOwner {
        require(feeBps <= 1000, "Fee too high");
        protocolFeeBps = feeBps;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        feeRecipient = recipient;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// ERC-4907 Implementation for rentable NFTs
contract RentableNFT is ERC721, IERC4907, Ownable {
    struct UserInfo {
        address user;
        uint64 expires;
    }

    mapping(uint256 => UserInfo) internal _users;
    uint256 private _tokenIdCounter;

    constructor() ERC721("RentableNFT", "RNFT") Ownable(msg.sender) {}

    function mint(address to) external onlyOwner returns (uint256) {
        _tokenIdCounter++;
        _safeMint(to, _tokenIdCounter);
        return _tokenIdCounter;
    }

    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        require(
            _isAuthorized(ownerOf(tokenId), msg.sender, tokenId),
            "Not owner or approved"
        );
        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId, user, expires);
    }

    function userOf(uint256 tokenId) external view override returns (address) {
        if (uint256(_users[tokenId].expires) >= block.timestamp) {
            return _users[tokenId].user;
        }
        return address(0);
    }

    function userExpires(uint256 tokenId) external view override returns (uint256) {
        return _users[tokenId].expires;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != to && _users[tokenId].user != address(0)) {
            delete _users[tokenId];
            emit UpdateUser(tokenId, address(0), 0);
        }
        return from;
    }
}
```

---

# MODULE 10: ROYALTY ROUTER (PAYMENT SPLITS + STREAMING)

File: `contracts/RoyaltyRouter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
ROYALTY ROUTER
- Multi-recipient payment splits
- Streaming payments (Superfluid-style)
- On-chain revenue accounting
- Batch distributions
- Creator payout automation
*/

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RoyaltyRouter is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    // ==================== Structs ====================

    struct Split {
        address[] recipients;
        uint256[] shares;      // Basis points (must sum to 10000)
        bool isActive;
    }

    struct Stream {
        address sender;
        address recipient;
        address token;         // address(0) for ETH
        uint256 totalAmount;
        uint256 withdrawn;
        uint64 startTime;
        uint64 endTime;
        bool isActive;
    }

    struct RevenueRecord {
        uint256 totalReceived;
        uint256 totalDistributed;
        uint256 lastDistribution;
    }

    // ==================== State ====================

    uint256 public splitCounter;
    uint256 public streamCounter;

    mapping(uint256 => Split) public splits;
    mapping(uint256 => Stream) public streams;

    // NFT contract => tokenId => splitId
    mapping(address => mapping(uint256 => uint256)) public tokenSplits;

    // Recipient => claimable ETH
    mapping(address => uint256) public claimableETH;

    // Recipient => token => claimable amount
    mapping(address => mapping(address => uint256)) public claimableTokens;

    // NFT contract => revenue record
    mapping(address => RevenueRecord) public revenueRecords;

    // ==================== Events ====================

    event SplitCreated(uint256 indexed splitId, address[] recipients, uint256[] shares);
    event SplitUpdated(uint256 indexed splitId);
    event PaymentDistributed(uint256 indexed splitId, uint256 amount, address token);
    event StreamCreated(uint256 indexed streamId, address indexed sender, address indexed recipient, uint256 amount);
    event StreamWithdrawn(uint256 indexed streamId, uint256 amount);
    event StreamCancelled(uint256 indexed streamId);
    event Claimed(address indexed recipient, uint256 amount, address token);

    // ==================== Constructor ====================

    constructor() Ownable(msg.sender) {}

    // ==================== Split Management ====================

    function createSplit(
        address[] calldata recipients,
        uint256[] calldata shares
    ) external returns (uint256 splitId) {
        require(recipients.length == shares.length, "Length mismatch");
        require(recipients.length > 0 && recipients.length <= 20, "Invalid recipient count");

        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(shares[i] > 0, "Share must be > 0");
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Shares must sum to 10000");

        splitCounter++;
        splitId = splitCounter;

        splits[splitId] = Split({
            recipients: recipients,
            shares: shares,
            isActive: true
        });

        emit SplitCreated(splitId, recipients, shares);
    }

    function updateSplit(
        uint256 splitId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external onlyOwner {
        require(splits[splitId].isActive, "Split not active");
        require(recipients.length == shares.length, "Length mismatch");

        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Shares must sum to 10000");

        splits[splitId].recipients = recipients;
        splits[splitId].shares = shares;

        emit SplitUpdated(splitId);
    }

    function setTokenSplit(address nftContract, uint256 tokenId, uint256 splitId) external onlyOwner {
        require(splits[splitId].isActive, "Split not active");
        tokenSplits[nftContract][tokenId] = splitId;
    }

    // ==================== Distribution ====================

    function distributeETH(uint256 splitId) external payable nonReentrant {
        require(msg.value > 0, "No ETH sent");
        _distributeETH(splitId, msg.value);
    }

    function _distributeETH(uint256 splitId, uint256 amount) internal {
        Split storage split = splits[splitId];
        require(split.isActive, "Split not active");

        for (uint256 i = 0; i < split.recipients.length; i++) {
            uint256 payment = (amount * split.shares[i]) / 10000;
            claimableETH[split.recipients[i]] += payment;
        }

        emit PaymentDistributed(splitId, amount, address(0));
    }

    function distributeToken(uint256 splitId, address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        Split storage split = splits[splitId];
        require(split.isActive, "Split not active");

        for (uint256 i = 0; i < split.recipients.length; i++) {
            uint256 payment = (amount * split.shares[i]) / 10000;
            claimableTokens[split.recipients[i]][token] += payment;
        }

        emit PaymentDistributed(splitId, amount, token);
    }

    function distributeToToken(address nftContract, uint256 tokenId) external payable nonReentrant {
        uint256 splitId = tokenSplits[nftContract][tokenId];
        require(splitId > 0, "No split configured");
        require(msg.value > 0, "No ETH sent");

        revenueRecords[nftContract].totalReceived += msg.value;
        _distributeETH(splitId, msg.value);
        revenueRecords[nftContract].totalDistributed += msg.value;
        revenueRecords[nftContract].lastDistribution = block.timestamp;
    }

    // ==================== Claiming ====================

    function claimETH() external nonReentrant {
        uint256 amount = claimableETH[msg.sender];
        require(amount > 0, "Nothing to claim");

        claimableETH[msg.sender] = 0;
        payable(msg.sender).sendValue(amount);

        emit Claimed(msg.sender, amount, address(0));
    }

    function claimToken(address token) external nonReentrant {
        uint256 amount = claimableTokens[msg.sender][token];
        require(amount > 0, "Nothing to claim");

        claimableTokens[msg.sender][token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount, token);
    }

    function claimAll(address[] calldata tokens) external nonReentrant {
        // Claim ETH
        uint256 ethAmount = claimableETH[msg.sender];
        if (ethAmount > 0) {
            claimableETH[msg.sender] = 0;
            payable(msg.sender).sendValue(ethAmount);
            emit Claimed(msg.sender, ethAmount, address(0));
        }

        // Claim tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amount = claimableTokens[msg.sender][tokens[i]];
            if (amount > 0) {
                claimableTokens[msg.sender][tokens[i]] = 0;
                IERC20(tokens[i]).safeTransfer(msg.sender, amount);
                emit Claimed(msg.sender, amount, tokens[i]);
            }
        }
    }

    // ==================== Streaming ====================

    function createStream(
        address recipient,
        address token,
        uint256 amount,
        uint64 duration
    ) external payable nonReentrant returns (uint256 streamId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        require(duration > 0, "Duration must be > 0");

        if (token == address(0)) {
            require(msg.value == amount, "Wrong ETH amount");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        streamCounter++;
        streamId = streamCounter;

        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            totalAmount: amount,
            withdrawn: 0,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp) + duration,
            isActive: true
        });

        emit StreamCreated(streamId, msg.sender, recipient, amount);
    }

    function withdrawFromStream(uint256 streamId) external nonReentrant {
        Stream storage stream = streams[streamId];
        require(stream.isActive, "Stream not active");
        require(msg.sender == stream.recipient, "Not recipient");

        uint256 available = _streamableAmount(streamId);
        require(available > 0, "Nothing to withdraw");

        stream.withdrawn += available;

        if (stream.token == address(0)) {
            payable(msg.sender).sendValue(available);
        } else {
            IERC20(stream.token).safeTransfer(msg.sender, available);
        }

        emit StreamWithdrawn(streamId, available);
    }

    function cancelStream(uint256 streamId) external nonReentrant {
        Stream storage stream = streams[streamId];
        require(stream.isActive, "Stream not active");
        require(msg.sender == stream.sender, "Not sender");

        stream.isActive = false;

        // Pay out what's owed to recipient
        uint256 recipientAmount = _streamableAmount(streamId);

        // Return rest to sender
        uint256 senderAmount = stream.totalAmount - stream.withdrawn - recipientAmount;

        if (stream.token == address(0)) {
            if (recipientAmount > 0) payable(stream.recipient).sendValue(recipientAmount);
            if (senderAmount > 0) payable(stream.sender).sendValue(senderAmount);
        } else {
            if (recipientAmount > 0) IERC20(stream.token).safeTransfer(stream.recipient, recipientAmount);
            if (senderAmount > 0) IERC20(stream.token).safeTransfer(stream.sender, senderAmount);
        }

        emit StreamCancelled(streamId);
    }

    function _streamableAmount(uint256 streamId) internal view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (!stream.isActive) return 0;

        uint256 elapsed;
        if (block.timestamp >= stream.endTime) {
            elapsed = stream.endTime - stream.startTime;
        } else {
            elapsed = block.timestamp - stream.startTime;
        }

        uint256 totalDuration = stream.endTime - stream.startTime;
        uint256 vested = (stream.totalAmount * elapsed) / totalDuration;

        return vested - stream.withdrawn;
    }

    function getStreamableAmount(uint256 streamId) external view returns (uint256) {
        return _streamableAmount(streamId);
    }

    // ==================== View Functions ====================

    function getSplit(uint256 splitId) external view returns (address[] memory, uint256[] memory) {
        return (splits[splitId].recipients, splits[splitId].shares);
    }

    function getStream(uint256 streamId) external view returns (Stream memory) {
        return streams[streamId];
    }

    // Accept ETH
    receive() external payable {}
}
```

---

# MODULE 46: NFT LOANS WITH STREAMING PAYMENTS

## Streaming Loan Contract (Superfluid Integration)

File: `contracts/lending/StreamingLoan.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ISuperfluid, ISuperToken, ISuperAgreement} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

/**
 * @title StreamingLoan
 * @notice NFT-backed loans with Superfluid streaming interest payments
 */
contract StreamingLoan is ReentrancyGuard, Pausable, Ownable {
    using CFAv1Library for CFAv1Library.InitData;

    CFAv1Library.InitData public cfaV1;
    ISuperToken public loanToken; // Super token for streaming (e.g., USDCx)

    uint256 private _loanIdCounter;

    struct Loan {
        address borrower;
        address lender;
        address nftContract;
        uint256 tokenId;
        uint256 principal;
        int96 interestFlowRate; // Tokens per second
        uint256 startTime;
        uint256 maxDuration;
        LoanStatus status;
    }

    enum LoanStatus {
        None,
        Active,
        Repaid,
        Liquidated
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => mapping(uint256 => uint256)) public nftToLoan;

    // Configuration
    uint256 public minLoanDuration = 1 days;
    uint256 public maxLoanDuration = 90 days;
    uint256 public liquidationBuffer = 1 hours; // Grace period after stream stops

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        address nftContract,
        uint256 tokenId,
        uint256 principal,
        int96 interestFlowRate
    );
    event LoanRepaid(uint256 indexed loanId);
    event LoanLiquidated(uint256 indexed loanId);

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken _loanToken
    ) Ownable(msg.sender) {
        cfaV1 = CFAv1Library.InitData(host, cfa);
        loanToken = _loanToken;
    }

    /**
     * @notice Create a loan offer (lender deposits funds)
     */
    function createLoanOffer(
        address nftContract,
        uint256 tokenId,
        uint256 principal,
        int96 interestFlowRate,
        uint256 duration
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(duration >= minLoanDuration && duration <= maxLoanDuration, "Invalid duration");
        require(interestFlowRate > 0, "Invalid flow rate");
        require(nftToLoan[nftContract][tokenId] == 0, "NFT already collateralized");

        uint256 loanId = ++_loanIdCounter;

        // Transfer principal from lender
        loanToken.transferFrom(msg.sender, address(this), principal);

        loans[loanId] = Loan({
            borrower: address(0),
            lender: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            principal: principal,
            interestFlowRate: interestFlowRate,
            startTime: 0,
            maxDuration: duration,
            status: LoanStatus.None
        });

        return loanId;
    }

    /**
     * @notice Accept a loan offer (borrower deposits NFT, starts stream)
     */
    function acceptLoan(uint256 loanId) external nonReentrant whenNotPaused {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.None, "Invalid loan status");
        require(loan.lender != address(0), "Loan not found");

        // Transfer NFT as collateral
        IERC721(loan.nftContract).transferFrom(msg.sender, address(this), loan.tokenId);

        loan.borrower = msg.sender;
        loan.startTime = block.timestamp;
        loan.status = LoanStatus.Active;

        nftToLoan[loan.nftContract][loan.tokenId] = loanId;

        // Transfer principal to borrower
        loanToken.transfer(msg.sender, loan.principal);

        // Start interest stream from borrower to lender
        cfaV1.createFlow(msg.sender, loan.lender, loanToken, loan.interestFlowRate);

        emit LoanCreated(
            loanId,
            msg.sender,
            loan.lender,
            loan.nftContract,
            loan.tokenId,
            loan.principal,
            loan.interestFlowRate
        );
    }

    /**
     * @notice Repay loan principal (borrower)
     */
    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(msg.sender == loan.borrower, "Not borrower");

        // Transfer principal back
        loanToken.transferFrom(msg.sender, loan.lender, loan.principal);

        // Stop interest stream
        cfaV1.deleteFlow(msg.sender, loan.lender, loanToken);

        // Return NFT
        IERC721(loan.nftContract).transferFrom(address(this), msg.sender, loan.tokenId);

        loan.status = LoanStatus.Repaid;
        delete nftToLoan[loan.nftContract][loan.tokenId];

        emit LoanRepaid(loanId);
    }

    /**
     * @notice Liquidate loan (lender) if stream stopped or duration exceeded
     */
    function liquidateLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(msg.sender == loan.lender, "Not lender");

        bool canLiquidate = false;

        // Check if max duration exceeded
        if (block.timestamp > loan.startTime + loan.maxDuration) {
            canLiquidate = true;
        }

        // Check if stream stopped (borrower ran out of tokens)
        (,int96 flowRate,,) = cfaV1.cfa.getFlow(
            loanToken,
            loan.borrower,
            loan.lender
        );
        if (flowRate == 0) {
            canLiquidate = true;
        }

        require(canLiquidate, "Cannot liquidate yet");

        // Transfer NFT to lender
        IERC721(loan.nftContract).transferFrom(address(this), msg.sender, loan.tokenId);

        loan.status = LoanStatus.Liquidated;
        delete nftToLoan[loan.nftContract][loan.tokenId];

        emit LoanLiquidated(loanId);
    }

    /**
     * @notice Calculate total interest paid
     */
    function getInterestPaid(uint256 loanId) external view returns (uint256) {
        Loan storage loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return 0;

        uint256 elapsed = block.timestamp - loan.startTime;
        return uint256(uint96(loan.interestFlowRate)) * elapsed;
    }

    // Admin functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
```

---

# MODULE 55: NFT AMM (SUDOSWAP-STYLE)

## Bonding Curve NFT Pool

File: `contracts/amm/NFTPool.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NFTPool
 * @notice Sudoswap-style AMM pool for instant NFT liquidity
 */
contract NFTPool is ERC721Holder, ReentrancyGuard, Ownable {
    using Address for address payable;

    enum PoolType { Trade, NFT, Token }
    enum BondingCurve { Linear, Exponential, XYK }

    IERC721 public nftCollection;
    PoolType public poolType;
    BondingCurve public curveType;

    // Curve parameters
    uint256 public spotPrice;      // Current price
    uint256 public delta;          // Price change per trade
    uint256 public fee;            // Trading fee (basis points)

    // Pool state
    uint256[] public heldNftIds;
    mapping(uint256 => uint256) public nftIdToIndex;
    uint256 public ethBalance;

    // Constants
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;

    event PoolCreated(address indexed collection, PoolType poolType, BondingCurve curve);
    event NFTDeposited(uint256 indexed tokenId);
    event NFTWithdrawn(uint256 indexed tokenId);
    event SwapNFTForETH(address indexed seller, uint256 indexed tokenId, uint256 price);
    event SwapETHForNFT(address indexed buyer, uint256 indexed tokenId, uint256 price);
    event SpotPriceUpdated(uint256 newSpotPrice);

    constructor(
        address _nftCollection,
        PoolType _poolType,
        BondingCurve _curveType,
        uint256 _spotPrice,
        uint256 _delta,
        uint256 _fee
    ) Ownable(msg.sender) {
        require(_fee <= MAX_FEE, "Fee too high");

        nftCollection = IERC721(_nftCollection);
        poolType = _poolType;
        curveType = _curveType;
        spotPrice = _spotPrice;
        delta = _delta;
        fee = _fee;

        emit PoolCreated(_nftCollection, _poolType, _curveType);
    }

    // ==================== Price Calculations ====================

    function getBuyPrice() public view returns (uint256) {
        uint256 price = spotPrice;
        uint256 feeAmount = (price * fee) / FEE_DENOMINATOR;
        return price + feeAmount;
    }

    function getSellPrice() public view returns (uint256) {
        uint256 price = spotPrice;
        uint256 feeAmount = (price * fee) / FEE_DENOMINATOR;
        return price - feeAmount;
    }

    function getBuyPriceAfterTrade(uint256 numItems) public view returns (uint256 totalPrice) {
        uint256 currentPrice = spotPrice;

        for (uint256 i = 0; i < numItems; i++) {
            uint256 feeAmount = (currentPrice * fee) / FEE_DENOMINATOR;
            totalPrice += currentPrice + feeAmount;
            currentPrice = _getNextPrice(currentPrice, true);
        }
    }

    function getSellPriceAfterTrade(uint256 numItems) public view returns (uint256 totalPrice) {
        uint256 currentPrice = spotPrice;

        for (uint256 i = 0; i < numItems; i++) {
            uint256 feeAmount = (currentPrice * fee) / FEE_DENOMINATOR;
            totalPrice += currentPrice - feeAmount;
            currentPrice = _getNextPrice(currentPrice, false);
        }
    }

    function _getNextPrice(uint256 currentPrice, bool isBuy) internal view returns (uint256) {
        if (curveType == BondingCurve.Linear) {
            if (isBuy) {
                return currentPrice + delta;
            } else {
                return currentPrice > delta ? currentPrice - delta : 0;
            }
        } else if (curveType == BondingCurve.Exponential) {
            if (isBuy) {
                return (currentPrice * (FEE_DENOMINATOR + delta)) / FEE_DENOMINATOR;
            } else {
                return (currentPrice * FEE_DENOMINATOR) / (FEE_DENOMINATOR + delta);
            }
        }
        return currentPrice;
    }

    // ==================== Trading ====================

    function swapETHForNFT(uint256[] calldata nftIds) external payable nonReentrant {
        require(poolType != PoolType.Token, "Pool doesn't sell NFTs");
        require(nftIds.length > 0, "No NFTs specified");

        uint256 totalCost = getBuyPriceAfterTrade(nftIds.length);
        require(msg.value >= totalCost, "Insufficient payment");

        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 tokenId = nftIds[i];
            _removeNFT(tokenId);
            nftCollection.safeTransferFrom(address(this), msg.sender, tokenId);

            spotPrice = _getNextPrice(spotPrice, true);

            emit SwapETHForNFT(msg.sender, tokenId, spotPrice);
        }

        ethBalance += totalCost;

        // Refund excess
        if (msg.value > totalCost) {
            Address.sendValue(payable(msg.sender), msg.value - totalCost);
        }
    }

    function swapNFTForETH(uint256[] calldata nftIds, uint256 minOutput) external nonReentrant {
        require(poolType != PoolType.NFT, "Pool doesn't buy NFTs");
        require(nftIds.length > 0, "No NFTs specified");

        uint256 totalPayout = getSellPriceAfterTrade(nftIds.length);
        require(totalPayout >= minOutput, "Slippage exceeded");
        require(ethBalance >= totalPayout, "Insufficient pool liquidity");

        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 tokenId = nftIds[i];
            nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);
            _addNFT(tokenId);

            spotPrice = _getNextPrice(spotPrice, false);

            emit SwapNFTForETH(msg.sender, tokenId, spotPrice);
        }

        ethBalance -= totalPayout;

        Address.sendValue(payable(msg.sender), totalPayout);
    }

    // ==================== Liquidity Management ====================

    function depositNFTs(uint256[] calldata nftIds) external onlyOwner {
        for (uint256 i = 0; i < nftIds.length; i++) {
            nftCollection.safeTransferFrom(msg.sender, address(this), nftIds[i]);
            _addNFT(nftIds[i]);
            emit NFTDeposited(nftIds[i]);
        }
    }

    function withdrawNFTs(uint256[] calldata nftIds) external onlyOwner {
        for (uint256 i = 0; i < nftIds.length; i++) {
            _removeNFT(nftIds[i]);
            nftCollection.safeTransferFrom(address(this), msg.sender, nftIds[i]);
            emit NFTWithdrawn(nftIds[i]);
        }
    }

    function depositETH() external payable onlyOwner {
        ethBalance += msg.value;
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(ethBalance >= amount, "Insufficient balance");
        ethBalance -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    // ==================== Internal ====================

    function _addNFT(uint256 tokenId) internal {
        nftIdToIndex[tokenId] = heldNftIds.length;
        heldNftIds.push(tokenId);
    }

    function _removeNFT(uint256 tokenId) internal {
        uint256 index = nftIdToIndex[tokenId];
        uint256 lastIndex = heldNftIds.length - 1;

        if (index != lastIndex) {
            uint256 lastTokenId = heldNftIds[lastIndex];
            heldNftIds[index] = lastTokenId;
            nftIdToIndex[lastTokenId] = index;
        }

        heldNftIds.pop();
        delete nftIdToIndex[tokenId];
    }

    // ==================== View Functions ====================

    function getHeldNFTs() external view returns (uint256[] memory) {
        return heldNftIds;
    }

    function getPoolInfo() external view returns (
        address collection,
        PoolType pType,
        BondingCurve curve,
        uint256 currentSpotPrice,
        uint256 currentDelta,
        uint256 currentFee,
        uint256 nftCount,
        uint256 ethBal
    ) {
        return (
            address(nftCollection),
            poolType,
            curveType,
            spotPrice,
            delta,
            fee,
            heldNftIds.length,
            ethBalance
        );
    }

    // ==================== Admin ====================

    function setSpotPrice(uint256 newSpotPrice) external onlyOwner {
        spotPrice = newSpotPrice;
        emit SpotPriceUpdated(newSpotPrice);
    }

    function setDelta(uint256 newDelta) external onlyOwner {
        delta = newDelta;
    }

    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Fee too high");
        fee = newFee;
    }

    receive() external payable {
        ethBalance += msg.value;
    }
}
```

---

# MODULE 57: FLOOR PRICE ORACLE

## NFT Floor Price Oracle Integration

File: `contracts/oracle/NFTFloorOracle.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NFTFloorOracle
 * @notice Aggregates NFT floor prices from multiple sources
 */
contract NFTFloorOracle is AccessControl {
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    struct FloorPrice {
        uint256 price;
        uint256 timestamp;
        uint256 confidence; // 0-100
        address source;
    }

    struct CollectionData {
        FloorPrice[] priceHistory;
        uint256 currentFloor;
        uint256 twap24h;
        uint256 twap7d;
        bool active;
    }

    // Collection address => floor data
    mapping(address => CollectionData) public collections;

    // Chainlink floor price feeds (where available)
    mapping(address => address) public chainlinkFeeds;

    // Configuration
    uint256 public maxPriceAge = 1 hours;
    uint256 public minConfidence = 50;
    uint256 public maxHistoryLength = 168; // 7 days of hourly updates

    event FloorPriceUpdated(address indexed collection, uint256 price, uint256 confidence);
    event ChainlinkFeedSet(address indexed collection, address feed);
    event CollectionActivated(address indexed collection);
    event CollectionDeactivated(address indexed collection);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
    }

    /**
     * @notice Update floor price from off-chain aggregator
     */
    function updateFloorPrice(
        address collection,
        uint256 price,
        uint256 confidence
    ) external onlyRole(UPDATER_ROLE) {
        require(collections[collection].active, "Collection not active");
        require(confidence <= 100, "Invalid confidence");
        require(confidence >= minConfidence, "Confidence too low");

        CollectionData storage data = collections[collection];

        // Add to history
        data.priceHistory.push(FloorPrice({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence,
            source: msg.sender
        }));

        // Trim history if needed
        if (data.priceHistory.length > maxHistoryLength) {
            // Shift array (gas intensive, consider circular buffer for production)
            for (uint256 i = 0; i < data.priceHistory.length - 1; i++) {
                data.priceHistory[i] = data.priceHistory[i + 1];
            }
            data.priceHistory.pop();
        }

        data.currentFloor = price;

        // Update TWAPs
        data.twap24h = _calculateTWAP(collection, 24 hours);
        data.twap7d = _calculateTWAP(collection, 7 days);

        emit FloorPriceUpdated(collection, price, confidence);
    }

    /**
     * @notice Get current floor price
     */
    function getFloorPrice(address collection) external view returns (
        uint256 price,
        uint256 timestamp,
        bool isStale
    ) {
        // Try Chainlink first
        if (chainlinkFeeds[collection] != address(0)) {
            try AggregatorV3Interface(chainlinkFeeds[collection]).latestRoundData() returns (
                uint80,
                int256 answer,
                uint256,
                uint256 updatedAt,
                uint80
            ) {
                if (answer > 0) {
                    return (
                        uint256(answer),
                        updatedAt,
                        block.timestamp - updatedAt > maxPriceAge
                    );
                }
            } catch {}
        }

        // Fall back to aggregated data
        CollectionData storage data = collections[collection];
        if (data.priceHistory.length == 0) {
            return (0, 0, true);
        }

        FloorPrice storage latest = data.priceHistory[data.priceHistory.length - 1];
        return (
            latest.price,
            latest.timestamp,
            block.timestamp - latest.timestamp > maxPriceAge
        );
    }

    /**
     * @notice Get TWAP (Time-Weighted Average Price)
     */
    function getTWAP(address collection, uint256 period) external view returns (uint256) {
        if (period == 24 hours) {
            return collections[collection].twap24h;
        } else if (period == 7 days) {
            return collections[collection].twap7d;
        }
        return _calculateTWAP(collection, period);
    }

    /**
     * @notice Calculate TWAP for a given period
     */
    function _calculateTWAP(address collection, uint256 period) internal view returns (uint256) {
        CollectionData storage data = collections[collection];
        if (data.priceHistory.length == 0) return 0;

        uint256 cutoffTime = block.timestamp - period;
        uint256 totalPrice;
        uint256 count;

        for (uint256 i = data.priceHistory.length; i > 0; i--) {
            FloorPrice storage fp = data.priceHistory[i - 1];
            if (fp.timestamp < cutoffTime) break;

            totalPrice += fp.price;
            count++;
        }

        return count > 0 ? totalPrice / count : 0;
    }

    /**
     * @notice Get price volatility (standard deviation proxy)
     */
    function getVolatility(address collection, uint256 period) external view returns (uint256) {
        CollectionData storage data = collections[collection];
        if (data.priceHistory.length < 2) return 0;

        uint256 cutoffTime = block.timestamp - period;
        uint256 minPrice = type(uint256).max;
        uint256 maxPrice = 0;

        for (uint256 i = data.priceHistory.length; i > 0; i--) {
            FloorPrice storage fp = data.priceHistory[i - 1];
            if (fp.timestamp < cutoffTime) break;

            if (fp.price < minPrice) minPrice = fp.price;
            if (fp.price > maxPrice) maxPrice = fp.price;
        }

        if (minPrice == type(uint256).max) return 0;

        // Return range as percentage of min (simplified volatility)
        return ((maxPrice - minPrice) * 10000) / minPrice;
    }

    /**
     * @notice Get price history
     */
    function getPriceHistory(address collection, uint256 limit)
        external
        view
        returns (FloorPrice[] memory)
    {
        CollectionData storage data = collections[collection];
        uint256 length = data.priceHistory.length;
        uint256 resultLength = limit < length ? limit : length;

        FloorPrice[] memory result = new FloorPrice[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = data.priceHistory[length - resultLength + i];
        }

        return result;
    }

    // ==================== Admin ====================

    function activateCollection(address collection) external onlyRole(DEFAULT_ADMIN_ROLE) {
        collections[collection].active = true;
        emit CollectionActivated(collection);
    }

    function deactivateCollection(address collection) external onlyRole(DEFAULT_ADMIN_ROLE) {
        collections[collection].active = false;
        emit CollectionDeactivated(collection);
    }

    function setChainlinkFeed(address collection, address feed)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        chainlinkFeeds[collection] = feed;
        emit ChainlinkFeedSet(collection, feed);
    }

    function setMaxPriceAge(uint256 age) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxPriceAge = age;
    }

    function setMinConfidence(uint256 confidence) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(confidence <= 100, "Invalid");
        minConfidence = confidence;
    }
}
```

---

# MODULE 58: PEER-TO-POOL LENDING

## NFT Lending Pool Contract

File: `contracts/lending/NFTLendingPool.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface INFTFloorOracle {
    function getFloorPrice(address collection) external view returns (uint256 price, uint256 timestamp, bool isStale);
}

/**
 * @title NFTLendingPool
 * @notice BendDAO-style peer-to-pool NFT lending
 */
contract NFTLendingPool is ERC721Holder, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    INFTFloorOracle public floorOracle;

    struct CollectionConfig {
        bool enabled;
        uint256 ltv;              // Loan-to-Value ratio (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationBonus; // Bonus for liquidators (basis points)
        uint256 borrowRate;       // Annual interest rate (basis points)
    }

    struct Loan {
        address borrower;
        address collection;
        uint256 tokenId;
        uint256 principal;
        uint256 interestAccrued;
        uint256 startTime;
        uint256 lastUpdateTime;
        bool active;
    }

    // Supported collections
    mapping(address => CollectionConfig) public collectionConfigs;

    // Loans
    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;
    mapping(address => mapping(uint256 => uint256)) public nftToLoan;

    // Pool state
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public utilizationTarget = 8000; // 80%

    // Depositor tracking
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositShares;
    uint256 public totalShares;

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    event CollectionConfigured(address indexed collection, uint256 ltv, uint256 liquidationThreshold);
    event Deposited(address indexed depositor, uint256 amount, uint256 shares);
    event Withdrawn(address indexed depositor, uint256 amount, uint256 shares);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, address collection, uint256 tokenId, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator, uint256 amount);

    constructor(address _floorOracle) Ownable(msg.sender) {
        floorOracle = INFTFloorOracle(_floorOracle);
    }

    // ==================== Depositor Functions ====================

    /**
     * @notice Deposit ETH to earn yield
     */
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");

        uint256 shares;
        if (totalShares == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * totalShares) / totalDeposits;
        }

        deposits[msg.sender] += msg.value;
        depositShares[msg.sender] += shares;
        totalDeposits += msg.value;
        totalShares += shares;

        emit Deposited(msg.sender, msg.value, shares);
    }

    /**
     * @notice Withdraw deposited ETH
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0 && shares <= depositShares[msg.sender], "Invalid shares");

        uint256 amount = (shares * totalDeposits) / totalShares;
        require(address(this).balance >= amount, "Insufficient liquidity");

        depositShares[msg.sender] -= shares;
        totalShares -= shares;
        totalDeposits -= amount;

        Address.sendValue(payable(msg.sender), amount);

        emit Withdrawn(msg.sender, amount, shares);
    }

    /**
     * @notice Get depositor's current balance
     */
    function getDepositBalance(address depositor) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (depositShares[depositor] * totalDeposits) / totalShares;
    }

    // ==================== Borrower Functions ====================

    /**
     * @notice Borrow against NFT collateral
     */
    function borrow(
        address collection,
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        CollectionConfig storage config = collectionConfigs[collection];
        require(config.enabled, "Collection not supported");

        // Get floor price
        (uint256 floorPrice, , bool isStale) = floorOracle.getFloorPrice(collection);
        require(!isStale, "Price is stale");
        require(floorPrice > 0, "No floor price");

        // Check LTV
        uint256 maxBorrow = (floorPrice * config.ltv) / BASIS_POINTS;
        require(amount <= maxBorrow, "Exceeds LTV");
        require(address(this).balance >= amount, "Insufficient liquidity");

        // Transfer NFT
        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create loan
        uint256 loanId = ++loanCounter;
        loans[loanId] = Loan({
            borrower: msg.sender,
            collection: collection,
            tokenId: tokenId,
            principal: amount,
            interestAccrued: 0,
            startTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            active: true
        });

        nftToLoan[collection][tokenId] = loanId;
        totalBorrowed += amount;

        // Transfer funds
        Address.sendValue(payable(msg.sender), amount);

        emit LoanCreated(loanId, msg.sender, collection, tokenId, amount);

        return loanId;
    }

    /**
     * @notice Repay loan and retrieve NFT
     */
    function repay(uint256 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.active, "Loan not active");
        require(msg.sender == loan.borrower, "Not borrower");

        _accrueInterest(loanId);

        uint256 totalOwed = loan.principal + loan.interestAccrued;
        require(msg.value >= totalOwed, "Insufficient repayment");

        loan.active = false;
        totalBorrowed -= loan.principal;
        totalDeposits += loan.interestAccrued; // Interest goes to depositors

        delete nftToLoan[loan.collection][loan.tokenId];

        // Return NFT
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Refund excess
        if (msg.value > totalOwed) {
            Address.sendValue(payable(msg.sender), msg.value - totalOwed);
        }

        emit LoanRepaid(loanId, totalOwed);
    }

    /**
     * @notice Liquidate undercollateralized loan
     */
    function liquidate(uint256 loanId) external payable nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.active, "Loan not active");

        _accrueInterest(loanId);

        // Check if liquidatable
        (uint256 floorPrice, , ) = floorOracle.getFloorPrice(loan.collection);
        CollectionConfig storage config = collectionConfigs[loan.collection];

        uint256 totalDebt = loan.principal + loan.interestAccrued;
        uint256 liquidationValue = (floorPrice * config.liquidationThreshold) / BASIS_POINTS;

        require(totalDebt > liquidationValue, "Not liquidatable");

        // Liquidator pays debt minus bonus
        uint256 liquidationPrice = totalDebt - (totalDebt * config.liquidationBonus) / BASIS_POINTS;
        require(msg.value >= liquidationPrice, "Insufficient payment");

        loan.active = false;
        totalBorrowed -= loan.principal;
        totalDeposits += loan.interestAccrued;

        delete nftToLoan[loan.collection][loan.tokenId];

        // Transfer NFT to liquidator
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Refund excess
        if (msg.value > liquidationPrice) {
            Address.sendValue(payable(msg.sender), msg.value - liquidationPrice);
        }

        emit LoanLiquidated(loanId, msg.sender, liquidationPrice);
    }

    // ==================== Internal ====================

    function _accrueInterest(uint256 loanId) internal {
        Loan storage loan = loans[loanId];
        if (!loan.active) return;

        uint256 timeElapsed = block.timestamp - loan.lastUpdateTime;
        if (timeElapsed == 0) return;

        CollectionConfig storage config = collectionConfigs[loan.collection];
        uint256 interest = (loan.principal * config.borrowRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);

        loan.interestAccrued += interest;
        loan.lastUpdateTime = block.timestamp;
    }

    // ==================== View Functions ====================

    function getLoanInfo(uint256 loanId) external view returns (
        address borrower,
        address collection,
        uint256 tokenId,
        uint256 principal,
        uint256 interestAccrued,
        uint256 healthFactor,
        bool active
    ) {
        Loan storage loan = loans[loanId];

        uint256 currentInterest = loan.interestAccrued;
        if (loan.active) {
            uint256 timeElapsed = block.timestamp - loan.lastUpdateTime;
            CollectionConfig storage config = collectionConfigs[loan.collection];
            currentInterest += (loan.principal * config.borrowRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        }

        uint256 hf = 0;
        if (loan.active) {
            (uint256 floorPrice, , ) = floorOracle.getFloorPrice(loan.collection);
            CollectionConfig storage config = collectionConfigs[loan.collection];
            uint256 totalDebt = loan.principal + currentInterest;
            if (totalDebt > 0) {
                hf = (floorPrice * config.liquidationThreshold) / totalDebt;
            }
        }

        return (
            loan.borrower,
            loan.collection,
            loan.tokenId,
            loan.principal,
            currentInterest,
            hf,
            loan.active
        );
    }

    function getUtilization() external view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return (totalBorrowed * BASIS_POINTS) / totalDeposits;
    }

    // ==================== Admin ====================

    function configureCollection(
        address collection,
        bool enabled,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 borrowRate
    ) external onlyOwner {
        require(ltv < liquidationThreshold, "LTV >= threshold");
        require(liquidationThreshold <= BASIS_POINTS, "Invalid threshold");

        collectionConfigs[collection] = CollectionConfig({
            enabled: enabled,
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            borrowRate: borrowRate
        });

        emit CollectionConfigured(collection, ltv, liquidationThreshold);
    }

    function setFloorOracle(address _oracle) external onlyOwner {
        floorOracle = INFTFloorOracle(_oracle);
    }

    receive() external payable {
        totalDeposits += msg.value;
    }
}
```

---
