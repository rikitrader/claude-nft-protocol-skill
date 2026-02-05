# Infrastructure & Cross-Chain

Oracle integration (Chainlink), The Graph subgraph indexing, multi-chain deployment, cross-chain bridging (LayerZero), account abstraction (ERC-4337), analytics dashboards, MEV protection, and Permit2 gasless approvals.

---

# MODULE 9: ASSET ORACLE (CHAINLINK INTEGRATION)

File: `contracts/AssetOracle.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
ASSET ORACLE
- Chainlink price feed integration
- Custom valuation submissions
- Multi-source aggregation
- Staleness checks
- RWA status feeds (legal, insurance)
*/

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IAssetOracle {
    function getPrice(address nftContract, uint256 tokenId) external view returns (uint256);
    function getAssetStatus(address nftContract, uint256 tokenId) external view returns (AssetStatus memory);
}

struct AssetStatus {
    uint256 valuation;
    bool legalVerified;
    bool insuranceActive;
    uint64 lastUpdated;
    bytes32 documentHash;
}

contract AssetOracle is IAssetOracle, AccessControl {
    bytes32 public constant ORACLE_ADMIN = keccak256("ORACLE_ADMIN");
    bytes32 public constant PRICE_UPDATER = keccak256("PRICE_UPDATER");
    bytes32 public constant STATUS_UPDATER = keccak256("STATUS_UPDATER");

    // ==================== Structs ====================

    struct PriceData {
        uint256 price;
        uint64 timestamp;
        address source;
    }

    struct CollectionConfig {
        address chainlinkFeed;      // ETH/USD or floor price feed
        uint256 floorPriceMultiplier; // Basis points (10000 = 1x)
        bool useChainlink;
        bool useManualPrice;
    }

    // ==================== State ====================

    // NFT contract => tokenId => price data
    mapping(address => mapping(uint256 => PriceData)) public tokenPrices;

    // NFT contract => tokenId => status
    mapping(address => mapping(uint256 => AssetStatus)) public assetStatuses;

    // NFT contract => collection config
    mapping(address => CollectionConfig) public collectionConfigs;

    // Staleness threshold (default 24 hours)
    uint256 public stalenessThreshold = 24 hours;

    // ETH/USD Chainlink feed
    AggregatorV3Interface public ethUsdFeed;

    // ==================== Events ====================

    event PriceUpdated(address indexed nftContract, uint256 indexed tokenId, uint256 price, address source);
    event StatusUpdated(address indexed nftContract, uint256 indexed tokenId, bool legalVerified, bool insuranceActive);
    event CollectionConfigured(address indexed nftContract, address chainlinkFeed, bool useChainlink);

    // ==================== Constructor ====================

    constructor(address admin, address _ethUsdFeed) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ADMIN, admin);
        _grantRole(PRICE_UPDATER, admin);
        _grantRole(STATUS_UPDATER, admin);

        if (_ethUsdFeed != address(0)) {
            ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
        }
    }

    // ==================== Price Functions ====================

    function setTokenPrice(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external onlyRole(PRICE_UPDATER) {
        tokenPrices[nftContract][tokenId] = PriceData({
            price: price,
            timestamp: uint64(block.timestamp),
            source: msg.sender
        });

        // Also update asset status valuation
        assetStatuses[nftContract][tokenId].valuation = price;
        assetStatuses[nftContract][tokenId].lastUpdated = uint64(block.timestamp);

        emit PriceUpdated(nftContract, tokenId, price, msg.sender);
    }

    function batchSetTokenPrices(
        address nftContract,
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external onlyRole(PRICE_UPDATER) {
        require(tokenIds.length == prices.length, "Length mismatch");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenPrices[nftContract][tokenIds[i]] = PriceData({
                price: prices[i],
                timestamp: uint64(block.timestamp),
                source: msg.sender
            });

            assetStatuses[nftContract][tokenIds[i]].valuation = prices[i];
            assetStatuses[nftContract][tokenIds[i]].lastUpdated = uint64(block.timestamp);

            emit PriceUpdated(nftContract, tokenIds[i], prices[i], msg.sender);
        }
    }

    function getPrice(address nftContract, uint256 tokenId) external view override returns (uint256) {
        CollectionConfig storage config = collectionConfigs[nftContract];

        // Try manual price first
        if (config.useManualPrice) {
            PriceData storage data = tokenPrices[nftContract][tokenId];
            if (data.price > 0 && !_isStale(data.timestamp)) {
                return data.price;
            }
        }

        // Try Chainlink feed
        if (config.useChainlink && config.chainlinkFeed != address(0)) {
            uint256 floorPrice = _getChainlinkPrice(config.chainlinkFeed);
            if (floorPrice > 0) {
                return (floorPrice * config.floorPriceMultiplier) / 10000;
            }
        }

        // Fallback to stored price even if stale
        return tokenPrices[nftContract][tokenId].price;
    }

    function _getChainlinkPrice(address feed) internal view returns (uint256) {
        try AggregatorV3Interface(feed).latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (price > 0 && !_isStale(updatedAt)) {
                return uint256(price);
            }
        } catch {}
        return 0;
    }

    function _isStale(uint256 timestamp) internal view returns (bool) {
        return block.timestamp - timestamp > stalenessThreshold;
    }

    // ==================== Status Functions ====================

    function setAssetStatus(
        address nftContract,
        uint256 tokenId,
        bool legalVerified,
        bool insuranceActive,
        bytes32 documentHash
    ) external onlyRole(STATUS_UPDATER) {
        AssetStatus storage status = assetStatuses[nftContract][tokenId];
        status.legalVerified = legalVerified;
        status.insuranceActive = insuranceActive;
        status.documentHash = documentHash;
        status.lastUpdated = uint64(block.timestamp);

        emit StatusUpdated(nftContract, tokenId, legalVerified, insuranceActive);
    }

    function getAssetStatus(address nftContract, uint256 tokenId)
        external
        view
        override
        returns (AssetStatus memory)
    {
        return assetStatuses[nftContract][tokenId];
    }

    function isAssetVerified(address nftContract, uint256 tokenId) external view returns (bool) {
        AssetStatus storage status = assetStatuses[nftContract][tokenId];
        return status.legalVerified && status.insuranceActive && !_isStale(status.lastUpdated);
    }

    // ==================== Configuration ====================

    function configureCollection(
        address nftContract,
        address chainlinkFeed,
        uint256 floorPriceMultiplier,
        bool useChainlink,
        bool useManualPrice
    ) external onlyRole(ORACLE_ADMIN) {
        collectionConfigs[nftContract] = CollectionConfig({
            chainlinkFeed: chainlinkFeed,
            floorPriceMultiplier: floorPriceMultiplier,
            useChainlink: useChainlink,
            useManualPrice: useManualPrice
        });

        emit CollectionConfigured(nftContract, chainlinkFeed, useChainlink);
    }

    function setStalenessThreshold(uint256 threshold) external onlyRole(ORACLE_ADMIN) {
        stalenessThreshold = threshold;
    }

    function setEthUsdFeed(address feed) external onlyRole(ORACLE_ADMIN) {
        ethUsdFeed = AggregatorV3Interface(feed);
    }

    // ==================== View Helpers ====================

    function getEthUsdPrice() external view returns (uint256) {
        if (address(ethUsdFeed) == address(0)) return 0;
        return _getChainlinkPrice(address(ethUsdFeed));
    }

    function getPriceInUsd(address nftContract, uint256 tokenId) external view returns (uint256) {
        uint256 priceInEth = this.getPrice(nftContract, tokenId);
        uint256 ethPrice = this.getEthUsdPrice();
        if (ethPrice == 0) return 0;
        return (priceInEth * ethPrice) / 1e18;
    }
}
```

---

# MODULE 11: THE GRAPH SUBGRAPH

## Directory Structure

```
subgraph/
├── schema.graphql
├── subgraph.yaml
├── src/
│   ├── mapping.ts
│   ├── nft.ts
│   ├── marketplace.ts
│   ├── lending.ts
│   └── utils.ts
├── abis/
│   ├── ERC721SecureUUPS.json
│   ├── NFTMarketplace.json
│   ├── NFTLending.json
│   └── FractionalVault.json
└── package.json
```

## File: `subgraph/schema.graphql`

```graphql
# NFT Entity
type Token @entity {
  id: ID!                          # contract-tokenId
  contract: Bytes!
  tokenId: BigInt!
  owner: User!
  creator: User
  tokenURI: String
  metadata: TokenMetadata
  mintedAt: BigInt!
  mintTxHash: Bytes!
  transfers: [Transfer!]! @derivedFrom(field: "token")
  listings: [Listing!]! @derivedFrom(field: "token")
  loans: [Loan!]! @derivedFrom(field: "token")
  rentals: [Rental!]! @derivedFrom(field: "token")
  state: TokenState!
  royaltyReceiver: Bytes
  royaltyBps: BigInt
}

enum TokenState {
  MINTED
  ACTIVE
  LOCKED
  FRACTIONALIZED
  BURNED
  REDEEMED
}

type TokenMetadata @entity {
  id: ID!
  name: String
  description: String
  image: String
  animationUrl: String
  externalUrl: String
  attributes: [Attribute!]! @derivedFrom(field: "metadata")
}

type Attribute @entity {
  id: ID!
  metadata: TokenMetadata!
  traitType: String!
  value: String!
  displayType: String
}

# User Entity
type User @entity {
  id: ID!                          # wallet address
  address: Bytes!
  tokensOwned: [Token!]! @derivedFrom(field: "owner")
  tokensCreated: [Token!]! @derivedFrom(field: "creator")
  purchases: [Sale!]! @derivedFrom(field: "buyer")
  sales: [Sale!]! @derivedFrom(field: "seller")
  bids: [Bid!]! @derivedFrom(field: "bidder")
  loans: [Loan!]! @derivedFrom(field: "borrower")
  totalSpent: BigInt!
  totalEarned: BigInt!
  isKYCApproved: Boolean!
  isAccredited: Boolean!
  isBlacklisted: Boolean!
}

# Transfer History
type Transfer @entity {
  id: ID!
  token: Token!
  from: User!
  to: User!
  timestamp: BigInt!
  blockNumber: BigInt!
  txHash: Bytes!
}

# Marketplace Entities
type Listing @entity {
  id: ID!
  token: Token!
  seller: User!
  price: BigInt!
  createdAt: BigInt!
  expiresAt: BigInt!
  isActive: Boolean!
  sale: Sale
}

type Auction @entity {
  id: ID!
  token: Token!
  seller: User!
  auctionType: AuctionType!
  startPrice: BigInt!
  reservePrice: BigInt!
  currentBid: BigInt!
  currentBidder: User
  startTime: BigInt!
  endTime: BigInt!
  isActive: Boolean!
  bids: [Bid!]! @derivedFrom(field: "auction")
  sale: Sale
}

enum AuctionType {
  ENGLISH
  DUTCH
}

type Bid @entity {
  id: ID!
  auction: Auction!
  bidder: User!
  amount: BigInt!
  timestamp: BigInt!
  txHash: Bytes!
}

type Sale @entity {
  id: ID!
  token: Token!
  seller: User!
  buyer: User!
  price: BigInt!
  royaltyPaid: BigInt!
  protocolFee: BigInt!
  timestamp: BigInt!
  txHash: Bytes!
  listing: Listing
  auction: Auction
}

type Offer @entity {
  id: ID!
  token: Token!
  buyer: User!
  amount: BigInt!
  expiresAt: BigInt!
  isActive: Boolean!
  createdAt: BigInt!
}

# Lending Entities
type Loan @entity {
  id: ID!
  token: Token!
  borrower: User!
  lender: User!
  principal: BigInt!
  interestRateBps: BigInt!
  accruedInterest: BigInt!
  startTime: BigInt!
  duration: BigInt!
  status: LoanStatus!
  repaidAt: BigInt
  liquidatedAt: BigInt
}

enum LoanStatus {
  ACTIVE
  REPAID
  DEFAULTED
  LIQUIDATED
}

type LoanOffer @entity {
  id: ID!
  lender: User!
  principal: BigInt!
  interestRateBps: BigInt!
  duration: BigInt!
  expiresAt: BigInt!
  isActive: Boolean!
}

# Rental Entities
type Rental @entity {
  id: ID!
  token: Token!
  owner: User!
  renter: User!
  pricePerDay: BigInt!
  totalPaid: BigInt!
  startTime: BigInt!
  endTime: BigInt!
  isActive: Boolean!
}

# Fractionalization Entities
type FractionalVault @entity {
  id: ID!
  token: Token!
  curator: User!
  fractionToken: Bytes!
  totalFractions: BigInt!
  buyoutPrice: BigInt
  buyoutActive: Boolean!
  soldAt: BigInt
  soldTo: User
  proceeds: BigInt
}

type FractionHolder @entity {
  id: ID!                          # vault-holder
  vault: FractionalVault!
  holder: User!
  balance: BigInt!
  claimed: BigInt!
}

# Analytics
type DailyStats @entity {
  id: ID!                          # date string
  date: BigInt!
  totalVolume: BigInt!
  salesCount: BigInt!
  uniqueBuyers: BigInt!
  uniqueSellers: BigInt!
  avgPrice: BigInt!
  floorPrice: BigInt!
}

type CollectionStats @entity {
  id: ID!                          # contract address
  contract: Bytes!
  totalSupply: BigInt!
  totalVolume: BigInt!
  totalSales: BigInt!
  floorPrice: BigInt!
  avgPrice: BigInt!
  uniqueOwners: BigInt!
}
```

## File: `subgraph/subgraph.yaml`

```yaml
specVersion: 0.0.5
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: ERC721SecureUUPS
    network: mainnet
    source:
      address: "0xYOUR_NFT_CONTRACT_ADDRESS"
      abi: ERC721SecureUUPS
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Token
        - User
        - Transfer
      abis:
        - name: ERC721SecureUUPS
          file: ./abis/ERC721SecureUUPS.json
      eventHandlers:
        - event: Transfer(indexed address,indexed address,indexed uint256)
          handler: handleTransfer
        - event: TokenMinted(indexed uint256,indexed address,string)
          handler: handleTokenMinted
        - event: TokenStateChanged(indexed uint256,uint8)
          handler: handleTokenStateChanged
      file: ./src/nft.ts

  - kind: ethereum
    name: NFTMarketplace
    network: mainnet
    source:
      address: "0xYOUR_MARKETPLACE_ADDRESS"
      abi: NFTMarketplace
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Listing
        - Auction
        - Bid
        - Sale
        - Offer
      abis:
        - name: NFTMarketplace
          file: ./abis/NFTMarketplace.json
      eventHandlers:
        - event: Listed(indexed uint256,indexed address,address,uint256,uint256)
          handler: handleListed
        - event: ListingCancelled(indexed uint256)
          handler: handleListingCancelled
        - event: Sale(indexed uint256,indexed address,uint256)
          handler: handleSale
        - event: AuctionCreated(indexed uint256,indexed address,address,uint256,uint8)
          handler: handleAuctionCreated
        - event: BidPlaced(indexed uint256,indexed address,uint256)
          handler: handleBidPlaced
        - event: AuctionEnded(indexed uint256,indexed address,uint256)
          handler: handleAuctionEnded
        - event: OfferMade(indexed uint256,indexed address,address,uint256,uint256)
          handler: handleOfferMade
        - event: OfferAccepted(indexed uint256,indexed address)
          handler: handleOfferAccepted
      file: ./src/marketplace.ts

  - kind: ethereum
    name: NFTLending
    network: mainnet
    source:
      address: "0xYOUR_LENDING_ADDRESS"
      abi: NFTLending
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Loan
        - LoanOffer
      abis:
        - name: NFTLending
          file: ./abis/NFTLending.json
      eventHandlers:
        - event: LoanOfferCreated(indexed uint256,indexed address,uint256,uint256)
          handler: handleLoanOfferCreated
        - event: LoanOriginated(indexed uint256,indexed address,indexed address,uint256)
          handler: handleLoanOriginated
        - event: LoanRepaid(indexed uint256,uint256)
          handler: handleLoanRepaid
        - event: LoanLiquidated(indexed uint256,address)
          handler: handleLoanLiquidated
      file: ./src/lending.ts
```

## File: `subgraph/src/nft.ts`

```typescript
import { BigInt, Address, Bytes } from "@graphprotocol/graph-ts";
import {
  Transfer as TransferEvent,
  TokenMinted as TokenMintedEvent,
  TokenStateChanged as TokenStateChangedEvent,
} from "../generated/ERC721SecureUUPS/ERC721SecureUUPS";
import { Token, User, Transfer } from "../generated/schema";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function handleTransfer(event: TransferEvent): void {
  let tokenId = event.params.tokenId.toString();
  let contractAddress = event.address.toHexString();
  let id = contractAddress + "-" + tokenId;

  let token = Token.load(id);
  if (token == null) {
    token = new Token(id);
    token.contract = event.address;
    token.tokenId = event.params.tokenId;
    token.mintedAt = event.block.timestamp;
    token.mintTxHash = event.transaction.hash;
    token.state = "ACTIVE";
  }

  // Get or create users
  let fromUser = getOrCreateUser(event.params.from);
  let toUser = getOrCreateUser(event.params.to);

  // Update ownership
  token.owner = toUser.id;

  // Set creator on mint
  if (event.params.from.toHexString() == ZERO_ADDRESS) {
    token.creator = toUser.id;
  }

  token.save();

  // Create transfer record
  let transferId =
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let transfer = new Transfer(transferId);
  transfer.token = token.id;
  transfer.from = fromUser.id;
  transfer.to = toUser.id;
  transfer.timestamp = event.block.timestamp;
  transfer.blockNumber = event.block.number;
  transfer.txHash = event.transaction.hash;
  transfer.save();
}

export function handleTokenMinted(event: TokenMintedEvent): void {
  let tokenId = event.params.tokenId.toString();
  let contractAddress = event.address.toHexString();
  let id = contractAddress + "-" + tokenId;

  let token = Token.load(id);
  if (token != null) {
    token.tokenURI = event.params.uri;
    token.save();
  }
}

export function handleTokenStateChanged(event: TokenStateChangedEvent): void {
  let tokenId = event.params.tokenId.toString();
  let contractAddress = event.address.toHexString();
  let id = contractAddress + "-" + tokenId;

  let token = Token.load(id);
  if (token != null) {
    let stateValue = event.params.newState;
    if (stateValue == 0) token.state = "MINTED";
    else if (stateValue == 1) token.state = "ACTIVE";
    else if (stateValue == 2) token.state = "LOCKED";
    else if (stateValue == 3) token.state = "FRACTIONALIZED";
    else if (stateValue == 4) token.state = "BURNED";
    else if (stateValue == 5) token.state = "REDEEMED";
    token.save();
  }
}

function getOrCreateUser(address: Address): User {
  let id = address.toHexString();
  let user = User.load(id);

  if (user == null) {
    user = new User(id);
    user.address = address;
    user.totalSpent = BigInt.fromI32(0);
    user.totalEarned = BigInt.fromI32(0);
    user.isKYCApproved = false;
    user.isAccredited = false;
    user.isBlacklisted = false;
    user.save();
  }

  return user;
}
```

## File: `subgraph/src/marketplace.ts`

```typescript
import { BigInt, Address } from "@graphprotocol/graph-ts";
import {
  Listed as ListedEvent,
  ListingCancelled as ListingCancelledEvent,
  Sale as SaleEvent,
  AuctionCreated as AuctionCreatedEvent,
  BidPlaced as BidPlacedEvent,
  AuctionEnded as AuctionEndedEvent,
} from "../generated/NFTMarketplace/NFTMarketplace";
import {
  Token,
  User,
  Listing,
  Auction,
  Bid,
  Sale,
  DailyStats,
  CollectionStats,
} from "../generated/schema";

export function handleListed(event: ListedEvent): void {
  let listingId = event.params.listingId.toString();
  let listing = new Listing(listingId);

  let tokenId =
    event.params.nftContract.toHexString() +
    "-" +
    event.params.tokenId.toString();

  listing.token = tokenId;
  listing.seller = event.params.seller.toHexString();
  listing.price = event.params.price;
  listing.createdAt = event.block.timestamp;
  listing.expiresAt = BigInt.fromI32(0); // Set from contract call if needed
  listing.isActive = true;
  listing.save();
}

export function handleListingCancelled(event: ListingCancelledEvent): void {
  let listingId = event.params.listingId.toString();
  let listing = Listing.load(listingId);
  if (listing != null) {
    listing.isActive = false;
    listing.save();
  }
}

export function handleSale(event: SaleEvent): void {
  let saleId = event.transaction.hash.toHexString();
  let sale = new Sale(saleId);

  let listingId = event.params.listingId.toString();
  let listing = Listing.load(listingId);

  if (listing != null) {
    sale.token = listing.token;
    sale.seller = listing.seller;
    sale.buyer = event.params.buyer.toHexString();
    sale.price = event.params.price;
    sale.royaltyPaid = BigInt.fromI32(0); // Calculate from event if available
    sale.protocolFee = BigInt.fromI32(0);
    sale.timestamp = event.block.timestamp;
    sale.txHash = event.transaction.hash;
    sale.listing = listingId;
    sale.save();

    // Update listing
    listing.isActive = false;
    listing.sale = saleId;
    listing.save();

    // Update user stats
    updateUserStats(
      Address.fromString(listing.seller),
      event.params.price,
      false
    );
    updateUserStats(event.params.buyer, event.params.price, true);

    // Update daily stats
    updateDailyStats(event.block.timestamp, event.params.price);
  }
}

export function handleAuctionCreated(event: AuctionCreatedEvent): void {
  let auctionId = event.params.auctionId.toString();
  let auction = new Auction(auctionId);

  let tokenId =
    event.params.nftContract.toHexString() +
    "-" +
    event.params.tokenId.toString();

  auction.token = tokenId;
  auction.seller = event.params.seller.toHexString();
  auction.auctionType = event.params.auctionType == 0 ? "ENGLISH" : "DUTCH";
  auction.startPrice = BigInt.fromI32(0);
  auction.reservePrice = BigInt.fromI32(0);
  auction.currentBid = BigInt.fromI32(0);
  auction.startTime = event.block.timestamp;
  auction.endTime = BigInt.fromI32(0);
  auction.isActive = true;
  auction.save();
}

export function handleBidPlaced(event: BidPlacedEvent): void {
  let bidId =
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let bid = new Bid(bidId);

  bid.auction = event.params.auctionId.toString();
  bid.bidder = event.params.bidder.toHexString();
  bid.amount = event.params.amount;
  bid.timestamp = event.block.timestamp;
  bid.txHash = event.transaction.hash;
  bid.save();

  // Update auction
  let auction = Auction.load(event.params.auctionId.toString());
  if (auction != null) {
    auction.currentBid = event.params.amount;
    auction.currentBidder = event.params.bidder.toHexString();
    auction.save();
  }
}

export function handleAuctionEnded(event: AuctionEndedEvent): void {
  let auctionId = event.params.auctionId.toString();
  let auction = Auction.load(auctionId);

  if (auction != null) {
    auction.isActive = false;

    if (event.params.winner.toHexString() != "0x0000000000000000000000000000000000000000") {
      // Create sale record
      let saleId = event.transaction.hash.toHexString();
      let sale = new Sale(saleId);
      sale.token = auction.token;
      sale.seller = auction.seller;
      sale.buyer = event.params.winner.toHexString();
      sale.price = event.params.amount;
      sale.royaltyPaid = BigInt.fromI32(0);
      sale.protocolFee = BigInt.fromI32(0);
      sale.timestamp = event.block.timestamp;
      sale.txHash = event.transaction.hash;
      sale.auction = auctionId;
      sale.save();

      auction.sale = saleId;
    }

    auction.save();
  }
}

function updateUserStats(
  address: Address,
  amount: BigInt,
  isBuyer: boolean
): void {
  let user = User.load(address.toHexString());
  if (user != null) {
    if (isBuyer) {
      user.totalSpent = user.totalSpent.plus(amount);
    } else {
      user.totalEarned = user.totalEarned.plus(amount);
    }
    user.save();
  }
}

function updateDailyStats(timestamp: BigInt, amount: BigInt): void {
  let dayId = timestamp.div(BigInt.fromI32(86400)).toString();
  let stats = DailyStats.load(dayId);

  if (stats == null) {
    stats = new DailyStats(dayId);
    stats.date = timestamp.div(BigInt.fromI32(86400)).times(BigInt.fromI32(86400));
    stats.totalVolume = BigInt.fromI32(0);
    stats.salesCount = BigInt.fromI32(0);
    stats.uniqueBuyers = BigInt.fromI32(0);
    stats.uniqueSellers = BigInt.fromI32(0);
    stats.avgPrice = BigInt.fromI32(0);
    stats.floorPrice = BigInt.fromI32(0);
  }

  stats.totalVolume = stats.totalVolume.plus(amount);
  stats.salesCount = stats.salesCount.plus(BigInt.fromI32(1));
  stats.avgPrice = stats.totalVolume.div(stats.salesCount);
  stats.save();
}
```

## Subgraph Queries

```graphql
# Get all tokens owned by a user
query GetUserTokens($owner: String!) {
  tokens(where: { owner: $owner }) {
    id
    tokenId
    tokenURI
    state
    mintedAt
  }
}

# Get active listings
query GetActiveListings($first: Int!, $skip: Int!) {
  listings(
    where: { isActive: true }
    orderBy: createdAt
    orderDirection: desc
    first: $first
    skip: $skip
  ) {
    id
    token {
      tokenId
      tokenURI
    }
    seller {
      address
    }
    price
    createdAt
  }
}

# Get recent sales
query GetRecentSales($first: Int!) {
  sales(orderBy: timestamp, orderDirection: desc, first: $first) {
    id
    token {
      tokenId
    }
    seller {
      address
    }
    buyer {
      address
    }
    price
    timestamp
  }
}

# Get collection stats
query GetCollectionStats($contract: Bytes!) {
  collectionStats(id: $contract) {
    totalSupply
    totalVolume
    totalSales
    floorPrice
    avgPrice
    uniqueOwners
  }
}

# Get user activity
query GetUserActivity($user: String!) {
  user(id: $user) {
    tokensOwned {
      tokenId
    }
    purchases(orderBy: timestamp, orderDirection: desc, first: 10) {
      price
      timestamp
    }
    sales(orderBy: timestamp, orderDirection: desc, first: 10) {
      price
      timestamp
    }
    loans {
      principal
      status
    }
  }
}

# Get daily stats for charts
query GetDailyStats($days: Int!) {
  dailyStats(orderBy: date, orderDirection: desc, first: $days) {
    date
    totalVolume
    salesCount
    avgPrice
  }
}
```

---

# MODULE 14: MULTI-CHAIN DEPLOYMENT

## Supported Networks Configuration

File: `hardhat.config.ts`

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x" + "0".repeat(64);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
    },
  },
  networks: {
    // Ethereum
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 1,
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
    },
    // Polygon
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 137,
    },
    polygonMumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 80001,
    },
    polygonZkEvm: {
      url: "https://zkevm-rpc.com",
      accounts: [PRIVATE_KEY],
      chainId: 1101,
    },
    // Base
    base: {
      url: "https://mainnet.base.org",
      accounts: [PRIVATE_KEY],
      chainId: 8453,
    },
    baseSepolia: {
      url: "https://sepolia.base.org",
      accounts: [PRIVATE_KEY],
      chainId: 84532,
    },
    // Arbitrum
    arbitrumOne: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 42161,
    },
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 421614,
    },
    // Optimism
    optimism: {
      url: `https://opt-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 10,
    },
    // Avalanche
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [PRIVATE_KEY],
      chainId: 43114,
    },
    avalancheFuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: [PRIVATE_KEY],
      chainId: 43113,
    },
    // BNB Chain
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: [PRIVATE_KEY],
      chainId: 56,
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_KEY || "",
      sepolia: process.env.ETHERSCAN_KEY || "",
      polygon: process.env.POLYGONSCAN_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_KEY || "",
      base: process.env.BASESCAN_KEY || "",
      baseSepolia: process.env.BASESCAN_KEY || "",
      arbitrumOne: process.env.ARBISCAN_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_KEY || "",
      avalanche: process.env.SNOWTRACE_KEY || "",
      bsc: process.env.BSCSCAN_KEY || "",
    },
  },
};

export default config;
```

## Multi-Chain Deploy Script

File: `scripts/deploy_multichain.ts`

```typescript
import { ethers, upgrades, network } from "hardhat";
import fs from "fs";

interface DeploymentConfig {
  name: string;
  symbol: string;
  baseURI: string;
  maxSupply: number;
  royaltyBps: number;
  chainlinkEthUsd?: string;
}

interface DeployedAddresses {
  nft: string;
  marketplace: string;
  lending: string;
  rental: string;
  compliance: string;
  oracle: string;
  royaltyRouter: string;
  dao?: {
    token: string;
    timelock: string;
    governor: string;
  };
}

// Chainlink ETH/USD feeds per network
const CHAINLINK_FEEDS: Record<string, string> = {
  mainnet: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  polygon: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
  arbitrumOne: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
  optimism: "0x13e3Ee699D1909E989722E753853AE30b17e08c5",
  base: "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70",
  avalanche: "0x976B3D034E162d8bD72D6b9C989d545b839003b0",
  bsc: "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e",
};

async function main() {
  const [deployer] = await ethers.getSigners();
  const networkName = network.name;

  console.log(`\n========================================`);
  console.log(`Deploying to: ${networkName}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  console.log(`========================================\n`);

  const config: DeploymentConfig = {
    name: "InstitutionalNFT",
    symbol: "INFT",
    baseURI: "ipfs://YOUR_CID/",
    maxSupply: 10000,
    royaltyBps: 500,
    chainlinkEthUsd: CHAINLINK_FEEDS[networkName],
  };

  const addresses: DeployedAddresses = {} as DeployedAddresses;

  // 1. Deploy Compliance Registry
  console.log("1. Deploying ComplianceRegistry...");
  const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
  const compliance = await ComplianceRegistry.deploy(deployer.address);
  await compliance.waitForDeployment();
  addresses.compliance = await compliance.getAddress();
  console.log(`   ComplianceRegistry: ${addresses.compliance}`);

  // 2. Deploy Asset Oracle
  console.log("2. Deploying AssetOracle...");
  const AssetOracle = await ethers.getContractFactory("AssetOracle");
  const oracle = await AssetOracle.deploy(
    deployer.address,
    config.chainlinkEthUsd || ethers.ZeroAddress
  );
  await oracle.waitForDeployment();
  addresses.oracle = await oracle.getAddress();
  console.log(`   AssetOracle: ${addresses.oracle}`);

  // 3. Deploy NFT (UUPS Proxy)
  console.log("3. Deploying ERC721SecureUUPS (Proxy)...");
  const ERC721SecureUUPS = await ethers.getContractFactory("ERC721SecureUUPS");
  const nft = await upgrades.deployProxy(
    ERC721SecureUUPS,
    [
      config.name,
      config.symbol,
      config.baseURI,
      config.maxSupply,
      deployer.address,
      deployer.address,
      config.royaltyBps,
    ],
    { kind: "uups", initializer: "initialize" }
  );
  await nft.waitForDeployment();
  addresses.nft = await nft.getAddress();
  console.log(`   ERC721SecureUUPS: ${addresses.nft}`);

  // 4. Deploy Marketplace
  console.log("4. Deploying NFTMarketplace...");
  const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
  const marketplace = await NFTMarketplace.deploy(deployer.address);
  await marketplace.waitForDeployment();
  addresses.marketplace = await marketplace.getAddress();
  console.log(`   NFTMarketplace: ${addresses.marketplace}`);

  // 5. Deploy Lending
  console.log("5. Deploying NFTLending...");
  const NFTLending = await ethers.getContractFactory("NFTLending");
  const lending = await NFTLending.deploy(deployer.address);
  await lending.waitForDeployment();
  addresses.lending = await lending.getAddress();
  console.log(`   NFTLending: ${addresses.lending}`);

  // 6. Deploy Rental
  console.log("6. Deploying NFTRental...");
  const NFTRental = await ethers.getContractFactory("NFTRental");
  const rental = await NFTRental.deploy(deployer.address);
  await rental.waitForDeployment();
  addresses.rental = await rental.getAddress();
  console.log(`   NFTRental: ${addresses.rental}`);

  // 7. Deploy Royalty Router
  console.log("7. Deploying RoyaltyRouter...");
  const RoyaltyRouter = await ethers.getContractFactory("RoyaltyRouter");
  const royaltyRouter = await RoyaltyRouter.deploy();
  await royaltyRouter.waitForDeployment();
  addresses.royaltyRouter = await royaltyRouter.getAddress();
  console.log(`   RoyaltyRouter: ${addresses.royaltyRouter}`);

  // 8. Configure contracts
  console.log("\n8. Configuring contracts...");

  // Set compliance registry on marketplace
  await marketplace.setComplianceRegistry(addresses.compliance);
  console.log("   - Marketplace: compliance registry set");

  // Set price oracle on lending
  await lending.setPriceOracle(addresses.oracle);
  console.log("   - Lending: price oracle set");

  // Whitelist NFT for lending
  await lending.setAllowedCollateral(addresses.nft, true);
  console.log("   - Lending: NFT whitelisted as collateral");

  // Configure oracle for NFT collection
  await oracle.configureCollection(
    addresses.nft,
    ethers.ZeroAddress, // No floor price feed
    10000, // 1x multiplier
    false, // Don't use Chainlink for this collection
    true // Use manual prices
  );
  console.log("   - Oracle: NFT collection configured");

  // Save deployment addresses
  const deploymentPath = `./deployments/${networkName}.json`;
  fs.mkdirSync("./deployments", { recursive: true });
  fs.writeFileSync(deploymentPath, JSON.stringify(addresses, null, 2));
  console.log(`\nDeployment saved to: ${deploymentPath}`);

  // Summary
  console.log("\n========================================");
  console.log("DEPLOYMENT COMPLETE");
  console.log("========================================");
  console.log(JSON.stringify(addresses, null, 2));

  // Verification commands
  console.log("\n========================================");
  console.log("VERIFICATION COMMANDS");
  console.log("========================================");
  console.log(`npx hardhat verify --network ${networkName} ${addresses.compliance} ${deployer.address}`);
  console.log(`npx hardhat verify --network ${networkName} ${addresses.marketplace} ${deployer.address}`);
  console.log(`npx hardhat verify --network ${networkName} ${addresses.lending} ${deployer.address}`);
  console.log(`npx hardhat verify --network ${networkName} ${addresses.rental} ${deployer.address}`);

  return addresses;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## Batch Deployment Script

File: `scripts/deploy_all_networks.sh`

```bash
#!/bin/bash

# Deploy to all testnets
echo "Deploying to testnets..."
npx hardhat run scripts/deploy_multichain.ts --network sepolia
npx hardhat run scripts/deploy_multichain.ts --network polygonMumbai
npx hardhat run scripts/deploy_multichain.ts --network baseSepolia
npx hardhat run scripts/deploy_multichain.ts --network arbitrumSepolia
npx hardhat run scripts/deploy_multichain.ts --network avalancheFuji

echo "Testnet deployments complete!"

# Uncomment for mainnet deployments (CAREFUL!)
# echo "Deploying to mainnets..."
# npx hardhat run scripts/deploy_multichain.ts --network mainnet
# npx hardhat run scripts/deploy_multichain.ts --network polygon
# npx hardhat run scripts/deploy_multichain.ts --network base
# npx hardhat run scripts/deploy_multichain.ts --network arbitrumOne
# npx hardhat run scripts/deploy_multichain.ts --network avalanche
```

---

# MODULE 20: CROSS-CHAIN BRIDGE (LayerZero)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CROSS-CHAIN NFT BRIDGE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Source Chain                          Destination Chain        │
│  ┌──────────┐                          ┌──────────┐            │
│  │   NFT    │──────┐          ┌────────│   NFT    │            │
│  │ Contract │      │          │        │ Contract │            │
│  └──────────┘      ▼          ▼        └──────────┘            │
│                ┌──────────────────┐                             │
│                │   LayerZero      │                             │
│                │   Endpoint       │                             │
│                └──────────────────┘                             │
│                         │                                       │
│                         ▼                                       │
│                ┌──────────────────┐                             │
│                │  ONFT721 Bridge  │                             │
│                │  ├─ Lock/Burn    │                             │
│                │  ├─ Message      │                             │
│                │  └─ Mint/Unlock  │                             │
│                └──────────────────┘                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ONFT721 Bridge Contract

File: `contracts/bridge/ONFT721Bridge.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/onft721/ONFT721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title ONFT721Bridge
 * @notice Cross-chain NFT bridge using LayerZero ONFT standard
 */
contract ONFT721Bridge is ONFT721, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant BRIDGE_ADMIN = keccak256("BRIDGE_ADMIN");
    bytes32 public constant FEE_MANAGER = keccak256("FEE_MANAGER");

    // Bridge configuration
    uint256 public bridgeFee;
    address public feeRecipient;

    // Rate limiting
    mapping(uint32 => uint256) public dailyLimit;      // eid => max transfers/day
    mapping(uint32 => uint256) public dailyCount;      // eid => current count
    mapping(uint32 => uint256) public lastResetTime;   // eid => last reset timestamp

    // Token tracking
    mapping(uint256 => bool) public lockedTokens;
    mapping(uint256 => uint32) public tokenOriginChain;

    // Blacklist for stolen tokens
    mapping(uint256 => bool) public blacklistedTokens;

    event BridgeInitiated(
        uint256 indexed tokenId,
        address indexed from,
        uint32 dstEid,
        bytes32 toAddress
    );
    event BridgeCompleted(
        uint256 indexed tokenId,
        address indexed to,
        uint32 srcEid
    );
    event TokenBlacklisted(uint256 indexed tokenId, bool status);
    event DailyLimitUpdated(uint32 indexed eid, uint256 limit);

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) ONFT721(_name, _symbol, _lzEndpoint, _delegate) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ADMIN, msg.sender);
        _grantRole(FEE_MANAGER, msg.sender);
        feeRecipient = msg.sender;
    }

    /**
     * @notice Bridge NFT to another chain
     */
    function bridge(
        uint256 _tokenId,
        uint32 _dstEid,
        bytes32 _to,
        bytes calldata _options
    ) external payable whenNotPaused nonReentrant {
        require(!blacklistedTokens[_tokenId], "Token blacklisted");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");

        // Check rate limit
        _checkAndUpdateRateLimit(_dstEid);

        // Collect bridge fee
        if (bridgeFee > 0) {
            require(msg.value >= bridgeFee, "Insufficient bridge fee");
            Address.sendValue(payable(feeRecipient), bridgeFee);
        }

        // Lock token on source chain
        lockedTokens[_tokenId] = true;

        // Prepare send params
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: _to,
            tokenId: _tokenId,
            extraOptions: _options,
            composeMsg: "",
            onftCmd: ""
        });

        // Get messaging fee
        MessagingFee memory fee = _quote(sendParam, false);
        require(msg.value >= fee.nativeFee + bridgeFee, "Insufficient fee");

        // Send cross-chain
        _send(sendParam, fee, msg.sender);

        emit BridgeInitiated(_tokenId, msg.sender, _dstEid, _to);
    }

    /**
     * @notice Quote bridge fee
     */
    function quoteBridge(
        uint256 _tokenId,
        uint32 _dstEid,
        bytes32 _to,
        bytes calldata _options
    ) external view returns (uint256 nativeFee, uint256 totalFee) {
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: _to,
            tokenId: _tokenId,
            extraOptions: _options,
            composeMsg: "",
            onftCmd: ""
        });

        MessagingFee memory fee = _quote(sendParam, false);
        nativeFee = fee.nativeFee;
        totalFee = fee.nativeFee + bridgeFee;
    }

    /**
     * @notice Check and update rate limit
     */
    function _checkAndUpdateRateLimit(uint32 _eid) internal {
        if (dailyLimit[_eid] == 0) return; // No limit set

        // Reset if new day
        if (block.timestamp >= lastResetTime[_eid] + 1 days) {
            dailyCount[_eid] = 0;
            lastResetTime[_eid] = block.timestamp;
        }

        require(dailyCount[_eid] < dailyLimit[_eid], "Daily limit reached");
        dailyCount[_eid]++;
    }

    /**
     * @notice Override credit to handle incoming bridged tokens
     */
    function _credit(
        address _to,
        uint256 _tokenId,
        uint32 _srcEid
    ) internal override returns (uint256) {
        // Track origin chain for wrapped tokens
        if (tokenOriginChain[_tokenId] == 0) {
            tokenOriginChain[_tokenId] = _srcEid;
        }

        emit BridgeCompleted(_tokenId, _to, _srcEid);
        return super._credit(_to, _tokenId, _srcEid);
    }

    // ==================== Admin Functions ====================

    function setBridgeFee(uint256 _fee) external onlyRole(FEE_MANAGER) {
        bridgeFee = _fee;
    }

    function setFeeRecipient(address _recipient) external onlyRole(FEE_MANAGER) {
        require(_recipient != address(0), "Invalid recipient");
        feeRecipient = _recipient;
    }

    function setDailyLimit(uint32 _eid, uint256 _limit) external onlyRole(BRIDGE_ADMIN) {
        dailyLimit[_eid] = _limit;
        emit DailyLimitUpdated(_eid, _limit);
    }

    function blacklistToken(uint256 _tokenId, bool _status) external onlyRole(BRIDGE_ADMIN) {
        blacklistedTokens[_tokenId] = _status;
        emit TokenBlacklisted(_tokenId, _status);
    }

    function pause() external onlyRole(BRIDGE_ADMIN) {
        _pause();
    }

    function unpause() external onlyRole(BRIDGE_ADMIN) {
        _unpause();
    }

    function withdrawFees() external onlyRole(FEE_MANAGER) {
        Address.sendValue(payable(feeRecipient), address(this).balance);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ONFT721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

## Bridge Adapter for Existing NFTs

File: `contracts/bridge/NFTBridgeAdapter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

/**
 * @title NFTBridgeAdapter
 * @notice Adapter to bridge existing ERC721 NFTs cross-chain
 */
contract NFTBridgeAdapter is OApp, ERC721Holder, AccessControl, ReentrancyGuard {
    bytes32 public constant BRIDGE_ADMIN = keccak256("BRIDGE_ADMIN");

    struct BridgedToken {
        address originalContract;
        uint256 originalTokenId;
        uint32 originChain;
        bool isLocked;
    }

    // Supported NFT contracts
    mapping(address => bool) public supportedContracts;

    // Locked tokens: contract => tokenId => owner
    mapping(address => mapping(uint256 => address)) public lockedTokenOwner;

    // Wrapped token tracking
    mapping(bytes32 => BridgedToken) public bridgedTokens;

    // Message types
    uint8 constant MSG_TYPE_BRIDGE = 1;
    uint8 constant MSG_TYPE_UNLOCK = 2;

    event TokenLocked(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed owner,
        uint32 dstEid
    );
    event TokenUnlocked(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed to
    );
    event ContractSupported(address indexed nftContract, bool supported);

    constructor(
        address _lzEndpoint,
        address _delegate
    ) OApp(_lzEndpoint, _delegate) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ADMIN, msg.sender);
    }

    /**
     * @notice Lock NFT and initiate bridge
     */
    function lockAndBridge(
        address _nftContract,
        uint256 _tokenId,
        uint32 _dstEid,
        address _toAddress,
        bytes calldata _options
    ) external payable nonReentrant {
        require(supportedContracts[_nftContract], "Contract not supported");

        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not owner");

        // Transfer NFT to this contract (lock)
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        lockedTokenOwner[_nftContract][_tokenId] = msg.sender;

        // Prepare message
        bytes memory payload = abi.encode(
            MSG_TYPE_BRIDGE,
            _nftContract,
            _tokenId,
            _toAddress,
            _getTokenURI(_nftContract, _tokenId)
        );

        // Send cross-chain message
        _lzSend(_dstEid, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));

        emit TokenLocked(_nftContract, _tokenId, msg.sender, _dstEid);
    }

    /**
     * @notice Receive cross-chain message
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata _payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (uint8 msgType, address nftContract, uint256 tokenId, address toAddress,) =
            abi.decode(_payload, (uint8, address, uint256, address, string));

        if (msgType == MSG_TYPE_UNLOCK) {
            // Unlock original token
            _unlockToken(nftContract, tokenId, toAddress);
        }
        // MSG_TYPE_BRIDGE would mint wrapped token (handled by paired ONFT contract)
    }

    /**
     * @notice Unlock token when bridged back
     */
    function _unlockToken(
        address _nftContract,
        uint256 _tokenId,
        address _to
    ) internal {
        require(
            lockedTokenOwner[_nftContract][_tokenId] != address(0),
            "Token not locked"
        );

        lockedTokenOwner[_nftContract][_tokenId] = address(0);
        IERC721(_nftContract).safeTransferFrom(address(this), _to, _tokenId);

        emit TokenUnlocked(_nftContract, _tokenId, _to);
    }

    /**
     * @notice Get token URI safely
     */
    function _getTokenURI(address _nftContract, uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        try IERC721Metadata(_nftContract).tokenURI(_tokenId) returns (string memory uri) {
            return uri;
        } catch {
            return "";
        }
    }

    /**
     * @notice Quote bridge fee
     */
    function quoteBridge(
        uint32 _dstEid,
        address _nftContract,
        uint256 _tokenId,
        address _toAddress,
        bytes calldata _options
    ) external view returns (uint256 nativeFee) {
        bytes memory payload = abi.encode(
            MSG_TYPE_BRIDGE,
            _nftContract,
            _tokenId,
            _toAddress,
            ""
        );

        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);
        return fee.nativeFee;
    }

    // ==================== Admin Functions ====================

    function setSupportedContract(address _contract, bool _supported)
        external
        onlyRole(BRIDGE_ADMIN)
    {
        supportedContracts[_contract] = _supported;
        emit ContractSupported(_contract, _supported);
    }

    function emergencyWithdraw(address _nftContract, uint256 _tokenId, address _to)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC721(_nftContract).safeTransferFrom(address(this), _to, _tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

interface IERC721Metadata {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
```

---

# MODULE 21: ACCOUNT ABSTRACTION (ERC-4337)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERC-4337 ACCOUNT ABSTRACTION                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Intent                                                    │
│      │                                                          │
│      ▼                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Bundler    │───▶│  EntryPoint  │───▶│   Paymaster  │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                             │                    │               │
│                             ▼                    ▼               │
│                      ┌──────────────┐    ┌──────────────┐       │
│                      │ Smart Wallet │    │  Gas Policy  │       │
│                      │  (ERC-4337)  │    │  ├─ Sponsor  │       │
│                      │  ├─ Execute  │    │  ├─ Limit    │       │
│                      │  ├─ Validate │    │  └─ Whitelist│       │
│                      │  └─ Modules  │    └──────────────┘       │
│                      └──────────────┘                           │
│                             │                                   │
│                             ▼                                   │
│                      ┌──────────────┐                           │
│                      │ NFT Protocol │                           │
│                      │  ├─ Mint     │                           │
│                      │  ├─ Transfer │                           │
│                      │  └─ Trade    │                           │
│                      └──────────────┘                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## NFT Paymaster Contract

File: `contracts/aa/NFTPaymaster.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NFTPaymaster
 * @notice Sponsors gas for NFT operations (minting, trading, etc.)
 */
contract NFTPaymaster is BasePaymaster, AccessControl {
    bytes32 public constant SPONSOR_ROLE = keccak256("SPONSOR_ROLE");
    bytes32 public constant POLICY_ADMIN = keccak256("POLICY_ADMIN");

    // Sponsored contracts
    mapping(address => bool) public sponsoredContracts;

    // Sponsored function selectors
    mapping(bytes4 => bool) public sponsoredSelectors;

    // User gas limits
    mapping(address => uint256) public userGasUsed;
    mapping(address => uint256) public userGasLimit;
    uint256 public defaultGasLimit = 1 ether; // 1 ETH worth of gas per user

    // Daily limits
    uint256 public dailyBudget;
    uint256 public dailySpent;
    uint256 public lastResetDay;

    // Token payment option
    IERC20 public paymentToken;
    uint256 public tokenGasPrice; // tokens per gas unit

    event ContractSponsored(address indexed contractAddr, bool sponsored);
    event SelectorSponsored(bytes4 indexed selector, bool sponsored);
    event GasSponsored(address indexed user, uint256 gasUsed, uint256 gasCost);
    event UserLimitSet(address indexed user, uint256 limit);

    constructor(
        IEntryPoint _entryPoint,
        address _owner
    ) BasePaymaster(_entryPoint) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SPONSOR_ROLE, _owner);
        _grantRole(POLICY_ADMIN, _owner);

        // Sponsor common NFT operations by default
        sponsoredSelectors[bytes4(keccak256("safeMint(address,uint256)"))] = true;
        sponsoredSelectors[bytes4(keccak256("safeMintAutoId(address)"))] = true;
        sponsoredSelectors[bytes4(keccak256("safeTransferFrom(address,address,uint256)"))] = true;
        sponsoredSelectors[bytes4(keccak256("approve(address,uint256)"))] = true;
        sponsoredSelectors[bytes4(keccak256("setApprovalForAll(address,bool)"))] = true;
    }

    /**
     * @notice Validate user operation for sponsorship
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        address sender = userOp.sender;

        // Check daily budget
        _checkAndResetDaily();
        require(dailySpent + maxCost <= dailyBudget, "Daily budget exceeded");

        // Check user limit
        require(
            userGasUsed[sender] + maxCost <= _getUserLimit(sender),
            "User limit exceeded"
        );

        // Decode calldata to check if operation is sponsored
        if (userOp.callData.length >= 4) {
            bytes4 selector = bytes4(userOp.callData[:4]);

            // Check if this is a batched call
            if (selector == bytes4(keccak256("executeBatch(address[],uint256[],bytes[])"))) {
                // Validate batch operations
                require(_validateBatchOp(userOp.callData), "Batch not sponsored");
            } else {
                // Single operation
                (address target,, bytes memory data) = _decodeExecute(userOp.callData);
                require(_isSponsoredOperation(target, data), "Operation not sponsored");
            }
        }

        // Return context for postOp
        context = abi.encode(sender, maxCost);
        validationData = 0; // Valid
    }

    /**
     * @notice Post-operation accounting
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) internal override {
        if (mode == PostOpMode.postOpReverted) {
            return;
        }

        (address sender, ) = abi.decode(context, (address, uint256));

        userGasUsed[sender] += actualGasCost;
        dailySpent += actualGasCost;

        emit GasSponsored(sender, actualGasCost, actualGasCost);
    }

    /**
     * @notice Check if operation is sponsored
     */
    function _isSponsoredOperation(address target, bytes memory data)
        internal
        view
        returns (bool)
    {
        if (!sponsoredContracts[target]) {
            return false;
        }

        if (data.length < 4) {
            return false;
        }

        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }

        return sponsoredSelectors[selector];
    }

    /**
     * @notice Validate batch operations
     */
    function _validateBatchOp(bytes calldata callData) internal view returns (bool) {
        // Skip selector (4 bytes)
        (address[] memory targets,, bytes[] memory datas) =
            abi.decode(callData[4:], (address[], uint256[], bytes[]));

        for (uint256 i = 0; i < targets.length; i++) {
            if (!_isSponsoredOperation(targets[i], datas[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Decode execute calldata
     */
    function _decodeExecute(bytes calldata callData)
        internal
        pure
        returns (address target, uint256 value, bytes memory data)
    {
        // Assume SimpleAccount execute(address,uint256,bytes)
        (target, value, data) = abi.decode(callData[4:], (address, uint256, bytes));
    }

    /**
     * @notice Get user's gas limit
     */
    function _getUserLimit(address user) internal view returns (uint256) {
        uint256 limit = userGasLimit[user];
        return limit > 0 ? limit : defaultGasLimit;
    }

    /**
     * @notice Check and reset daily budget
     */
    function _checkAndResetDaily() internal {
        uint256 today = block.timestamp / 1 days;
        if (today > lastResetDay) {
            dailySpent = 0;
            lastResetDay = today;
        }
    }

    // ==================== Admin Functions ====================

    function setSponsoredContract(address _contract, bool _sponsored)
        external
        onlyRole(POLICY_ADMIN)
    {
        sponsoredContracts[_contract] = _sponsored;
        emit ContractSponsored(_contract, _sponsored);
    }

    function setSponsoredSelector(bytes4 _selector, bool _sponsored)
        external
        onlyRole(POLICY_ADMIN)
    {
        sponsoredSelectors[_selector] = _sponsored;
        emit SelectorSponsored(_selector, _sponsored);
    }

    function setUserLimit(address _user, uint256 _limit)
        external
        onlyRole(POLICY_ADMIN)
    {
        userGasLimit[_user] = _limit;
        emit UserLimitSet(_user, _limit);
    }

    function setDefaultGasLimit(uint256 _limit) external onlyRole(POLICY_ADMIN) {
        defaultGasLimit = _limit;
    }

    function setDailyBudget(uint256 _budget) external onlyRole(POLICY_ADMIN) {
        dailyBudget = _budget;
    }

    function resetUserGas(address _user) external onlyRole(POLICY_ADMIN) {
        userGasUsed[_user] = 0;
    }

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entryPoint.withdrawTo(payable(msg.sender), amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

## Smart Wallet Factory

File: `contracts/aa/NFTSmartWalletFactory.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./NFTSmartWallet.sol";

/**
 * @title NFTSmartWalletFactory
 * @notice Factory for deploying smart wallets with NFT features
 */
contract NFTSmartWalletFactory {
    IEntryPoint public immutable entryPoint;
    address public immutable walletImplementation;

    event WalletCreated(address indexed wallet, address indexed owner, uint256 salt);

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        walletImplementation = address(new NFTSmartWallet(_entryPoint));
    }

    /**
     * @notice Create new smart wallet
     */
    function createWallet(address owner, uint256 salt) external returns (NFTSmartWallet) {
        address walletAddress = getWalletAddress(owner, salt);

        if (walletAddress.code.length > 0) {
            return NFTSmartWallet(payable(walletAddress));
        }

        bytes memory initCode = abi.encodePacked(
            type(NFTSmartWallet).creationCode,
            abi.encode(entryPoint, owner)
        );

        address wallet = Create2.deploy(0, bytes32(salt), initCode);
        emit WalletCreated(wallet, owner, salt);

        return NFTSmartWallet(payable(wallet));
    }

    /**
     * @notice Compute wallet address
     */
    function getWalletAddress(address owner, uint256 salt) public view returns (address) {
        bytes memory initCode = abi.encodePacked(
            type(NFTSmartWallet).creationCode,
            abi.encode(entryPoint, owner)
        );

        return Create2.computeAddress(bytes32(salt), keccak256(initCode));
    }
}
```

## Smart Wallet Implementation

File: `contracts/aa/NFTSmartWallet.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NFTSmartWallet
 * @notice ERC-4337 smart wallet optimized for NFT operations
 */
contract NFTSmartWallet is BaseAccount, IERC721Receiver, IERC1155Receiver {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IEntryPoint private immutable _entryPoint;
    address public owner;

    // Session keys for gasless NFT operations
    mapping(address => SessionKey) public sessionKeys;

    struct SessionKey {
        uint48 validUntil;
        uint48 validAfter;
        address[] allowedContracts;
        bytes4[] allowedSelectors;
    }

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event SessionKeyAdded(address indexed key, uint48 validUntil);
    event SessionKeyRevoked(address indexed key);

    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == address(this), "Not owner");
        _;
    }

    constructor(IEntryPoint anEntryPoint, address _owner) {
        _entryPoint = anEntryPoint;
        owner = _owner;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @notice Validate user operation signature
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        // Check if owner
        if (signer == owner) {
            return 0;
        }

        // Check if valid session key
        SessionKey storage session = sessionKeys[signer];
        if (session.validUntil > 0) {
            // Validate session key permissions
            if (_validateSessionKey(signer, userOp.callData)) {
                return _packValidationData(
                    false,
                    session.validUntil,
                    session.validAfter
                );
            }
        }

        return SIG_VALIDATION_FAILED;
    }

    /**
     * @notice Validate session key has permission for operation
     */
    function _validateSessionKey(address signer, bytes calldata callData)
        internal
        view
        returns (bool)
    {
        SessionKey storage session = sessionKeys[signer];

        if (callData.length < 4) return false;

        // Decode execute call
        (address target,, bytes memory data) = abi.decode(
            callData[4:],
            (address, uint256, bytes)
        );

        // Check allowed contracts
        bool contractAllowed = false;
        for (uint256 i = 0; i < session.allowedContracts.length; i++) {
            if (session.allowedContracts[i] == target) {
                contractAllowed = true;
                break;
            }
        }
        if (!contractAllowed) return false;

        // Check allowed selectors
        if (data.length >= 4) {
            bytes4 selector = bytes4(data);
            bool selectorAllowed = false;
            for (uint256 i = 0; i < session.allowedSelectors.length; i++) {
                if (session.allowedSelectors[i] == selector) {
                    selectorAllowed = true;
                    break;
                }
            }
            if (!selectorAllowed) return false;
        }

        return true;
    }

    /**
     * @notice Execute operation
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");
        return result;
    }

    /**
     * @notice Execute batch operations
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyOwner returns (bytes[] memory results) {
        require(
            targets.length == values.length && values.length == datas.length,
            "Length mismatch"
        );

        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{value: values[i]}(datas[i]);
            require(success, "Batch execution failed");
            results[i] = result;
        }
    }

    /**
     * @notice Add session key for gasless operations
     */
    function addSessionKey(
        address key,
        uint48 validUntil,
        uint48 validAfter,
        address[] calldata allowedContracts,
        bytes4[] calldata allowedSelectors
    ) external onlyOwner {
        sessionKeys[key] = SessionKey({
            validUntil: validUntil,
            validAfter: validAfter,
            allowedContracts: allowedContracts,
            allowedSelectors: allowedSelectors
        });
        emit SessionKeyAdded(key, validUntil);
    }

    /**
     * @notice Revoke session key
     */
    function revokeSessionKey(address key) external onlyOwner {
        delete sessionKeys[key];
        emit SessionKeyRevoked(key);
    }

    /**
     * @notice Change owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    // ==================== Token Receivers ====================

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    receive() external payable {}
}
```

---

# MODULE 27: ANALYTICS DASHBOARD

## Dune Analytics Queries

File: `analytics/dune/nft_protocol_dashboard.sql`

```sql
-- ============================================================
-- NFT PROTOCOL ANALYTICS DASHBOARD
-- Dune Analytics SQL Queries
-- ============================================================

-- ===========================================
-- 1. DAILY TRADING VOLUME
-- ===========================================
-- @name: Daily Trading Volume
-- @description: Track daily NFT trading volume in ETH and USD

WITH daily_sales AS (
    SELECT
        DATE_TRUNC('day', block_time) AS day,
        COUNT(*) AS num_sales,
        SUM(CAST(value AS DECIMAL(38,0)) / 1e18) AS volume_eth
    FROM {{blockchain}}.transactions
    WHERE "to" = {{marketplace_contract}}
        AND success = true
        AND block_time >= NOW() - INTERVAL '90 days'
    GROUP BY 1
),
eth_prices AS (
    SELECT
        DATE_TRUNC('day', minute) AS day,
        AVG(price) AS eth_price
    FROM prices.usd
    WHERE symbol = 'ETH'
        AND minute >= NOW() - INTERVAL '90 days'
    GROUP BY 1
)
SELECT
    ds.day,
    ds.num_sales,
    ds.volume_eth,
    ds.volume_eth * ep.eth_price AS volume_usd,
    SUM(ds.volume_eth) OVER (ORDER BY ds.day) AS cumulative_volume_eth
FROM daily_sales ds
LEFT JOIN eth_prices ep ON ds.day = ep.day
ORDER BY ds.day DESC;

-- ===========================================
-- 2. TOP COLLECTIONS BY VOLUME
-- ===========================================
-- @name: Top Collections
-- @description: Ranking of NFT collections by trading volume

SELECT
    nft_contract_address,
    COUNT(*) AS total_sales,
    COUNT(DISTINCT buyer) AS unique_buyers,
    COUNT(DISTINCT seller) AS unique_sellers,
    SUM(price_eth) AS total_volume_eth,
    AVG(price_eth) AS avg_price_eth,
    MIN(price_eth) AS floor_price_eth,
    MAX(price_eth) AS ceiling_price_eth
FROM nft_protocol.sales
WHERE block_time >= NOW() - INTERVAL '30 days'
GROUP BY nft_contract_address
ORDER BY total_volume_eth DESC
LIMIT 50;

-- ===========================================
-- 3. USER ACTIVITY METRICS
-- ===========================================
-- @name: User Activity
-- @description: Track user engagement and activity

WITH user_activity AS (
    SELECT
        user_address,
        COUNT(DISTINCT CASE WHEN action = 'mint' THEN tx_hash END) AS mints,
        COUNT(DISTINCT CASE WHEN action = 'buy' THEN tx_hash END) AS purchases,
        COUNT(DISTINCT CASE WHEN action = 'sell' THEN tx_hash END) AS sales,
        COUNT(DISTINCT CASE WHEN action = 'list' THEN tx_hash END) AS listings,
        SUM(CASE WHEN action = 'buy' THEN value_eth ELSE 0 END) AS total_spent,
        SUM(CASE WHEN action = 'sell' THEN value_eth ELSE 0 END) AS total_earned,
        MIN(block_time) AS first_activity,
        MAX(block_time) AS last_activity
    FROM nft_protocol.user_actions
    WHERE block_time >= NOW() - INTERVAL '30 days'
    GROUP BY user_address
)
SELECT
    user_address,
    mints,
    purchases,
    sales,
    listings,
    total_spent,
    total_earned,
    total_earned - total_spent AS net_profit,
    DATE_DIFF('day', first_activity, last_activity) AS active_days
FROM user_activity
ORDER BY total_spent + total_earned DESC
LIMIT 100;

-- ===========================================
-- 4. LENDING PROTOCOL METRICS
-- ===========================================
-- @name: Lending Metrics
-- @description: NFT lending protocol health metrics

SELECT
    DATE_TRUNC('day', block_time) AS day,
    COUNT(CASE WHEN event_type = 'LoanCreated' THEN 1 END) AS new_loans,
    COUNT(CASE WHEN event_type = 'LoanRepaid' THEN 1 END) AS repaid_loans,
    COUNT(CASE WHEN event_type = 'LoanLiquidated' THEN 1 END) AS liquidated_loans,
    SUM(CASE WHEN event_type = 'LoanCreated' THEN principal_eth END) AS total_borrowed,
    SUM(CASE WHEN event_type = 'LoanRepaid' THEN repayment_eth END) AS total_repaid,
    AVG(interest_rate_bps) / 100.0 AS avg_interest_rate
FROM nft_protocol.lending_events
WHERE block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- ===========================================
-- 5. FRACTIONALIZATION METRICS
-- ===========================================
-- @name: Fractionalization Stats
-- @description: Track NFT fractionalization activity

SELECT
    vault_address,
    nft_contract,
    token_id,
    total_supply AS fraction_supply,
    reserve_price_eth,
    (SELECT COUNT(DISTINCT holder) FROM nft_protocol.fraction_holders WHERE vault = vault_address) AS unique_holders,
    (SELECT SUM(amount) * latest_price FROM nft_protocol.fraction_trades WHERE vault = vault_address) AS implied_valuation,
    created_at,
    CASE WHEN buyout_completed THEN 'Bought Out' ELSE 'Active' END AS status
FROM nft_protocol.fractional_vaults
ORDER BY implied_valuation DESC NULLS LAST
LIMIT 50;

-- ===========================================
-- 6. ROYALTY DISTRIBUTION
-- ===========================================
-- @name: Royalty Analytics
-- @description: Track royalty payments to creators

SELECT
    creator_address,
    COUNT(*) AS sales_count,
    SUM(sale_price_eth) AS total_sales_volume,
    SUM(royalty_paid_eth) AS total_royalties_received,
    AVG(royalty_rate_bps) / 100.0 AS avg_royalty_rate,
    SUM(royalty_paid_eth) / NULLIF(SUM(sale_price_eth), 0) * 100 AS effective_royalty_rate
FROM nft_protocol.royalty_payments
WHERE block_time >= NOW() - INTERVAL '30 days'
GROUP BY creator_address
ORDER BY total_royalties_received DESC
LIMIT 50;

-- ===========================================
-- 7. CROSS-CHAIN BRIDGE ACTIVITY
-- ===========================================
-- @name: Bridge Analytics
-- @description: Track cross-chain NFT transfers

SELECT
    DATE_TRUNC('day', block_time) AS day,
    source_chain,
    destination_chain,
    COUNT(*) AS transfers,
    COUNT(DISTINCT token_id) AS unique_nfts,
    SUM(bridge_fee_eth) AS total_fees
FROM nft_protocol.bridge_events
WHERE block_time >= NOW() - INTERVAL '30 days'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, transfers DESC;

-- ===========================================
-- 8. GOVERNANCE PARTICIPATION
-- ===========================================
-- @name: DAO Governance
-- @description: Track governance participation

SELECT
    proposal_id,
    title,
    proposer,
    for_votes,
    against_votes,
    abstain_votes,
    for_votes + against_votes + abstain_votes AS total_votes,
    for_votes * 100.0 / NULLIF(for_votes + against_votes, 0) AS approval_rate,
    CASE
        WHEN status = 0 THEN 'Pending'
        WHEN status = 1 THEN 'Active'
        WHEN status = 2 THEN 'Canceled'
        WHEN status = 3 THEN 'Defeated'
        WHEN status = 4 THEN 'Succeeded'
        WHEN status = 5 THEN 'Queued'
        WHEN status = 6 THEN 'Expired'
        WHEN status = 7 THEN 'Executed'
    END AS status_name,
    created_at,
    voting_ends_at
FROM nft_protocol.governance_proposals
ORDER BY created_at DESC
LIMIT 20;
```

## Dashboard React Component

File: `frontend/components/analytics/Dashboard.tsx`

```tsx
'use client';

import { useState, useEffect } from 'react';
import {
  LineChart, Line, BarChart, Bar, PieChart, Pie,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, Area, AreaChart
} from 'recharts';

interface DashboardProps {
  duneApiKey: string;
  queryIds: {
    volume: number;
    collections: number;
    users: number;
    lending: number;
  };
}

export function AnalyticsDashboard({ duneApiKey, queryIds }: DashboardProps) {
  const [volumeData, setVolumeData] = useState<any[]>([]);
  const [collectionsData, setCollectionsData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState('30d');

  useEffect(() => {
    fetchDashboardData();
  }, [timeRange]);

  const fetchDashboardData = async () => {
    setLoading(true);
    try {
      const [volume, collections] = await Promise.all([
        fetchDuneQuery(queryIds.volume),
        fetchDuneQuery(queryIds.collections),
      ]);
      setVolumeData(volume);
      setCollectionsData(collections);
    } catch (error) {
      console.error('Failed to fetch analytics:', error);
    }
    setLoading(false);
  };

  const fetchDuneQuery = async (queryId: number) => {
    const res = await fetch(
      `https://api.dune.com/api/v1/query/${queryId}/results`,
      {
        headers: { 'X-Dune-API-Key': duneApiKey },
      }
    );
    const data = await res.json();
    return data.result?.rows || [];
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500" />
      </div>
    );
  }

  return (
    <div className="space-y-8 p-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-white">Protocol Analytics</h1>
        <div className="flex gap-2">
          {['7d', '30d', '90d'].map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-4 py-2 rounded-lg ${
                timeRange === range
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              {range}
            </button>
          ))}
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KPICard
          title="Total Volume"
          value={`${formatNumber(sumField(volumeData, 'volume_eth'))} ETH`}
          change={calculateChange(volumeData, 'volume_eth')}
        />
        <KPICard
          title="Total Sales"
          value={formatNumber(sumField(volumeData, 'num_sales'))}
          change={calculateChange(volumeData, 'num_sales')}
        />
        <KPICard
          title="Unique Buyers"
          value={formatNumber(sumField(collectionsData, 'unique_buyers'))}
        />
        <KPICard
          title="Avg Sale Price"
          value={`${avgField(collectionsData, 'avg_price_eth').toFixed(2)} ETH`}
        />
      </div>

      {/* Volume Chart */}
      <div className="bg-gray-800 rounded-xl p-6">
        <h2 className="text-xl font-semibold text-white mb-4">Trading Volume</h2>
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={volumeData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis
              dataKey="day"
              tickFormatter={(v) => new Date(v).toLocaleDateString()}
              stroke="#9CA3AF"
            />
            <YAxis stroke="#9CA3AF" />
            <Tooltip
              contentStyle={{ backgroundColor: '#1F2937', border: 'none' }}
              labelFormatter={(v) => new Date(v).toLocaleDateString()}
            />
            <Area
              type="monotone"
              dataKey="volume_eth"
              stroke="#3B82F6"
              fill="#3B82F6"
              fillOpacity={0.3}
              name="Volume (ETH)"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Collections Table */}
      <div className="bg-gray-800 rounded-xl p-6">
        <h2 className="text-xl font-semibold text-white mb-4">Top Collections</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead>
              <tr className="text-gray-400 border-b border-gray-700">
                <th className="pb-3">Collection</th>
                <th className="pb-3">Sales</th>
                <th className="pb-3">Volume</th>
                <th className="pb-3">Floor</th>
                <th className="pb-3">Buyers</th>
              </tr>
            </thead>
            <tbody>
              {collectionsData.slice(0, 10).map((collection, i) => (
                <tr key={i} className="border-b border-gray-700/50 text-white">
                  <td className="py-3 font-mono text-sm">
                    {truncateAddress(collection.nft_contract_address)}
                  </td>
                  <td className="py-3">{formatNumber(collection.total_sales)}</td>
                  <td className="py-3">{collection.total_volume_eth?.toFixed(2)} ETH</td>
                  <td className="py-3">{collection.floor_price_eth?.toFixed(3)} ETH</td>
                  <td className="py-3">{formatNumber(collection.unique_buyers)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

// Helper Components
function KPICard({ title, value, change }: { title: string; value: string; change?: number }) {
  return (
    <div className="bg-gray-800 rounded-xl p-6">
      <p className="text-gray-400 text-sm">{title}</p>
      <p className="text-2xl font-bold text-white mt-1">{value}</p>
      {change !== undefined && (
        <p className={`text-sm mt-1 ${change >= 0 ? 'text-green-400' : 'text-red-400'}`}>
          {change >= 0 ? '+' : ''}{change.toFixed(1)}%
        </p>
      )}
    </div>
  );
}

// Helper Functions
function formatNumber(n: number): string {
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
  return n?.toFixed(0) || '0';
}

function truncateAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function sumField(data: any[], field: string): number {
  return data.reduce((sum, item) => sum + (item[field] || 0), 0);
}

function avgField(data: any[], field: string): number {
  const values = data.filter(item => item[field]);
  return values.reduce((sum, item) => sum + item[field], 0) / (values.length || 1);
}

function calculateChange(data: any[], field: string): number {
  if (data.length < 2) return 0;
  const recent = data.slice(0, Math.floor(data.length / 2));
  const previous = data.slice(Math.floor(data.length / 2));
  const recentSum = sumField(recent, field);
  const previousSum = sumField(previous, field);
  return previousSum ? ((recentSum - previousSum) / previousSum) * 100 : 0;
}
```

---

# MODULE 62: MEV PROTECTION

## MEV-Protected Minting Contract

File: `contracts/mev/MEVProtectedMint.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title MEVProtectedMint
 * @notice NFT minting with MEV protection mechanisms
 */
contract MEVProtectedMint is ERC721, Ownable, ReentrancyGuard {

    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    // MEV Protection Settings
    bool public mevProtectionEnabled = true;
    uint256 public maxGasPrice = 100 gwei;
    uint256 public minBlockDelay = 1; // Blocks between commit and mint
    uint256 public maxBlockDelay = 50;

    // Commit-reveal for MEV protection
    mapping(bytes32 => Commitment) public commitments;
    mapping(address => uint256) public lastMintBlock;

    struct Commitment {
        address sender;
        uint256 amount;
        uint256 blockNumber;
        bool revealed;
    }

    // Flashbots protection
    mapping(address => bool) public trustedRelayers;
    bool public onlyTrustedRelayers = false;

    // Per-block mint limits
    uint256 public maxMintsPerBlock = 10;
    mapping(uint256 => uint256) public blockMintCount;

    string private _baseTokenURI;

    event Committed(address indexed sender, bytes32 indexed commitHash);
    event MintedWithProtection(address indexed minter, uint256 tokenId);
    event MEVProtectionToggled(bool enabled);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
    }

    // ==================== Commit-Reveal Minting ====================

    /**
     * @notice Commit to mint (step 1)
     */
    function commit(bytes32 commitHash) external payable {
        require(mevProtectionEnabled, "MEV protection disabled");
        require(commitments[commitHash].sender == address(0), "Commit exists");
        require(msg.value >= mintPrice, "Insufficient payment");

        commitments[commitHash] = Commitment({
            sender: msg.sender,
            amount: 1,
            blockNumber: block.number,
            revealed: false
        });

        emit Committed(msg.sender, commitHash);
    }

    /**
     * @notice Reveal and mint (step 2)
     */
    function reveal(bytes32 secret) external nonReentrant {
        require(mevProtectionEnabled, "Use directMint");

        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, secret));
        Commitment storage commitment = commitments[commitHash];

        require(commitment.sender == msg.sender, "Invalid commit");
        require(!commitment.revealed, "Already revealed");
        require(
            block.number >= commitment.blockNumber + minBlockDelay,
            "Too early"
        );
        require(
            block.number <= commitment.blockNumber + maxBlockDelay,
            "Commit expired"
        );

        commitment.revealed = true;

        _protectedMint(msg.sender, commitment.amount);
    }

    /**
     * @notice Direct mint with MEV checks (no commit-reveal)
     */
    function directMint(uint256 quantity) external payable nonReentrant {
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        if (mevProtectionEnabled) {
            // Gas price check
            require(tx.gasprice <= maxGasPrice, "Gas price too high");

            // Block delay check
            require(
                lastMintBlock[msg.sender] == 0 ||
                block.number > lastMintBlock[msg.sender],
                "One tx per block"
            );

            // Per-block limit
            require(
                blockMintCount[block.number] + quantity <= maxMintsPerBlock,
                "Block limit reached"
            );

            // Trusted relayer check
            if (onlyTrustedRelayers) {
                require(trustedRelayers[tx.origin], "Untrusted relayer");
            }
        }

        lastMintBlock[msg.sender] = block.number;
        blockMintCount[block.number] += quantity;

        _protectedMint(msg.sender, quantity);
    }

    /**
     * @notice Internal protected mint
     */
    function _protectedMint(address to, uint256 quantity) internal {
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds supply");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter++;
            _safeMint(to, _tokenIdCounter);
            emit MintedWithProtection(to, _tokenIdCounter);
        }
    }

    // ==================== Helper Functions ====================

    /**
     * @notice Generate commit hash (view function for frontend)
     */
    function generateCommitHash(address sender, bytes32 secret)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sender, secret));
    }

    /**
     * @notice Check if commit is ready to reveal
     */
    function canReveal(bytes32 commitHash) external view returns (bool, string memory) {
        Commitment storage commitment = commitments[commitHash];

        if (commitment.sender == address(0)) {
            return (false, "Commit not found");
        }
        if (commitment.revealed) {
            return (false, "Already revealed");
        }
        if (block.number < commitment.blockNumber + minBlockDelay) {
            return (false, "Too early");
        }
        if (block.number > commitment.blockNumber + maxBlockDelay) {
            return (false, "Commit expired");
        }

        return (true, "Ready to reveal");
    }

    /**
     * @notice Refund expired commitment
     */
    function refundExpiredCommit(bytes32 commitHash) external nonReentrant {
        Commitment storage commitment = commitments[commitHash];

        require(commitment.sender == msg.sender, "Not your commit");
        require(!commitment.revealed, "Already revealed");
        require(
            block.number > commitment.blockNumber + maxBlockDelay,
            "Not expired"
        );

        uint256 refundAmount = mintPrice * commitment.amount;
        delete commitments[commitHash];

        Address.sendValue(payable(msg.sender), refundAmount);
    }

    // ==================== Admin ====================

    function setMEVProtection(bool enabled) external onlyOwner {
        mevProtectionEnabled = enabled;
        emit MEVProtectionToggled(enabled);
    }

    function setMaxGasPrice(uint256 price) external onlyOwner {
        maxGasPrice = price;
    }

    function setBlockDelays(uint256 min, uint256 max) external onlyOwner {
        require(min < max, "Invalid range");
        minBlockDelay = min;
        maxBlockDelay = max;
    }

    function setMaxMintsPerBlock(uint256 max) external onlyOwner {
        maxMintsPerBlock = max;
    }

    function setTrustedRelayer(address relayer, bool trusted) external onlyOwner {
        trustedRelayers[relayer] = trusted;
    }

    function setOnlyTrustedRelayers(bool only) external onlyOwner {
        onlyTrustedRelayers = only;
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

# MODULE 63: PERMIT2 INTEGRATION

## Permit2 NFT Marketplace Contract

File: `contracts/permit2/Permit2Marketplace.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// Permit2 interfaces
interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    struct PermitBatch {
        TokenPermissions[] permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetailsBatch {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitBatch calldata permit,
        SignatureTransferDetailsBatch[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

/**
 * @title Permit2Marketplace
 * @notice NFT marketplace with Permit2 gasless approvals
 */
contract Permit2Marketplace is ReentrancyGuard, Ownable {

    IPermit2 public immutable permit2;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        uint256 expiry;
        bool active;
    }

    mapping(bytes32 => Listing) public listings;

    // Platform fee
    uint256 public platformFee = 250; // 2.5%
    address public feeRecipient;

    // Nonce tracking for cancellations
    mapping(address => uint256) public userNonce;

    event Listed(bytes32 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event Sold(bytes32 indexed listingId, address indexed buyer, uint256 price);
    event Cancelled(bytes32 indexed listingId);

    constructor(address _permit2, address _feeRecipient) Ownable(msg.sender) {
        permit2 = IPermit2(_permit2);
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Create a listing (seller signs off-chain, no on-chain approval needed)
     */
    function createListing(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 expiry
    ) external returns (bytes32) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(expiry > block.timestamp, "Invalid expiry");

        bytes32 listingId = keccak256(abi.encodePacked(
            msg.sender,
            nftContract,
            tokenId,
            paymentToken,
            price,
            userNonce[msg.sender]++
        ));

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            expiry: expiry,
            active: true
        });

        emit Listed(listingId, msg.sender, nftContract, tokenId, price);

        return listingId;
    }

    /**
     * @notice Buy NFT using Permit2 (gasless token approval)
     */
    function buyWithPermit2(
        bytes32 listingId,
        IPermit2.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(block.timestamp < listing.expiry, "Listing expired");
        require(listing.paymentToken != address(0), "Use buyWithETH");
        require(permit.permitted.token == listing.paymentToken, "Wrong token");
        require(permit.permitted.amount >= listing.price, "Insufficient amount");

        listing.active = false;

        // Calculate fees
        uint256 fee = (listing.price * platformFee) / 10000;
        uint256 sellerAmount = listing.price - fee;

        // Transfer payment via Permit2 (to this contract first)
        permit2.permitTransferFrom(
            permit,
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: listing.price
            }),
            msg.sender,
            signature
        );

        // Distribute payment
        IERC20(listing.paymentToken).transfer(listing.seller, sellerAmount);
        if (fee > 0) {
            IERC20(listing.paymentToken).transfer(feeRecipient, fee);
        }

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        emit Sold(listingId, msg.sender, listing.price);
    }

    /**
     * @notice Buy with ETH
     */
    function buyWithETH(bytes32 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(block.timestamp < listing.expiry, "Listing expired");
        require(listing.paymentToken == address(0), "Use buyWithPermit2");
        require(msg.value >= listing.price, "Insufficient payment");

        listing.active = false;

        // Calculate fees
        uint256 fee = (listing.price * platformFee) / 10000;
        uint256 sellerAmount = listing.price - fee;

        // Transfer ETH to seller
        Address.sendValue(payable(listing.seller), sellerAmount);

        // Transfer fee
        if (fee > 0) {
            Address.sendValue(payable(feeRecipient), fee);
        }

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Refund excess
        if (msg.value > listing.price) {
            Address.sendValue(payable(msg.sender), msg.value - listing.price);
        }

        emit Sold(listingId, msg.sender, listing.price);
    }

    /**
     * @notice Cancel listing
     */
    function cancelListing(bytes32 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not active");

        listing.active = false;

        emit Cancelled(listingId);
    }

    /**
     * @notice Get listing details
     */
    function getListing(bytes32 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @notice Generate listing ID (for frontend)
     */
    function generateListingId(
        address seller,
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(
            seller,
            nftContract,
            tokenId,
            paymentToken,
            price,
            userNonce[seller]
        ));
    }

    // ==================== Admin ====================

    function setPlatformFee(uint256 fee) external onlyOwner {
        require(fee <= 1000, "Fee too high"); // Max 10%
        platformFee = fee;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        feeRecipient = recipient;
    }

    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).transfer(msg.sender, balance);
        }
    }
}
```

---
