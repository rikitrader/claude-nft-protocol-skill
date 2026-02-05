# Marketplace & Trading

NFT marketplace contracts: buy/sell/auction, collection offers, trait-based offers, options/futures, and operator filter registry.

# MODULE 6: NFT MARKETPLACE (BUY/SELL/AUCTION)

File: `contracts/NFTMarketplace.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
NFT MARKETPLACE
- Fixed price listings
- English auction (ascending bids)
- Dutch auction (descending price)
- Offer system
- Royalty enforcement (ERC-2981)
- Escrow for secure trades
- Compliance integration
*/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IComplianceRegistry {
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool);
}

contract NFTMarketplace is ReentrancyGuard, Pausable, Ownable {
    using Address for address payable;

    // ==================== Structs ====================

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint64 expiresAt;
        bool isActive;
    }

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address currentBidder;
        uint64 startTime;
        uint64 endTime;
        bool isActive;
        AuctionType auctionType;
    }

    struct Offer {
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 amount;
        uint64 expiresAt;
        bool isActive;
    }

    enum AuctionType { English, Dutch }

    // ==================== State ====================

    uint256 public listingCounter;
    uint256 public auctionCounter;
    uint256 public offerCounter;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Offer) public offers;

    // NFT contract => tokenId => listingId (for quick lookup)
    mapping(address => mapping(uint256 => uint256)) public activeListingId;
    mapping(address => mapping(uint256 => uint256)) public activeAuctionId;

    // Protocol fee (basis points, e.g., 250 = 2.5%)
    uint256 public protocolFeeBps = 250;
    address public feeRecipient;

    // Compliance registry (optional)
    IComplianceRegistry public complianceRegistry;

    // Minimum auction duration
    uint64 public minAuctionDuration = 1 hours;
    uint64 public maxAuctionDuration = 30 days;

    // Bid increment percentage (basis points)
    uint256 public minBidIncrementBps = 500; // 5%

    // Pull-over-push pattern for safe bid refunds (prevents DoS)
    mapping(address => uint256) public pendingReturns;

    // ==================== Events ====================

    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event ListingCancelled(uint256 indexed listingId);
    event Sale(uint256 indexed listingId, address indexed buyer, uint256 price);

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, address nftContract, uint256 tokenId, AuctionType auctionType);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId);

    event OfferMade(uint256 indexed offerId, address indexed buyer, address nftContract, uint256 tokenId, uint256 amount);
    event OfferAccepted(uint256 indexed offerId, address indexed seller);
    event OfferCancelled(uint256 indexed offerId);

    // ==================== Constructor ====================

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    // ==================== Fixed Price Listings ====================

    function createListing(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint64 duration
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(price > 0, "Price must be > 0");
        require(duration > 0, "Duration must be > 0");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) == address(this),
            "Not approved"
        );

        listingCounter++;
        listingId = listingCounter;

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            expiresAt: uint64(block.timestamp) + duration,
            isActive: true
        });

        activeListingId[nftContract][tokenId] = listingId;

        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Not active");
        require(listing.seller == msg.sender, "Not seller");

        listing.isActive = false;
        delete activeListingId[listing.nftContract][listing.tokenId];

        emit ListingCancelled(listingId);
    }

    function buy(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Not active");
        require(block.timestamp < listing.expiresAt, "Expired");
        require(msg.value == listing.price, "Wrong price");

        // Compliance check
        if (address(complianceRegistry) != address(0)) {
            require(
                complianceRegistry.canTransfer(listing.seller, msg.sender, listing.tokenId),
                "Compliance check failed"
            );
        }

        listing.isActive = false;
        delete activeListingId[listing.nftContract][listing.tokenId];

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // Handle payments
        _handlePayment(listing.nftContract, listing.tokenId, listing.seller, listing.price);

        emit Sale(listingId, msg.sender, listing.price);
    }

    // ==================== Auctions ====================

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint64 duration,
        AuctionType auctionType
    ) external whenNotPaused nonReentrant returns (uint256 auctionId) {
        require(startPrice > 0, "Start price must be > 0");
        require(duration >= minAuctionDuration && duration <= maxAuctionDuration, "Invalid duration");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) == address(this),
            "Not approved"
        );

        // Transfer NFT to marketplace (escrow)
        nft.transferFrom(msg.sender, address(this), tokenId);

        auctionCounter++;
        auctionId = auctionCounter;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            reservePrice: reservePrice,
            currentBid: 0,
            currentBidder: address(0),
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp) + duration,
            isActive: true,
            auctionType: auctionType
        });

        activeAuctionId[nftContract][tokenId] = auctionId;

        emit AuctionCreated(auctionId, msg.sender, nftContract, tokenId, auctionType);
    }

    function placeBid(uint256 auctionId) external payable whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Not active");
        require(block.timestamp < auction.endTime, "Ended");
        require(auction.auctionType == AuctionType.English, "Not English auction");

        uint256 minBid = auction.currentBid == 0
            ? auction.startPrice
            : auction.currentBid + (auction.currentBid * minBidIncrementBps / 10000);

        require(msg.value >= minBid, "Bid too low");

        // Compliance check
        if (address(complianceRegistry) != address(0)) {
            require(
                complianceRegistry.canTransfer(auction.seller, msg.sender, auction.tokenId),
                "Compliance check failed"
            );
        }

        // Queue refund for previous bidder (pull-over-push pattern)
        if (auction.currentBidder != address(0)) {
            pendingReturns[auction.currentBidder] += auction.currentBid;
        }

        auction.currentBid = msg.value;
        auction.currentBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    // Withdraw pending returns (pull-over-push pattern)
    function withdrawPendingReturn() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No pending returns");

        pendingReturns[msg.sender] = 0;
        Address.sendValue(payable(msg.sender), amount);
    }

    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Not active");
        require(block.timestamp >= auction.endTime, "Not ended yet");

        auction.isActive = false;
        delete activeAuctionId[auction.nftContract][auction.tokenId];

        IERC721 nft = IERC721(auction.nftContract);

        if (auction.currentBidder != address(0) && auction.currentBid >= auction.reservePrice) {
            // Successful auction
            nft.safeTransferFrom(address(this), auction.currentBidder, auction.tokenId);
            _handlePayment(auction.nftContract, auction.tokenId, auction.seller, auction.currentBid);
            emit AuctionEnded(auctionId, auction.currentBidder, auction.currentBid);
        } else {
            // Reserve not met or no bids - return NFT to seller
            nft.safeTransferFrom(address(this), auction.seller, auction.tokenId);
            // Queue refund for last bidder (pull-over-push pattern)
            if (auction.currentBidder != address(0)) {
                pendingReturns[auction.currentBidder] += auction.currentBid;
            }
            emit AuctionCancelled(auctionId);
        }
    }

    function getDutchAuctionPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        require(auction.auctionType == AuctionType.Dutch, "Not Dutch auction");

        if (block.timestamp >= auction.endTime) return auction.reservePrice;

        uint256 elapsed = block.timestamp - auction.startTime;
        uint256 duration = auction.endTime - auction.startTime;
        uint256 priceDrop = ((auction.startPrice - auction.reservePrice) * elapsed) / duration;

        return auction.startPrice - priceDrop;
    }

    function buyDutchAuction(uint256 auctionId) external payable whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Not active");
        require(auction.auctionType == AuctionType.Dutch, "Not Dutch auction");

        uint256 currentPrice = getDutchAuctionPrice(auctionId);
        require(msg.value >= currentPrice, "Insufficient payment");

        // Compliance check
        if (address(complianceRegistry) != address(0)) {
            require(
                complianceRegistry.canTransfer(auction.seller, msg.sender, auction.tokenId),
                "Compliance check failed"
            );
        }

        auction.isActive = false;
        delete activeAuctionId[auction.nftContract][auction.tokenId];

        // Transfer NFT
        IERC721(auction.nftContract).safeTransferFrom(address(this), msg.sender, auction.tokenId);

        // Handle payments
        _handlePayment(auction.nftContract, auction.tokenId, auction.seller, currentPrice);

        // Refund excess
        if (msg.value > currentPrice) {
            Address.sendValue(payable(msg.sender), msg.value - currentPrice);
        }

        emit AuctionEnded(auctionId, msg.sender, currentPrice);
    }

    // ==================== Offers ====================

    function makeOffer(
        address nftContract,
        uint256 tokenId,
        uint64 duration
    ) external payable whenNotPaused nonReentrant returns (uint256 offerId) {
        require(msg.value > 0, "Offer must be > 0");
        require(duration > 0, "Duration must be > 0");

        offerCounter++;
        offerId = offerCounter;

        offers[offerId] = Offer({
            buyer: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: msg.value,
            expiresAt: uint64(block.timestamp) + duration,
            isActive: true
        });

        emit OfferMade(offerId, msg.sender, nftContract, tokenId, msg.value);
    }

    function acceptOffer(uint256 offerId) external whenNotPaused nonReentrant {
        Offer storage offer = offers[offerId];
        require(offer.isActive, "Not active");
        require(block.timestamp < offer.expiresAt, "Expired");

        IERC721 nft = IERC721(offer.nftContract);
        require(nft.ownerOf(offer.tokenId) == msg.sender, "Not owner");

        // Compliance check
        if (address(complianceRegistry) != address(0)) {
            require(
                complianceRegistry.canTransfer(msg.sender, offer.buyer, offer.tokenId),
                "Compliance check failed"
            );
        }

        offer.isActive = false;

        // Transfer NFT
        nft.safeTransferFrom(msg.sender, offer.buyer, offer.tokenId);

        // Handle payments
        _handlePayment(offer.nftContract, offer.tokenId, msg.sender, offer.amount);

        emit OfferAccepted(offerId, msg.sender);
    }

    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        require(offer.isActive, "Not active");
        require(offer.buyer == msg.sender, "Not buyer");

        offer.isActive = false;
        Address.sendValue(payable(msg.sender), offer.amount);

        emit OfferCancelled(offerId);
    }

    // ==================== Payment Handling ====================

    function _handlePayment(
        address nftContract,
        uint256 tokenId,
        address seller,
        uint256 salePrice
    ) internal {
        uint256 protocolFee = (salePrice * protocolFeeBps) / 10000;
        uint256 royaltyAmount = 0;
        address royaltyReceiver = address(0);

        // Check for ERC-2981 royalty
        try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (
            address receiver,
            uint256 amount
        ) {
            royaltyReceiver = receiver;
            royaltyAmount = amount;
        } catch {}

        uint256 sellerProceeds = salePrice - protocolFee - royaltyAmount;

        // Pay protocol fee
        if (protocolFee > 0 && feeRecipient != address(0)) {
            Address.sendValue(payable(feeRecipient), protocolFee);
        }

        // Pay royalty
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            Address.sendValue(payable(royaltyReceiver), royaltyAmount);
        }

        // Pay seller
        Address.sendValue(payable(seller), sellerProceeds);
    }

    // ==================== Admin ====================

    function setProtocolFee(uint256 feeBps) external onlyOwner {
        require(feeBps <= 1000, "Fee too high"); // Max 10%
        protocolFeeBps = feeBps;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        feeRecipient = recipient;
    }

    function setComplianceRegistry(address registry) external onlyOwner {
        complianceRegistry = IComplianceRegistry(registry);
    }

    function setAuctionDurations(uint64 min, uint64 max) external onlyOwner {
        minAuctionDuration = min;
        maxAuctionDuration = max;
    }

    function setMinBidIncrement(uint256 bps) external onlyOwner {
        minBidIncrementBps = bps;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // Emergency withdrawal for stuck NFTs
    function emergencyWithdrawNFT(address nftContract, uint256 tokenId, address to) external onlyOwner {
        IERC721(nftContract).safeTransferFrom(address(this), to, tokenId);
    }

    function emergencyWithdrawETH(address to) external onlyOwner {
        Address.sendValue(payable(to), address(this).balance);
    }

    // ==================== View Functions ====================

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    // Accept NFT transfers
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
```

---

# MODULE 40: COLLECTION OFFERS

## Collection Offer Contract

File: `contracts/offers/CollectionOffers.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CollectionOffers
 * @notice Place offers on any NFT in a collection (Blur-style)
 */
contract CollectionOffers is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Offer {
        address offerer;
        address nftContract;
        uint256 amount;
        uint256 quantity;      // How many NFTs to buy at this price
        uint256 filledQuantity;
        uint256 expiresAt;
        bool isActive;
    }

    // Payment token (WETH for gas efficiency)
    IERC20 public immutable paymentToken;

    // Offers
    mapping(uint256 => Offer) public offers;
    uint256 public offerCounter;

    // Collection => sorted offer IDs by price (highest first)
    mapping(address => uint256[]) public collectionOffers;

    // User => offer IDs
    mapping(address => uint256[]) public userOffers;

    // Protocol fee
    uint256 public protocolFeeBps = 50; // 0.5%
    address public feeRecipient;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed offerer,
        address indexed nftContract,
        uint256 amount,
        uint256 quantity
    );
    event OfferFilled(
        uint256 indexed offerId,
        address indexed seller,
        uint256 tokenId,
        uint256 amount
    );
    event OfferCancelled(uint256 indexed offerId);
    event OfferUpdated(uint256 indexed offerId, uint256 newAmount, uint256 newQuantity);

    constructor(address _paymentToken) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        feeRecipient = msg.sender;
    }

    /**
     * @notice Create a collection offer
     */
    function createOffer(
        address nftContract,
        uint256 amount,
        uint256 quantity,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(amount > 0, "Invalid amount");
        require(quantity > 0, "Invalid quantity");
        require(duration > 0 && duration <= 30 days, "Invalid duration");

        // Transfer payment token to escrow
        uint256 totalAmount = amount * quantity;
        paymentToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        uint256 offerId = ++offerCounter;
        offers[offerId] = Offer({
            offerer: msg.sender,
            nftContract: nftContract,
            amount: amount,
            quantity: quantity,
            filledQuantity: 0,
            expiresAt: block.timestamp + duration,
            isActive: true
        });

        collectionOffers[nftContract].push(offerId);
        userOffers[msg.sender].push(offerId);

        emit OfferCreated(offerId, msg.sender, nftContract, amount, quantity);
        return offerId;
    }

    /**
     * @notice Accept a collection offer by selling your NFT
     */
    function acceptOffer(uint256 offerId, uint256 tokenId) external nonReentrant {
        Offer storage offer = offers[offerId];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expiresAt, "Offer expired");
        require(offer.filledQuantity < offer.quantity, "Offer fully filled");

        IERC721 nft = IERC721(offer.nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");

        // Transfer NFT to offerer
        nft.safeTransferFrom(msg.sender, offer.offerer, tokenId);

        // Calculate fees
        uint256 fee = (offer.amount * protocolFeeBps) / 10000;
        uint256 sellerAmount = offer.amount - fee;

        // Transfer payment
        paymentToken.safeTransfer(msg.sender, sellerAmount);
        if (fee > 0) {
            paymentToken.safeTransfer(feeRecipient, fee);
        }

        offer.filledQuantity++;

        // Deactivate if fully filled
        if (offer.filledQuantity >= offer.quantity) {
            offer.isActive = false;
        }

        emit OfferFilled(offerId, msg.sender, tokenId, offer.amount);
    }

    /**
     * @notice Cancel an offer and refund remaining amount
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        require(offer.offerer == msg.sender, "Not offerer");
        require(offer.isActive, "Not active");

        offer.isActive = false;

        // Refund remaining
        uint256 remainingQuantity = offer.quantity - offer.filledQuantity;
        uint256 refund = offer.amount * remainingQuantity;

        if (refund > 0) {
            paymentToken.safeTransfer(msg.sender, refund);
        }

        emit OfferCancelled(offerId);
    }

    /**
     * @notice Get best offer for a collection
     */
    function getBestOffer(address nftContract) external view returns (uint256 offerId, uint256 amount) {
        uint256[] storage offerIds = collectionOffers[nftContract];
        uint256 bestAmount = 0;
        uint256 bestOfferId = 0;

        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage offer = offers[offerIds[i]];
            if (offer.isActive &&
                offer.expiresAt > block.timestamp &&
                offer.filledQuantity < offer.quantity &&
                offer.amount > bestAmount
            ) {
                bestAmount = offer.amount;
                bestOfferId = offerIds[i];
            }
        }

        return (bestOfferId, bestAmount);
    }

    /**
     * @notice Get all active offers for a collection
     */
    function getCollectionOffers(address nftContract)
        external
        view
        returns (uint256[] memory activeOfferIds, uint256[] memory amounts)
    {
        uint256[] storage offerIds = collectionOffers[nftContract];
        uint256 activeCount = 0;

        // Count active offers
        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage offer = offers[offerIds[i]];
            if (offer.isActive && offer.expiresAt > block.timestamp) {
                activeCount++;
            }
        }

        // Build arrays
        activeOfferIds = new uint256[](activeCount);
        amounts = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < offerIds.length; i++) {
            Offer storage offer = offers[offerIds[i]];
            if (offer.isActive && offer.expiresAt > block.timestamp) {
                activeOfferIds[index] = offerIds[i];
                amounts[index] = offer.amount;
                index++;
            }
        }
    }

    // Admin functions
    function setProtocolFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee too high"); // Max 5%
        protocolFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
}
```

---

# MODULE 41: TRAIT-BASED OFFERS

## Trait Offers Contract

File: `contracts/offers/TraitOffers.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title TraitOffers
 * @notice Place offers on NFTs with specific traits using Merkle proofs
 */
contract TraitOffers is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct TraitOffer {
        address offerer;
        address nftContract;
        bytes32 traitMerkleRoot;  // Merkle root of token IDs with desired trait
        string traitDescription;   // Human-readable trait (e.g., "Background: Gold")
        uint256 amount;
        uint256 quantity;
        uint256 filledQuantity;
        uint256 expiresAt;
        bool isActive;
    }

    IERC20 public immutable paymentToken;

    mapping(uint256 => TraitOffer) public traitOffers;
    uint256 public offerCounter;

    // Track which tokens have been used for each offer
    mapping(uint256 => mapping(uint256 => bool)) public tokenUsedForOffer;

    uint256 public protocolFeeBps = 50;
    address public feeRecipient;

    event TraitOfferCreated(
        uint256 indexed offerId,
        address indexed offerer,
        address indexed nftContract,
        bytes32 traitMerkleRoot,
        string traitDescription,
        uint256 amount
    );
    event TraitOfferFilled(
        uint256 indexed offerId,
        address indexed seller,
        uint256 tokenId
    );
    event TraitOfferCancelled(uint256 indexed offerId);

    constructor(address _paymentToken) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        feeRecipient = msg.sender;
    }

    /**
     * @notice Create a trait-based offer
     * @param nftContract The NFT collection address
     * @param traitMerkleRoot Merkle root of token IDs with the desired trait
     * @param traitDescription Human-readable description of the trait
     * @param amount Price per NFT
     * @param quantity How many NFTs to buy
     * @param duration How long the offer is valid
     */
    function createTraitOffer(
        address nftContract,
        bytes32 traitMerkleRoot,
        string calldata traitDescription,
        uint256 amount,
        uint256 quantity,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(amount > 0 && quantity > 0, "Invalid params");
        require(duration <= 30 days, "Duration too long");

        uint256 totalAmount = amount * quantity;
        paymentToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        uint256 offerId = ++offerCounter;
        traitOffers[offerId] = TraitOffer({
            offerer: msg.sender,
            nftContract: nftContract,
            traitMerkleRoot: traitMerkleRoot,
            traitDescription: traitDescription,
            amount: amount,
            quantity: quantity,
            filledQuantity: 0,
            expiresAt: block.timestamp + duration,
            isActive: true
        });

        emit TraitOfferCreated(
            offerId,
            msg.sender,
            nftContract,
            traitMerkleRoot,
            traitDescription,
            amount
        );

        return offerId;
    }

    /**
     * @notice Accept a trait offer by proving your NFT has the trait
     * @param offerId The offer ID
     * @param tokenId Your token ID
     * @param merkleProof Proof that tokenId is in the trait set
     */
    function acceptTraitOffer(
        uint256 offerId,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        TraitOffer storage offer = traitOffers[offerId];
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expiresAt, "Offer expired");
        require(offer.filledQuantity < offer.quantity, "Fully filled");
        require(!tokenUsedForOffer[offerId][tokenId], "Token already used");

        // Verify token has the trait
        bytes32 leaf = keccak256(abi.encodePacked(tokenId));
        require(
            MerkleProof.verify(merkleProof, offer.traitMerkleRoot, leaf),
            "Invalid trait proof"
        );

        IERC721 nft = IERC721(offer.nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");

        // Mark token as used for this offer
        tokenUsedForOffer[offerId][tokenId] = true;

        // Transfer NFT
        nft.safeTransferFrom(msg.sender, offer.offerer, tokenId);

        // Calculate and transfer payment
        uint256 fee = (offer.amount * protocolFeeBps) / 10000;
        uint256 sellerAmount = offer.amount - fee;

        paymentToken.safeTransfer(msg.sender, sellerAmount);
        if (fee > 0) {
            paymentToken.safeTransfer(feeRecipient, fee);
        }

        offer.filledQuantity++;
        if (offer.filledQuantity >= offer.quantity) {
            offer.isActive = false;
        }

        emit TraitOfferFilled(offerId, msg.sender, tokenId);
    }

    /**
     * @notice Cancel trait offer
     */
    function cancelTraitOffer(uint256 offerId) external nonReentrant {
        TraitOffer storage offer = traitOffers[offerId];
        require(offer.offerer == msg.sender, "Not offerer");
        require(offer.isActive, "Not active");

        offer.isActive = false;

        uint256 remaining = offer.quantity - offer.filledQuantity;
        uint256 refund = offer.amount * remaining;

        if (refund > 0) {
            paymentToken.safeTransfer(msg.sender, refund);
        }

        emit TraitOfferCancelled(offerId);
    }

    /**
     * @notice Verify if a token qualifies for an offer
     */
    function verifyTrait(
        uint256 offerId,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        TraitOffer storage offer = traitOffers[offerId];
        bytes32 leaf = keccak256(abi.encodePacked(tokenId));
        return MerkleProof.verify(merkleProof, offer.traitMerkleRoot, leaf);
    }

    function setProtocolFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee too high");
        protocolFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
}
```

---

# MODULE 42: NFT OPTIONS & FUTURES

## NFT Options Contract

File: `contracts/derivatives/NFTOptions.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NFTOptions
 * @notice Call and Put options on NFTs
 */
contract NFTOptions is ERC721Holder, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum OptionType { CALL, PUT }
    enum OptionState { ACTIVE, EXERCISED, EXPIRED, CANCELLED }

    struct Option {
        OptionType optionType;
        address writer;          // Seller of the option
        address holder;          // Buyer of the option
        address nftContract;
        uint256 tokenId;
        uint256 strikePrice;     // Price at which option can be exercised
        uint256 premium;         // Price paid for the option
        uint256 expiresAt;
        OptionState state;
        bool nftDeposited;       // For calls: NFT must be deposited
        bool fundsDeposited;     // For puts: strike price must be deposited
    }

    IERC20 public immutable paymentToken;

    mapping(uint256 => Option) public options;
    uint256 public optionCounter;

    uint256 public protocolFeeBps = 100; // 1%
    address public feeRecipient;

    event OptionCreated(
        uint256 indexed optionId,
        OptionType optionType,
        address indexed writer,
        address indexed nftContract,
        uint256 tokenId,
        uint256 strikePrice,
        uint256 premium
    );
    event OptionPurchased(uint256 indexed optionId, address indexed holder);
    event OptionExercised(uint256 indexed optionId);
    event OptionExpired(uint256 indexed optionId);
    event OptionCancelled(uint256 indexed optionId);

    constructor(address _paymentToken) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        feeRecipient = msg.sender;
    }

    /**
     * @notice Write a CALL option (seller deposits NFT)
     * @dev Buyer can purchase NFT at strike price before expiry
     */
    function writeCallOption(
        address nftContract,
        uint256 tokenId,
        uint256 strikePrice,
        uint256 premium,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(duration >= 1 hours && duration <= 90 days, "Invalid duration");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");

        // Transfer NFT to contract
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 optionId = ++optionCounter;
        options[optionId] = Option({
            optionType: OptionType.CALL,
            writer: msg.sender,
            holder: address(0),
            nftContract: nftContract,
            tokenId: tokenId,
            strikePrice: strikePrice,
            premium: premium,
            expiresAt: block.timestamp + duration,
            state: OptionState.ACTIVE,
            nftDeposited: true,
            fundsDeposited: false
        });

        emit OptionCreated(
            optionId,
            OptionType.CALL,
            msg.sender,
            nftContract,
            tokenId,
            strikePrice,
            premium
        );

        return optionId;
    }

    /**
     * @notice Write a PUT option (seller deposits strike price)
     * @dev Buyer can sell NFT at strike price before expiry
     */
    function writePutOption(
        address nftContract,
        uint256 tokenId,
        uint256 strikePrice,
        uint256 premium,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(duration >= 1 hours && duration <= 90 days, "Invalid duration");

        // Transfer strike price to contract
        paymentToken.safeTransferFrom(msg.sender, address(this), strikePrice);

        uint256 optionId = ++optionCounter;
        options[optionId] = Option({
            optionType: OptionType.PUT,
            writer: msg.sender,
            holder: address(0),
            nftContract: nftContract,
            tokenId: tokenId,
            strikePrice: strikePrice,
            premium: premium,
            expiresAt: block.timestamp + duration,
            state: OptionState.ACTIVE,
            nftDeposited: false,
            fundsDeposited: true
        });

        emit OptionCreated(
            optionId,
            OptionType.PUT,
            msg.sender,
            nftContract,
            tokenId,
            strikePrice,
            premium
        );

        return optionId;
    }

    /**
     * @notice Purchase an option by paying the premium
     */
    function purchaseOption(uint256 optionId) external nonReentrant {
        Option storage option = options[optionId];
        require(option.state == OptionState.ACTIVE, "Option not active");
        require(option.holder == address(0), "Already purchased");
        require(block.timestamp < option.expiresAt, "Option expired");

        // Pay premium to writer
        uint256 fee = (option.premium * protocolFeeBps) / 10000;
        uint256 writerAmount = option.premium - fee;

        paymentToken.safeTransferFrom(msg.sender, option.writer, writerAmount);
        if (fee > 0) {
            paymentToken.safeTransferFrom(msg.sender, feeRecipient, fee);
        }

        option.holder = msg.sender;

        emit OptionPurchased(optionId, msg.sender);
    }

    /**
     * @notice Exercise a CALL option (buy NFT at strike price)
     */
    function exerciseCall(uint256 optionId) external nonReentrant {
        Option storage option = options[optionId];
        require(option.optionType == OptionType.CALL, "Not a call");
        require(option.holder == msg.sender, "Not holder");
        require(option.state == OptionState.ACTIVE, "Not active");
        require(block.timestamp < option.expiresAt, "Expired");

        option.state = OptionState.EXERCISED;

        // Pay strike price to writer
        paymentToken.safeTransferFrom(msg.sender, option.writer, option.strikePrice);

        // Transfer NFT to holder
        IERC721(option.nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            option.tokenId
        );

        emit OptionExercised(optionId);
    }

    /**
     * @notice Exercise a PUT option (sell NFT at strike price)
     */
    function exercisePut(uint256 optionId) external nonReentrant {
        Option storage option = options[optionId];
        require(option.optionType == OptionType.PUT, "Not a put");
        require(option.holder == msg.sender, "Not holder");
        require(option.state == OptionState.ACTIVE, "Not active");
        require(block.timestamp < option.expiresAt, "Expired");

        IERC721 nft = IERC721(option.nftContract);
        require(nft.ownerOf(option.tokenId) == msg.sender, "Must own NFT");

        option.state = OptionState.EXERCISED;

        // Transfer NFT to writer
        nft.safeTransferFrom(msg.sender, option.writer, option.tokenId);

        // Pay strike price to holder
        paymentToken.safeTransfer(msg.sender, option.strikePrice);

        emit OptionExercised(optionId);
    }

    /**
     * @notice Claim assets from expired option (writer only)
     */
    function claimExpired(uint256 optionId) external nonReentrant {
        Option storage option = options[optionId];
        require(option.writer == msg.sender, "Not writer");
        require(option.state == OptionState.ACTIVE, "Not active");
        require(block.timestamp >= option.expiresAt, "Not expired");

        option.state = OptionState.EXPIRED;

        if (option.optionType == OptionType.CALL && option.nftDeposited) {
            // Return NFT to writer
            IERC721(option.nftContract).safeTransferFrom(
                address(this),
                msg.sender,
                option.tokenId
            );
        } else if (option.optionType == OptionType.PUT && option.fundsDeposited) {
            // Return funds to writer
            paymentToken.safeTransfer(msg.sender, option.strikePrice);
        }

        emit OptionExpired(optionId);
    }

    /**
     * @notice Cancel unpurchased option
     */
    function cancelOption(uint256 optionId) external nonReentrant {
        Option storage option = options[optionId];
        require(option.writer == msg.sender, "Not writer");
        require(option.holder == address(0), "Already purchased");
        require(option.state == OptionState.ACTIVE, "Not active");

        option.state = OptionState.CANCELLED;

        if (option.optionType == OptionType.CALL) {
            IERC721(option.nftContract).safeTransferFrom(
                address(this),
                msg.sender,
                option.tokenId
            );
        } else {
            paymentToken.safeTransfer(msg.sender, option.strikePrice);
        }

        emit OptionCancelled(optionId);
    }

    function setProtocolFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "Fee too high");
        protocolFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
}
```

---

# MODULE 45: OPERATOR FILTER REGISTRY

## Operator Filter Contract

File: `contracts/royalty/OperatorFilter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OperatorFilterRegistry
 * @notice Registry to block marketplaces that don't honor royalties
 */
contract OperatorFilterRegistry is Ownable {
    // Operator => blocked status
    mapping(address => bool) public blockedOperators;

    // Code hash => blocked status (for proxy contracts)
    mapping(bytes32 => bool) public blockedCodeHashes;

    // Collection => uses filter
    mapping(address => bool) public registeredCollections;

    // Collection => custom blocked operators
    mapping(address => mapping(address => bool)) public collectionBlockedOperators;

    // Default blocked operators (known royalty-skipping marketplaces)
    address[] public defaultBlockedOperators;

    event OperatorBlocked(address indexed operator);
    event OperatorUnblocked(address indexed operator);
    event CodeHashBlocked(bytes32 indexed codeHash);
    event CodeHashUnblocked(bytes32 indexed codeHash);
    event CollectionRegistered(address indexed collection);
    event CollectionUnregistered(address indexed collection);

    constructor() Ownable(msg.sender) {
        // Add known royalty-skipping marketplace addresses
        // These are examples - update with actual addresses
    }

    /**
     * @notice Register collection to use the filter
     */
    function registerCollection() external {
        registeredCollections[msg.sender] = true;
        emit CollectionRegistered(msg.sender);
    }

    /**
     * @notice Unregister collection
     */
    function unregisterCollection() external {
        registeredCollections[msg.sender] = false;
        emit CollectionUnregistered(msg.sender);
    }

    /**
     * @notice Check if operator is allowed for a collection
     */
    function isOperatorAllowed(address collection, address operator)
        external
        view
        returns (bool)
    {
        if (!registeredCollections[collection]) {
            return true; // Not using filter
        }

        // Check collection-specific blocks
        if (collectionBlockedOperators[collection][operator]) {
            return false;
        }

        // Check global blocks
        if (blockedOperators[operator]) {
            return false;
        }

        // Check code hash blocks
        bytes32 codeHash = operator.codehash;
        if (blockedCodeHashes[codeHash]) {
            return false;
        }

        return true;
    }

    /**
     * @notice Block operator for your collection
     */
    function blockOperatorForCollection(address operator) external {
        require(registeredCollections[msg.sender], "Not registered");
        collectionBlockedOperators[msg.sender][operator] = true;
    }

    /**
     * @notice Unblock operator for your collection
     */
    function unblockOperatorForCollection(address operator) external {
        collectionBlockedOperators[msg.sender][operator] = false;
    }

    // ==================== Admin (Global Blocks) ====================

    function blockOperator(address operator) external onlyOwner {
        blockedOperators[operator] = true;
        defaultBlockedOperators.push(operator);
        emit OperatorBlocked(operator);
    }

    function unblockOperator(address operator) external onlyOwner {
        blockedOperators[operator] = false;
        emit OperatorUnblocked(operator);
    }

    function blockCodeHash(bytes32 codeHash) external onlyOwner {
        blockedCodeHashes[codeHash] = true;
        emit CodeHashBlocked(codeHash);
    }

    function unblockCodeHash(bytes32 codeHash) external onlyOwner {
        blockedCodeHashes[codeHash] = false;
        emit CodeHashUnblocked(codeHash);
    }

    function getDefaultBlockedOperators() external view returns (address[] memory) {
        return defaultBlockedOperators;
    }
}

/**
 * @title OperatorFilterer
 * @notice Mixin for NFT contracts to enforce operator filtering
 */
abstract contract OperatorFilterer {
    IOperatorFilterRegistry public operatorFilterRegistry;

    error OperatorNotAllowed(address operator);

    constructor(address registry) {
        operatorFilterRegistry = IOperatorFilterRegistry(registry);
    }

    modifier onlyAllowedOperator(address from) {
        if (from != msg.sender) {
            if (!operatorFilterRegistry.isOperatorAllowed(address(this), msg.sender)) {
                revert OperatorNotAllowed(msg.sender);
            }
        }
        _;
    }

    modifier onlyAllowedOperatorApproval(address operator) {
        if (!operatorFilterRegistry.isOperatorAllowed(address(this), operator)) {
            revert OperatorNotAllowed(operator);
        }
        _;
    }
}

interface IOperatorFilterRegistry {
    function isOperatorAllowed(address collection, address operator) external view returns (bool);
}
```

---
