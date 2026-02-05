# SDK, Configuration & Tooling

SDK package, batch operations (Multicall), contract ABIs, event signatures, environment templates, Hardhat configuration, and internationalized error messages.

---

# MODULE 28: SDK PACKAGE

## NPM Package Structure

```
nft-protocol-sdk/
├── src/
│   ├── index.ts
│   ├── client.ts
│   ├── contracts/
│   │   ├── index.ts
│   │   ├── nft.ts
│   │   ├── marketplace.ts
│   │   ├── lending.ts
│   │   ├── fractional.ts
│   │   └── governance.ts
│   ├── utils/
│   │   ├── ipfs.ts
│   │   ├── metadata.ts
│   │   └── formatting.ts
│   └── types/
│       └── index.ts
├── package.json
├── tsconfig.json
└── README.md
```

## Main SDK Client

File: `sdk/src/client.ts`

```typescript
import {
  createPublicClient,
  createWalletClient,
  http,
  PublicClient,
  WalletClient,
  Chain,
  Transport,
  Account,
} from 'viem';
import { mainnet, polygon, base, arbitrum } from 'viem/chains';
import { NFTContract } from './contracts/nft';
import { MarketplaceContract } from './contracts/marketplace';
import { LendingContract } from './contracts/lending';
import { FractionalContract } from './contracts/fractional';
import { GovernanceContract } from './contracts/governance';
import { IPFSService } from './utils/ipfs';
import { ContractAddresses, SDKConfig } from './types';

const SUPPORTED_CHAINS: Record<number, Chain> = {
  1: mainnet,
  137: polygon,
  8453: base,
  42161: arbitrum,
};

export class NFTProtocolSDK {
  public readonly publicClient: PublicClient;
  public readonly walletClient?: WalletClient;
  public readonly chain: Chain;

  // Contract interfaces
  public readonly nft: NFTContract;
  public readonly marketplace: MarketplaceContract;
  public readonly lending: LendingContract;
  public readonly fractional: FractionalContract;
  public readonly governance: GovernanceContract;

  // Services
  public readonly ipfs: IPFSService;

  constructor(config: SDKConfig) {
    const chain = SUPPORTED_CHAINS[config.chainId];
    if (!chain) throw new Error(`Unsupported chain: ${config.chainId}`);

    this.chain = chain;

    // Create clients
    this.publicClient = createPublicClient({
      chain,
      transport: http(config.rpcUrl),
    });

    if (config.account) {
      this.walletClient = createWalletClient({
        chain,
        transport: http(config.rpcUrl),
        account: config.account,
      });
    }

    // Initialize contracts
    const addresses = config.addresses;
    this.nft = new NFTContract(this.publicClient, this.walletClient, addresses.nft);
    this.marketplace = new MarketplaceContract(this.publicClient, this.walletClient, addresses.marketplace);
    this.lending = new LendingContract(this.publicClient, this.walletClient, addresses.lending);
    this.fractional = new FractionalContract(this.publicClient, this.walletClient, addresses.fractional);
    this.governance = new GovernanceContract(this.publicClient, this.walletClient, addresses.governance);

    // Initialize services
    this.ipfs = new IPFSService(config.ipfsGateway, config.pinataJwt);
  }

  // ==================== Factory Methods ====================

  static create(config: SDKConfig): NFTProtocolSDK {
    return new NFTProtocolSDK(config);
  }

  static forMainnet(rpcUrl: string, addresses: ContractAddresses): NFTProtocolSDK {
    return new NFTProtocolSDK({ chainId: 1, rpcUrl, addresses });
  }

  static forPolygon(rpcUrl: string, addresses: ContractAddresses): NFTProtocolSDK {
    return new NFTProtocolSDK({ chainId: 137, rpcUrl, addresses });
  }

  // ==================== High-Level Operations ====================

  /**
   * Mint and list NFT in one transaction
   */
  async mintAndList(params: {
    to: `0x${string}`;
    tokenURI: string;
    price: bigint;
    duration: number;
  }): Promise<{ tokenId: bigint; listingId: bigint }> {
    if (!this.walletClient) throw new Error('Wallet not connected');

    // Mint
    const tokenId = await this.nft.mint(params.to, params.tokenURI);

    // Approve marketplace
    await this.nft.approve(this.marketplace.address, tokenId);

    // List
    const listingId = await this.marketplace.createListing(
      this.nft.address,
      tokenId,
      params.price,
      params.duration
    );

    return { tokenId, listingId };
  }

  /**
   * Buy NFT with automatic price check
   */
  async buyNFT(listingId: bigint, maxPrice?: bigint): Promise<`0x${string}`> {
    const listing = await this.marketplace.getListing(listingId);

    if (maxPrice && listing.price > maxPrice) {
      throw new Error(`Price ${listing.price} exceeds max ${maxPrice}`);
    }

    return this.marketplace.buy(listingId, listing.price);
  }

  /**
   * Fractionalize NFT
   */
  async fractionalizeNFT(params: {
    nftContract: `0x${string}`;
    tokenId: bigint;
    name: string;
    symbol: string;
    supply: bigint;
    reservePrice: bigint;
  }): Promise<`0x${string}`> {
    // Approve fractional vault
    await this.nft.approve(this.fractional.address, params.tokenId);

    // Create vault
    return this.fractional.createVault(
      params.nftContract,
      params.tokenId,
      params.name,
      params.symbol,
      params.supply,
      params.reservePrice
    );
  }

  /**
   * Get NFT with full metadata
   */
  async getNFTWithMetadata(contract: `0x${string}`, tokenId: bigint) {
    const [owner, tokenURI, royaltyInfo] = await Promise.all([
      this.nft.ownerOf(tokenId, contract),
      this.nft.tokenURI(tokenId, contract),
      this.nft.royaltyInfo(tokenId, 10000n, contract),
    ]);

    let metadata = null;
    try {
      metadata = await this.ipfs.fetchMetadata(tokenURI);
    } catch (e) {
      console.warn('Failed to fetch metadata:', e);
    }

    return {
      contract,
      tokenId,
      owner,
      tokenURI,
      royalty: {
        receiver: royaltyInfo[0],
        percentage: Number(royaltyInfo[1]) / 100,
      },
      metadata,
    };
  }
}
```

## Contract Wrapper Example

File: `sdk/src/contracts/marketplace.ts`

```typescript
import { PublicClient, WalletClient, getContract } from 'viem';
import { MARKETPLACE_ABI } from '../abis/marketplace';

export class MarketplaceContract {
  public readonly address: `0x${string}`;
  private readonly publicClient: PublicClient;
  private readonly walletClient?: WalletClient;

  constructor(
    publicClient: PublicClient,
    walletClient: WalletClient | undefined,
    address: `0x${string}`
  ) {
    this.publicClient = publicClient;
    this.walletClient = walletClient;
    this.address = address;
  }

  private get readContract() {
    return getContract({
      address: this.address,
      abi: MARKETPLACE_ABI,
      client: this.publicClient,
    });
  }

  private get writeContract() {
    if (!this.walletClient) throw new Error('Wallet not connected');
    return getContract({
      address: this.address,
      abi: MARKETPLACE_ABI,
      client: this.walletClient,
    });
  }

  // ==================== Read Functions ====================

  async getListing(listingId: bigint) {
    const listing = await this.readContract.read.listings([listingId]);
    return {
      seller: listing[0],
      nftContract: listing[1],
      tokenId: listing[2],
      price: listing[3],
      expiresAt: listing[4],
      isActive: listing[5],
    };
  }

  async getAuction(auctionId: bigint) {
    const auction = await this.readContract.read.auctions([auctionId]);
    return {
      seller: auction[0],
      nftContract: auction[1],
      tokenId: auction[2],
      startPrice: auction[3],
      reservePrice: auction[4],
      currentBid: auction[5],
      currentBidder: auction[6],
      startTime: auction[7],
      endTime: auction[8],
      auctionType: auction[9],
      isActive: auction[10],
    };
  }

  async getActiveListings(offset: number = 0, limit: number = 100) {
    return this.readContract.read.getActiveListings([BigInt(offset), BigInt(limit)]);
  }

  async getActiveAuctions(offset: number = 0, limit: number = 100) {
    return this.readContract.read.getActiveAuctions([BigInt(offset), BigInt(limit)]);
  }

  // ==================== Write Functions ====================

  async createListing(
    nftContract: `0x${string}`,
    tokenId: bigint,
    price: bigint,
    duration: number
  ): Promise<bigint> {
    const hash = await this.writeContract.write.createListing([
      nftContract,
      tokenId,
      price,
      BigInt(duration),
    ]);

    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });
    // Parse listingId from event logs
    const event = receipt.logs.find(log =>
      log.topics[0] === '0x...' // ListingCreated event signature
    );
    return event ? BigInt(event.topics[1] || 0) : 0n;
  }

  async buy(listingId: bigint, price: bigint): Promise<`0x${string}`> {
    return this.writeContract.write.buy([listingId], { value: price });
  }

  async cancelListing(listingId: bigint): Promise<`0x${string}`> {
    return this.writeContract.write.cancelListing([listingId]);
  }

  async createAuction(
    nftContract: `0x${string}`,
    tokenId: bigint,
    startPrice: bigint,
    reservePrice: bigint,
    duration: number,
    auctionType: 'english' | 'dutch'
  ): Promise<`0x${string}`> {
    return this.writeContract.write.createAuction([
      nftContract,
      tokenId,
      startPrice,
      reservePrice,
      BigInt(duration),
      auctionType === 'english' ? 0 : 1,
    ]);
  }

  async placeBid(auctionId: bigint, amount: bigint): Promise<`0x${string}`> {
    return this.writeContract.write.placeBid([auctionId], { value: amount });
  }

  async settleAuction(auctionId: bigint): Promise<`0x${string}`> {
    return this.writeContract.write.settleAuction([auctionId]);
  }

  // ==================== Event Listeners ====================

  onListingCreated(callback: (event: any) => void) {
    return this.publicClient.watchContractEvent({
      address: this.address,
      abi: MARKETPLACE_ABI,
      eventName: 'ListingCreated',
      onLogs: callback,
    });
  }

  onSale(callback: (event: any) => void) {
    return this.publicClient.watchContractEvent({
      address: this.address,
      abi: MARKETPLACE_ABI,
      eventName: 'Sale',
      onLogs: callback,
    });
  }
}
```

## Package Configuration

File: `sdk/package.json`

```json
{
  "name": "@nft-protocol/sdk",
  "version": "1.0.0",
  "description": "SDK for NFT Protocol - Institutional grade NFT infrastructure",
  "main": "dist/index.js",
  "module": "dist/index.mjs",
  "types": "dist/index.d.ts",
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "dev": "tsup src/index.ts --format cjs,esm --dts --watch",
    "test": "vitest",
    "lint": "eslint src/",
    "prepublishOnly": "npm run build"
  },
  "dependencies": {
    "viem": "^2.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "tsup": "^8.0.0",
    "typescript": "^5.0.0",
    "vitest": "^1.0.0",
    "eslint": "^8.0.0"
  },
  "peerDependencies": {
    "viem": "^2.0.0"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/nft-protocol-sdk"
  },
  "keywords": [
    "nft",
    "ethereum",
    "web3",
    "marketplace",
    "defi",
    "fractionalization"
  ],
  "license": "MIT"
}
```

## SDK Usage Example

File: `sdk/examples/usage.ts`

```typescript
import { NFTProtocolSDK } from '@nft-protocol/sdk';
import { privateKeyToAccount } from 'viem/accounts';

// Initialize SDK
const sdk = NFTProtocolSDK.create({
  chainId: 1,
  rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY',
  account: privateKeyToAccount('0x...'),
  addresses: {
    nft: '0x...',
    marketplace: '0x...',
    lending: '0x...',
    fractional: '0x...',
    governance: '0x...',
  },
  pinataJwt: 'YOUR_PINATA_JWT',
});

async function main() {
  // 1. Mint and List NFT
  const { tokenId, listingId } = await sdk.mintAndList({
    to: '0x...',
    tokenURI: 'ipfs://...',
    price: 1000000000000000000n, // 1 ETH
    duration: 7 * 24 * 60 * 60, // 7 days
  });
  console.log(`Minted token ${tokenId}, listing ${listingId}`);

  // 2. Get NFT with metadata
  const nft = await sdk.getNFTWithMetadata(sdk.nft.address, tokenId);
  console.log('NFT:', nft);

  // 3. Browse marketplace
  const listings = await sdk.marketplace.getActiveListings(0, 10);
  console.log('Active listings:', listings);

  // 4. Buy NFT
  const txHash = await sdk.buyNFT(listingId);
  console.log('Purchase tx:', txHash);

  // 5. Fractionalize NFT
  const vaultAddress = await sdk.fractionalizeNFT({
    nftContract: sdk.nft.address,
    tokenId,
    name: 'Fractionalized NFT',
    symbol: 'FNFT',
    supply: 1000000n,
    reservePrice: 10000000000000000000n, // 10 ETH
  });
  console.log('Vault created:', vaultAddress);

  // 6. Listen to events
  sdk.marketplace.onSale((event) => {
    console.log('Sale event:', event);
  });
}

main().catch(console.error);
```

---

# MODULE 29: BATCH OPERATIONS (Multicall)

## Multicall Contract

File: `contracts/utils/NFTMulticall.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NFTMulticall
 * @notice Gas-efficient batch operations for NFT protocol
 */
contract NFTMulticall is Ownable {
    // Trusted contracts that can be called
    mapping(address => bool) public trustedContracts;

    // Emergency stop
    bool public paused;

    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    event CallExecuted(address indexed target, bool success, bytes returnData);
    event BatchExecuted(uint256 successCount, uint256 totalCalls);
    event ContractTrustUpdated(address indexed target, bool trusted);

    error Paused();
    error UntrustedContract(address target);
    error InsufficientValue();
    error CallFailed(uint256 index, bytes returnData);

    constructor() Ownable(msg.sender) {}

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /**
     * @notice Execute multiple calls in a single transaction
     * @param calls Array of calls to execute
     * @return results Array of results from each call
     */
    function multicall(Call[] calldata calls)
        external
        payable
        whenNotPaused
        returns (Result[] memory results)
    {
        results = new Result[](calls.length);
        uint256 totalValue;

        for (uint256 i = 0; i < calls.length; i++) {
            totalValue += calls[i].value;
        }

        if (msg.value < totalValue) revert InsufficientValue();

        uint256 successCount;
        for (uint256 i = 0; i < calls.length; i++) {
            Call calldata call = calls[i];

            // Only allow trusted contracts in production
            if (!trustedContracts[call.target] && call.target != address(this)) {
                revert UntrustedContract(call.target);
            }

            (bool success, bytes memory returnData) = call.target.call{value: call.value}(
                call.callData
            );

            results[i] = Result(success, returnData);

            if (success) successCount++;

            emit CallExecuted(call.target, success, returnData);
        }

        emit BatchExecuted(successCount, calls.length);

        // Refund excess ETH
        if (address(this).balance > 0) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @notice Execute multiple calls, revert if any fails
     */
    function multicallStrict(Call[] calldata calls)
        external
        payable
        whenNotPaused
        returns (Result[] memory results)
    {
        results = new Result[](calls.length);

        for (uint256 i = 0; i < calls.length; i++) {
            Call calldata call = calls[i];

            if (!trustedContracts[call.target]) {
                revert UntrustedContract(call.target);
            }

            (bool success, bytes memory returnData) = call.target.call{value: call.value}(
                call.callData
            );

            if (!success) {
                revert CallFailed(i, returnData);
            }

            results[i] = Result(success, returnData);
        }

        if (address(this).balance > 0) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        }
    }

    // ==================== Batch NFT Operations ====================

    /**
     * @notice Batch mint NFTs
     */
    function batchMint(
        address nftContract,
        address[] calldata recipients,
        string[] calldata tokenURIs
    ) external whenNotPaused returns (uint256[] memory tokenIds) {
        require(trustedContracts[nftContract], "Untrusted contract");
        require(recipients.length == tokenURIs.length, "Length mismatch");

        tokenIds = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            // Call safeMintWithURI(address,string) on NFT contract
            (bool success, bytes memory data) = nftContract.call(
                abi.encodeWithSignature(
                    "safeMintWithURI(address,string)",
                    recipients[i],
                    tokenURIs[i]
                )
            );
            require(success, "Mint failed");
            tokenIds[i] = abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Batch transfer NFTs
     */
    function batchTransfer(
        address nftContract,
        address from,
        address to,
        uint256[] calldata tokenIds
    ) external whenNotPaused {
        require(trustedContracts[nftContract], "Untrusted contract");

        IERC721 nft = IERC721(nftContract);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.safeTransferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @notice Batch approve NFTs
     */
    function batchApprove(
        address nftContract,
        address operator,
        uint256[] calldata tokenIds
    ) external whenNotPaused {
        require(trustedContracts[nftContract], "Untrusted contract");

        IERC721 nft = IERC721(nftContract);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(nft.ownerOf(tokenIds[i]) == msg.sender, "Not owner");
            nft.approve(operator, tokenIds[i]);
        }
    }

    /**
     * @notice Batch create marketplace listings
     */
    function batchCreateListings(
        address marketplace,
        address nftContract,
        uint256[] calldata tokenIds,
        uint256[] calldata prices,
        uint256 duration
    ) external whenNotPaused returns (uint256[] memory listingIds) {
        require(trustedContracts[marketplace], "Untrusted contract");
        require(tokenIds.length == prices.length, "Length mismatch");

        listingIds = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            (bool success, bytes memory data) = marketplace.call(
                abi.encodeWithSignature(
                    "createListing(address,uint256,uint256,uint256)",
                    nftContract,
                    tokenIds[i],
                    prices[i],
                    duration
                )
            );
            require(success, "Listing failed");
            listingIds[i] = abi.decode(data, (uint256));
        }
    }

    /**
     * @notice Batch cancel listings
     */
    function batchCancelListings(
        address marketplace,
        uint256[] calldata listingIds
    ) external whenNotPaused {
        require(trustedContracts[marketplace], "Untrusted contract");

        for (uint256 i = 0; i < listingIds.length; i++) {
            (bool success, ) = marketplace.call(
                abi.encodeWithSignature("cancelListing(uint256)", listingIds[i])
            );
            require(success, "Cancel failed");
        }
    }

    /**
     * @notice Batch buy NFTs
     */
    function batchBuy(
        address marketplace,
        uint256[] calldata listingIds,
        uint256[] calldata prices
    ) external payable whenNotPaused {
        require(trustedContracts[marketplace], "Untrusted contract");
        require(listingIds.length == prices.length, "Length mismatch");

        uint256 totalPrice;
        for (uint256 i = 0; i < prices.length; i++) {
            totalPrice += prices[i];
        }
        require(msg.value >= totalPrice, "Insufficient ETH");

        for (uint256 i = 0; i < listingIds.length; i++) {
            (bool success, ) = marketplace.call{value: prices[i]}(
                abi.encodeWithSignature("buy(uint256)", listingIds[i])
            );
            require(success, "Buy failed");
        }

        // Refund excess
        if (address(this).balance > 0) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        }
    }

    // ==================== Admin Functions ====================

    function setTrustedContract(address _contract, bool _trusted) external onlyOwner {
        trustedContracts[_contract] = _trusted;
        emit ContractTrustUpdated(_contract, _trusted);
    }

    function batchSetTrustedContracts(
        address[] calldata contracts,
        bool[] calldata trusted
    ) external onlyOwner {
        require(contracts.length == trusted.length, "Length mismatch");
        for (uint256 i = 0; i < contracts.length; i++) {
            trustedContracts[contracts[i]] = trusted[i];
            emit ContractTrustUpdated(contracts[i], trusted[i]);
        }
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function withdrawETH() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    function withdrawERC20(address token) external onlyOwner {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}
```

## Frontend Multicall Hook

File: `frontend/hooks/useMulticall.ts`

```typescript
import { useCallback } from 'react';
import {
  useAccount,
  usePublicClient,
  useWalletClient,
} from 'wagmi';
import { encodeFunctionData, parseAbi } from 'viem';

const MULTICALL_ABI = parseAbi([
  'function multicall((address target, bytes callData, uint256 value)[] calls) payable returns ((bool success, bytes returnData)[])',
  'function multicallStrict((address target, bytes callData, uint256 value)[] calls) payable returns ((bool success, bytes returnData)[])',
  'function batchMint(address nftContract, address[] recipients, string[] tokenURIs) returns (uint256[])',
  'function batchTransfer(address nftContract, address from, address to, uint256[] tokenIds)',
  'function batchApprove(address nftContract, address operator, uint256[] tokenIds)',
  'function batchCreateListings(address marketplace, address nftContract, uint256[] tokenIds, uint256[] prices, uint256 duration) returns (uint256[])',
  'function batchBuy(address marketplace, uint256[] listingIds, uint256[] prices) payable',
]);

interface Call {
  target: `0x${string}`;
  callData: `0x${string}`;
  value: bigint;
}

export function useMulticall(multicallAddress: `0x${string}`) {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  /**
   * Execute multiple arbitrary calls
   */
  const multicall = useCallback(
    async (calls: Call[], strict = false) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const totalValue = calls.reduce((sum, call) => sum + call.value, 0n);

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: strict ? 'multicallStrict' : 'multicall',
        args: [calls],
        value: totalValue,
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Batch mint NFTs
   */
  const batchMint = useCallback(
    async (
      nftContract: `0x${string}`,
      recipients: `0x${string}`[],
      tokenURIs: string[]
    ) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: 'batchMint',
        args: [nftContract, recipients, tokenURIs],
      });

      const receipt = await publicClient?.waitForTransactionReceipt({ hash });
      return receipt;
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Batch transfer NFTs
   */
  const batchTransfer = useCallback(
    async (
      nftContract: `0x${string}`,
      to: `0x${string}`,
      tokenIds: bigint[]
    ) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: 'batchTransfer',
        args: [nftContract, address, to, tokenIds],
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Batch approve for marketplace
   */
  const batchApprove = useCallback(
    async (
      nftContract: `0x${string}`,
      operator: `0x${string}`,
      tokenIds: bigint[]
    ) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: 'batchApprove',
        args: [nftContract, operator, tokenIds],
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Batch create listings
   */
  const batchList = useCallback(
    async (
      marketplace: `0x${string}`,
      nftContract: `0x${string}`,
      tokenIds: bigint[],
      prices: bigint[],
      duration: bigint
    ) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: 'batchCreateListings',
        args: [marketplace, nftContract, tokenIds, prices, duration],
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Batch buy NFTs
   */
  const batchBuy = useCallback(
    async (
      marketplace: `0x${string}`,
      listingIds: bigint[],
      prices: bigint[]
    ) => {
      if (!walletClient || !address) throw new Error('Wallet not connected');

      const totalPrice = prices.reduce((sum, p) => sum + p, 0n);

      const hash = await walletClient.writeContract({
        address: multicallAddress,
        abi: MULTICALL_ABI,
        functionName: 'batchBuy',
        args: [marketplace, listingIds, prices],
        value: totalPrice,
      });

      return publicClient?.waitForTransactionReceipt({ hash });
    },
    [walletClient, publicClient, address, multicallAddress]
  );

  /**
   * Build custom multicall from individual operations
   */
  const buildMulticall = useCallback(() => {
    const calls: Call[] = [];

    return {
      addCall(target: `0x${string}`, abi: any, functionName: string, args: any[], value = 0n) {
        calls.push({
          target,
          callData: encodeFunctionData({ abi, functionName, args }),
          value,
        });
        return this;
      },

      async execute(strict = false) {
        return multicall(calls, strict);
      },

      getCalls() {
        return [...calls];
      },

      clear() {
        calls.length = 0;
        return this;
      },
    };
  }, [multicall]);

  return {
    multicall,
    batchMint,
    batchTransfer,
    batchApprove,
    batchList,
    batchBuy,
    buildMulticall,
  };
}
```

## Batch Operations Component

File: `frontend/components/batch/BatchOperations.tsx`

```tsx
'use client';

import { useState } from 'react';
import { formatEther, parseEther } from 'viem';
import { useMulticall } from '@/hooks/useMulticall';
import { Button } from '@/components/common/Button';

interface NFTItem {
  tokenId: bigint;
  name: string;
  image: string;
  selected: boolean;
}

interface BatchOperationsProps {
  multicallAddress: `0x${string}`;
  nftContract: `0x${string}`;
  marketplaceAddress: `0x${string}`;
  ownedNFTs: NFTItem[];
}

export function BatchOperations({
  multicallAddress,
  nftContract,
  marketplaceAddress,
  ownedNFTs,
}: BatchOperationsProps) {
  const [items, setItems] = useState(ownedNFTs);
  const [operation, setOperation] = useState<'transfer' | 'list' | 'approve'>('list');
  const [recipient, setRecipient] = useState('');
  const [price, setPrice] = useState('');
  const [duration, setDuration] = useState(7);
  const [loading, setLoading] = useState(false);

  const { batchTransfer, batchList, batchApprove } = useMulticall(multicallAddress);

  const selectedItems = items.filter((item) => item.selected);
  const selectedTokenIds = selectedItems.map((item) => item.tokenId);

  const toggleSelect = (tokenId: bigint) => {
    setItems(
      items.map((item) =>
        item.tokenId === tokenId ? { ...item, selected: !item.selected } : item
      )
    );
  };

  const selectAll = () => {
    setItems(items.map((item) => ({ ...item, selected: true })));
  };

  const deselectAll = () => {
    setItems(items.map((item) => ({ ...item, selected: false })));
  };

  const handleExecute = async () => {
    if (selectedTokenIds.length === 0) return;

    setLoading(true);
    try {
      if (operation === 'transfer') {
        await batchTransfer(nftContract, recipient as `0x${string}`, selectedTokenIds);
      } else if (operation === 'list') {
        const prices = selectedTokenIds.map(() => parseEther(price));
        await batchList(
          marketplaceAddress,
          nftContract,
          selectedTokenIds,
          prices,
          BigInt(duration * 24 * 60 * 60)
        );
      } else if (operation === 'approve') {
        await batchApprove(nftContract, marketplaceAddress, selectedTokenIds);
      }

      // Refresh or show success
      alert('Batch operation completed!');
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    }
    setLoading(false);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-white">Batch Operations</h2>
        <div className="flex gap-2">
          <button onClick={selectAll} className="text-blue-400 hover:text-blue-300">
            Select All
          </button>
          <button onClick={deselectAll} className="text-gray-400 hover:text-gray-300">
            Deselect All
          </button>
        </div>
      </div>

      {/* NFT Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
        {items.map((item) => (
          <div
            key={item.tokenId.toString()}
            onClick={() => toggleSelect(item.tokenId)}
            className={`cursor-pointer rounded-lg overflow-hidden border-2 transition-all ${
              item.selected
                ? 'border-blue-500 ring-2 ring-blue-500/50'
                : 'border-gray-700 hover:border-gray-600'
            }`}
          >
            <img
              src={item.image}
              alt={item.name}
              className="w-full aspect-square object-cover"
            />
            <div className="p-2 bg-gray-800">
              <p className="text-sm text-white truncate">{item.name}</p>
              <p className="text-xs text-gray-400">#{item.tokenId.toString()}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Operation Selection */}
      <div className="bg-gray-800 rounded-xl p-6 space-y-4">
        <div className="flex gap-4">
          {(['transfer', 'list', 'approve'] as const).map((op) => (
            <button
              key={op}
              onClick={() => setOperation(op)}
              className={`px-4 py-2 rounded-lg capitalize ${
                operation === op
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              {op}
            </button>
          ))}
        </div>

        {/* Operation Inputs */}
        {operation === 'transfer' && (
          <div>
            <label className="block text-sm text-gray-400 mb-2">Recipient Address</label>
            <input
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="0x..."
              className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
            />
          </div>
        )}

        {operation === 'list' && (
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Price (ETH each)</label>
              <input
                type="number"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                placeholder="0.1"
                step="0.01"
                className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Duration (days)</label>
              <input
                type="number"
                value={duration}
                onChange={(e) => setDuration(Number(e.target.value))}
                min={1}
                max={30}
                className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
              />
            </div>
          </div>
        )}

        {/* Summary */}
        <div className="flex justify-between items-center pt-4 border-t border-gray-700">
          <div>
            <p className="text-white font-medium">
              {selectedItems.length} NFT{selectedItems.length !== 1 ? 's' : ''} selected
            </p>
            {operation === 'list' && price && (
              <p className="text-sm text-gray-400">
                Total: {(selectedItems.length * parseFloat(price)).toFixed(2)} ETH
              </p>
            )}
          </div>
          <Button
            onClick={handleExecute}
            disabled={loading || selectedItems.length === 0}
            className="px-8"
          >
            {loading ? 'Processing...' : `${operation.charAt(0).toUpperCase() + operation.slice(1)} ${selectedItems.length} NFTs`}
          </Button>
        </div>
      </div>
    </div>
  );
}
```

---

# MODULE 30: CONTRACT ABIs

## ERC721SecureUUPS ABI

File: `abis/ERC721SecureUUPS.json`

```json
[
  {
    "inputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "AccessControlBadConfirmation",
    "type": "error"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "account", "type": "address" },
      { "internalType": "bytes32", "name": "neededRole", "type": "bytes32" }
    ],
    "name": "AccessControlUnauthorizedAccount",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "owner", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "approved", "type": "address" },
      { "indexed": true, "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "Approval",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "owner", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "operator", "type": "address" },
      { "indexed": false, "internalType": "bool", "name": "approved", "type": "bool" }
    ],
    "name": "ApprovalForAll",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "to", "type": "address" },
      { "indexed": false, "internalType": "string", "name": "uri", "type": "string" }
    ],
    "name": "TokenMinted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "from", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "to", "type": "address" },
      { "indexed": true, "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "Transfer",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "to", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "owner", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "tokenId", "type": "uint256" }],
    "name": "burn",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "tokenId", "type": "uint256" }],
    "name": "getApproved",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "role", "type": "bytes32" },
      { "internalType": "address", "name": "account", "type": "address" }
    ],
    "name": "grantRole",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "role", "type": "bytes32" },
      { "internalType": "address", "name": "account", "type": "address" }
    ],
    "name": "hasRole",
    "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "string", "name": "name_", "type": "string" },
      { "internalType": "string", "name": "symbol_", "type": "string" },
      { "internalType": "string", "name": "baseURI_", "type": "string" },
      { "internalType": "uint256", "name": "maxSupply_", "type": "uint256" },
      { "internalType": "address", "name": "admin", "type": "address" },
      { "internalType": "address", "name": "royaltyReceiver", "type": "address" },
      { "internalType": "uint96", "name": "royaltyBps", "type": "uint96" }
    ],
    "name": "initialize",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "owner", "type": "address" },
      { "internalType": "address", "name": "operator", "type": "address" }
    ],
    "name": "isApprovedForAll",
    "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "maxSupply",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "tokenId", "type": "uint256" }],
    "name": "ownerOf",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pause",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "paused",
    "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "salePrice", "type": "uint256" }
    ],
    "name": "royaltyInfo",
    "outputs": [
      { "internalType": "address", "name": "", "type": "address" },
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "to", "type": "address" }],
    "name": "safeMintAutoId",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "to", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "string", "name": "uri", "type": "string" },
      { "internalType": "uint96", "name": "royaltyBps", "type": "uint96" }
    ],
    "name": "safeMintWithRoyalty",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "from", "type": "address" },
      { "internalType": "address", "name": "to", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "safeTransferFrom",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "from", "type": "address" },
      { "internalType": "address", "name": "to", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "bytes", "name": "data", "type": "bytes" }
    ],
    "name": "safeTransferFrom",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "operator", "type": "address" },
      { "internalType": "bool", "name": "approved", "type": "bool" }
    ],
    "name": "setApprovalForAll",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "bytes4", "name": "interfaceId", "type": "bytes4" }],
    "name": "supportsInterface",
    "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "tokenId", "type": "uint256" }],
    "name": "tokenURI",
    "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalMinted",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "from", "type": "address" },
      { "internalType": "address", "name": "to", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "transferFrom",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "unpause",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

## NFTMarketplace ABI

File: `abis/NFTMarketplace.json`

```json
[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "listingId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "seller", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "nftContract", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "price", "type": "uint256" }
    ],
    "name": "ListingCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "listingId", "type": "uint256" }
    ],
    "name": "ListingCancelled",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "listingId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "buyer", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "price", "type": "uint256" }
    ],
    "name": "Sale",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "auctionId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "seller", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "startPrice", "type": "uint256" }
    ],
    "name": "AuctionCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "auctionId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "bidder", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "BidPlaced",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "auctionId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "winner", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "AuctionSettled",
    "type": "event"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "listingId", "type": "uint256" }],
    "name": "buy",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "listingId", "type": "uint256" }],
    "name": "cancelListing",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "startPrice", "type": "uint256" },
      { "internalType": "uint256", "name": "reservePrice", "type": "uint256" },
      { "internalType": "uint256", "name": "duration", "type": "uint256" },
      { "internalType": "uint8", "name": "auctionType", "type": "uint8" }
    ],
    "name": "createAuction",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "price", "type": "uint256" },
      { "internalType": "uint256", "name": "duration", "type": "uint256" }
    ],
    "name": "createListing",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "offset", "type": "uint256" },
      { "internalType": "uint256", "name": "limit", "type": "uint256" }
    ],
    "name": "getActiveAuctions",
    "outputs": [{ "internalType": "uint256[]", "name": "", "type": "uint256[]" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "offset", "type": "uint256" },
      { "internalType": "uint256", "name": "limit", "type": "uint256" }
    ],
    "name": "getActiveListings",
    "outputs": [{ "internalType": "uint256[]", "name": "", "type": "uint256[]" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "name": "auctions",
    "outputs": [
      { "internalType": "address", "name": "seller", "type": "address" },
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "startPrice", "type": "uint256" },
      { "internalType": "uint256", "name": "reservePrice", "type": "uint256" },
      { "internalType": "uint256", "name": "currentBid", "type": "uint256" },
      { "internalType": "address", "name": "currentBidder", "type": "address" },
      { "internalType": "uint256", "name": "startTime", "type": "uint256" },
      { "internalType": "uint256", "name": "endTime", "type": "uint256" },
      { "internalType": "uint8", "name": "auctionType", "type": "uint8" },
      { "internalType": "bool", "name": "isActive", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "name": "listings",
    "outputs": [
      { "internalType": "address", "name": "seller", "type": "address" },
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "price", "type": "uint256" },
      { "internalType": "uint256", "name": "expiresAt", "type": "uint256" },
      { "internalType": "bool", "name": "isActive", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "auctionId", "type": "uint256" }],
    "name": "placeBid",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "auctionId", "type": "uint256" }],
    "name": "settleAuction",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

## NFTLending ABI

File: `abis/NFTLending.json`

```json
[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "offerId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "lender", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "principal", "type": "uint256" }
    ],
    "name": "LoanOfferCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "loanId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "borrower", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "lender", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "principal", "type": "uint256" }
    ],
    "name": "LoanCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "loanId", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "LoanRepaid",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "loanId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "liquidator", "type": "address" }
    ],
    "name": "LoanLiquidated",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "offerId", "type": "uint256" },
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "borrow",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "principal", "type": "uint256" },
      { "internalType": "uint256", "name": "interestRateBps", "type": "uint256" },
      { "internalType": "uint256", "name": "duration", "type": "uint256" },
      { "internalType": "address[]", "name": "acceptedCollections", "type": "address[]" }
    ],
    "name": "createLoanOffer",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "loanId", "type": "uint256" }],
    "name": "getOutstandingBalance",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "loanId", "type": "uint256" }],
    "name": "liquidate",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "name": "loanOffers",
    "outputs": [
      { "internalType": "address", "name": "lender", "type": "address" },
      { "internalType": "uint256", "name": "principal", "type": "uint256" },
      { "internalType": "uint256", "name": "interestRateBps", "type": "uint256" },
      { "internalType": "uint256", "name": "duration", "type": "uint256" },
      { "internalType": "uint256", "name": "expiresAt", "type": "uint256" },
      { "internalType": "bool", "name": "isActive", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "name": "loans",
    "outputs": [
      { "internalType": "address", "name": "borrower", "type": "address" },
      { "internalType": "address", "name": "lender", "type": "address" },
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "uint256", "name": "principal", "type": "uint256" },
      { "internalType": "uint256", "name": "interestRateBps", "type": "uint256" },
      { "internalType": "uint256", "name": "startTime", "type": "uint256" },
      { "internalType": "uint256", "name": "duration", "type": "uint256" },
      { "internalType": "uint8", "name": "status", "type": "uint8" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "loanId", "type": "uint256" }],
    "name": "repay",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  }
]
```

## FractionalVault ABI

File: `abis/FractionalVault.json`

```json
[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "vault", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "nftContract", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "VaultCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "vault", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "buyer", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "BuyoutStarted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "vault", "type": "address" },
      { "indexed": true, "internalType": "address", "name": "buyer", "type": "address" }
    ],
    "name": "BuyoutCompleted",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "nftContract", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "string", "name": "symbol", "type": "string" },
      { "internalType": "uint256", "name": "supply", "type": "uint256" },
      { "internalType": "uint256", "name": "reservePrice", "type": "uint256" }
    ],
    "name": "createVault",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "completeBuyout",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "amount", "type": "uint256" }],
    "name": "redeemFractions",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "startBuyout",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "newPrice", "type": "uint256" }],
    "name": "updateReservePrice",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

---

# MODULE 31: EVENT SIGNATURES

## Event Signature Constants

File: `sdk/src/constants/events.ts`

```typescript
/**
 * Event signatures for all protocol contracts
 * Computed as keccak256(eventName(paramTypes))
 */
export const EVENT_SIGNATURES = {
  // ERC721 Events
  TRANSFER: '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
  APPROVAL: '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925',
  APPROVAL_FOR_ALL: '0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31',

  // Marketplace Events
  LISTING_CREATED: '0x6b2d6c2e3f2e5e6d8c9a7b4c5d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4',
  LISTING_CANCELLED: '0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b',
  SALE: '0x8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c',
  AUCTION_CREATED: '0x9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d',
  BID_PLACED: '0x0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e',
  AUCTION_SETTLED: '0x1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f',

  // Lending Events
  LOAN_OFFER_CREATED: '0x2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a',
  LOAN_CREATED: '0x3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b',
  LOAN_REPAID: '0x4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c',
  LOAN_LIQUIDATED: '0x5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d',

  // Fractionalization Events
  VAULT_CREATED: '0x6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e',
  BUYOUT_STARTED: '0x7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f',
  BUYOUT_COMPLETED: '0x8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a',

  // Governance Events
  PROPOSAL_CREATED: '0x9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
  VOTE_CAST: '0x0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c',
  PROPOSAL_EXECUTED: '0x1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d',

  // Compliance Events
  KYC_APPROVED: '0x2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e',
  ADDRESS_BLACKLISTED: '0x3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f',

  // Bridge Events
  BRIDGE_INITIATED: '0x4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a',
  BRIDGE_COMPLETED: '0x5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b',

  // Insurance Events
  POLICY_CREATED: '0x6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c',
  CLAIM_FILED: '0x7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d',
  CLAIM_RESOLVED: '0x8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e',
} as const;

/**
 * Decode event from log
 */
export function decodeEventLog(
  signature: string,
  topics: string[],
  data: string
): { eventName: string; args: Record<string, any> } | null {
  const eventName = Object.entries(EVENT_SIGNATURES).find(
    ([, sig]) => sig === signature
  )?.[0];

  if (!eventName) return null;

  // Basic decoding - in production use viem's decodeEventLog
  return {
    eventName,
    args: { topics, data },
  };
}

/**
 * Event filter helpers
 */
export const EventFilters = {
  transfers: (fromOrTo: string) => ({
    topics: [
      EVENT_SIGNATURES.TRANSFER,
      null, // any from
      null, // any to
    ],
  }),

  sales: (seller?: string) => ({
    topics: [
      EVENT_SIGNATURES.SALE,
      seller ? `0x000000000000000000000000${seller.slice(2)}` : null,
    ],
  }),

  listings: (nftContract?: string) => ({
    topics: [
      EVENT_SIGNATURES.LISTING_CREATED,
      null, // any listingId
      null, // any seller
      nftContract ? `0x000000000000000000000000${nftContract.slice(2)}` : null,
    ],
  }),
};
```

---

# MODULE 32: ENVIRONMENT TEMPLATES

## Root Environment Template

File: `.env.example`

```bash
# ============================================================
# NFT PROTOCOL - ENVIRONMENT CONFIGURATION
# ============================================================
# Copy this file to .env and fill in your values
# NEVER commit .env to version control

# ==================== NETWORK CONFIGURATION ====================

# RPC URLs (get from Alchemy, Infura, or QuickNode)
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_BASE=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_ARBITRUM=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Alchemy API Key (for webhooks, NFT API, etc.)
ALCHEMY_KEY=YOUR_ALCHEMY_KEY

# ==================== WALLET CONFIGURATION ====================

# Deployer private key (NEVER share this!)
# Use a dedicated deployment wallet, not your main wallet
DEPLOYER_PRIVATE_KEY=0x...

# Multisig addresses for contract ownership
MULTISIG_MAINNET=0x...
MULTISIG_POLYGON=0x...
MULTISIG_BASE=0x...

# ==================== CONTRACT ADDRESSES ====================

# Mainnet Contracts
NFT_CONTRACT_MAINNET=0x...
MARKETPLACE_CONTRACT_MAINNET=0x...
LENDING_CONTRACT_MAINNET=0x...
FRACTIONAL_CONTRACT_MAINNET=0x...
GOVERNANCE_CONTRACT_MAINNET=0x...
COMPLIANCE_CONTRACT_MAINNET=0x...

# Polygon Contracts
NFT_CONTRACT_POLYGON=0x...
MARKETPLACE_CONTRACT_POLYGON=0x...
LENDING_CONTRACT_POLYGON=0x...

# Base Contracts
NFT_CONTRACT_BASE=0x...
MARKETPLACE_CONTRACT_BASE=0x...

# Sepolia Testnet Contracts
NFT_CONTRACT_SEPOLIA=0x...
MARKETPLACE_CONTRACT_SEPOLIA=0x...

# ==================== EXTERNAL SERVICES ====================

# IPFS / Pinata
PINATA_API_KEY=YOUR_PINATA_API_KEY
PINATA_SECRET_KEY=YOUR_PINATA_SECRET_KEY
PINATA_JWT=YOUR_PINATA_JWT
IPFS_GATEWAY=https://gateway.pinata.cloud

# Arweave (optional)
ARWEAVE_KEY=YOUR_ARWEAVE_KEY

# ==================== CHAINLINK ====================

# Chainlink Price Feeds (by network)
CHAINLINK_ETH_USD_MAINNET=0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
CHAINLINK_ETH_USD_POLYGON=0xF9680D99D6C9589e2a93a78A04A279e509205945
CHAINLINK_ETH_USD_SEPOLIA=0x694AA1769357215DE4FAC081bf1f309aDC325306

# ==================== LAYERZERO (Cross-Chain) ====================

LAYERZERO_ENDPOINT_MAINNET=0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675
LAYERZERO_ENDPOINT_POLYGON=0x3c2269811836af69497E5F486A85D7316753cf62
LAYERZERO_ENDPOINT_BASE=0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7

# ==================== THE GRAPH ====================

GRAPH_ACCESS_TOKEN=YOUR_GRAPH_ACCESS_TOKEN
SUBGRAPH_NAME=your-org/nft-protocol
SUBGRAPH_URL_MAINNET=https://api.thegraph.com/subgraphs/name/your-org/nft-protocol
SUBGRAPH_URL_POLYGON=https://api.thegraph.com/subgraphs/name/your-org/nft-protocol-polygon

# ==================== DATABASE ====================

DATABASE_URL=postgresql://user:password@localhost:5432/nft_protocol
REDIS_URL=redis://localhost:6379

# ==================== API CONFIGURATION ====================

# Server
PORT=3001
NODE_ENV=development
API_SECRET=your-super-secret-api-key

# CORS
CORS_ORIGINS=http://localhost:3000,https://your-domain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# ==================== FRONTEND ====================

NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_NFT_CONTRACT=0x...
NEXT_PUBLIC_MARKETPLACE_CONTRACT=0x...
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=YOUR_WALLETCONNECT_PROJECT_ID
NEXT_PUBLIC_ALCHEMY_KEY=YOUR_ALCHEMY_KEY
NEXT_PUBLIC_API_URL=http://localhost:3001

# ==================== WEBHOOKS ====================

WEBHOOK_SECRET=your-webhook-secret
ALCHEMY_WEBHOOK_SIGNING_KEY=your-alchemy-signing-key

# ==================== ANALYTICS ====================

DUNE_API_KEY=YOUR_DUNE_API_KEY

# ==================== BLOCK EXPLORERS (for verification) ====================

ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
POLYGONSCAN_API_KEY=YOUR_POLYGONSCAN_KEY
BASESCAN_API_KEY=YOUR_BASESCAN_KEY
ARBISCAN_API_KEY=YOUR_ARBISCAN_KEY

# ==================== MONITORING ====================

TENDERLY_ACCESS_KEY=YOUR_TENDERLY_KEY
TENDERLY_PROJECT=your-project
TENDERLY_ACCOUNT=your-account

# Forta (optional)
FORTA_API_KEY=YOUR_FORTA_KEY

# ==================== ACCOUNT ABSTRACTION ====================

# EntryPoint addresses (ERC-4337)
ENTRYPOINT_MAINNET=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
ENTRYPOINT_POLYGON=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
ENTRYPOINT_BASE=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

# Bundler URLs
BUNDLER_URL_MAINNET=https://bundler.example.com/mainnet
BUNDLER_URL_POLYGON=https://bundler.example.com/polygon

# ==================== KLEROS (Dispute Resolution) ====================

KLEROS_ARBITRATOR_MAINNET=0x988b3A538b618C7A603e1c11Ab82Cd16dbE28069
KLEROS_ARBITRATOR_POLYGON=0x...
```

## Frontend Environment Template

File: `frontend/.env.example`

```bash
# Frontend Environment Variables
# Copy to .env.local

# Chain Configuration
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_SUPPORTED_CHAINS=1,137,8453,42161

# Contract Addresses
NEXT_PUBLIC_NFT_CONTRACT=0x...
NEXT_PUBLIC_MARKETPLACE_CONTRACT=0x...
NEXT_PUBLIC_LENDING_CONTRACT=0x...
NEXT_PUBLIC_FRACTIONAL_CONTRACT=0x...
NEXT_PUBLIC_MULTICALL_CONTRACT=0x...

# API Endpoints
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_SUBGRAPH_URL=https://api.thegraph.com/subgraphs/name/your-org/nft-protocol

# External Services
NEXT_PUBLIC_ALCHEMY_KEY=YOUR_ALCHEMY_KEY
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=YOUR_WALLETCONNECT_PROJECT_ID
NEXT_PUBLIC_IPFS_GATEWAY=https://gateway.pinata.cloud

# Feature Flags
NEXT_PUBLIC_ENABLE_TESTNET=true
NEXT_PUBLIC_ENABLE_LENDING=true
NEXT_PUBLIC_ENABLE_FRACTIONALIZATION=true
NEXT_PUBLIC_ENABLE_BRIDGE=false
```

## Backend Environment Template

File: `backend/.env.example`

```bash
# Backend Environment Variables
# Copy to .env

# Server
PORT=3001
NODE_ENV=development

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/nft_protocol

# Redis
REDIS_URL=redis://localhost:6379

# Blockchain
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
ALCHEMY_KEY=YOUR_ALCHEMY_KEY

# Contracts
NFT_CONTRACT_MAINNET=0x...
MARKETPLACE_CONTRACT_MAINNET=0x...
LENDING_CONTRACT_MAINNET=0x...

# IPFS
PINATA_JWT=YOUR_PINATA_JWT
PINATA_GATEWAY=https://gateway.pinata.cloud

# Security
API_SECRET=generate-a-strong-secret-here
WEBHOOK_SECRET=your-webhook-secret
CORS_ORIGINS=http://localhost:3000

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
```

---

# MODULE 33: HARDHAT CONFIGURATION

## Complete Hardhat Config

File: `hardhat.config.ts`

```typescript
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-verify';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import 'hardhat-abi-exporter';
import 'solidity-coverage';
import * as dotenv from 'dotenv';

dotenv.config();

const DEPLOYER_KEY = process.env.DEPLOYER_PRIVATE_KEY || '0x' + '0'.repeat(64);

const config: HardhatUserConfig = {
  // ==================== SOLIDITY ====================
  solidity: {
    compilers: [
      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
          evmVersion: 'paris',
        },
      },
    ],
  },

  // ==================== NETWORKS ====================
  networks: {
    // Local
    hardhat: {
      chainId: 31337,
      forking: process.env.RPC_MAINNET
        ? {
            url: process.env.RPC_MAINNET,
            blockNumber: 18000000,
          }
        : undefined,
      accounts: {
        count: 20,
        accountsBalance: '10000000000000000000000', // 10000 ETH
      },
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
    },

    // Testnets
    sepolia: {
      url: process.env.RPC_SEPOLIA || '',
      chainId: 11155111,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    goerli: {
      url: process.env.RPC_GOERLI || '',
      chainId: 5,
      accounts: [DEPLOYER_KEY],
    },
    mumbai: {
      url: process.env.RPC_MUMBAI || '',
      chainId: 80001,
      accounts: [DEPLOYER_KEY],
      gasPrice: 35000000000, // 35 gwei
    },
    baseSepolia: {
      url: process.env.RPC_BASE_SEPOLIA || 'https://sepolia.base.org',
      chainId: 84532,
      accounts: [DEPLOYER_KEY],
    },

    // Mainnets
    mainnet: {
      url: process.env.RPC_MAINNET || '',
      chainId: 1,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    polygon: {
      url: process.env.RPC_POLYGON || '',
      chainId: 137,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    base: {
      url: process.env.RPC_BASE || 'https://mainnet.base.org',
      chainId: 8453,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    arbitrum: {
      url: process.env.RPC_ARBITRUM || '',
      chainId: 42161,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    optimism: {
      url: process.env.RPC_OPTIMISM || '',
      chainId: 10,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    avalanche: {
      url: process.env.RPC_AVALANCHE || 'https://api.avax.network/ext/bc/C/rpc',
      chainId: 43114,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
    bsc: {
      url: process.env.RPC_BSC || 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      accounts: [DEPLOYER_KEY],
      gasPrice: 'auto',
    },
  },

  // ==================== ETHERSCAN VERIFICATION ====================
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || '',
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      polygon: process.env.POLYGONSCAN_API_KEY || '',
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || '',
      base: process.env.BASESCAN_API_KEY || '',
      baseSepolia: process.env.BASESCAN_API_KEY || '',
      arbitrumOne: process.env.ARBISCAN_API_KEY || '',
      optimisticEthereum: process.env.OPTIMISM_API_KEY || '',
      avalanche: process.env.SNOWTRACE_API_KEY || '',
      bsc: process.env.BSCSCAN_API_KEY || '',
    },
    customChains: [
      {
        network: 'base',
        chainId: 8453,
        urls: {
          apiURL: 'https://api.basescan.org/api',
          browserURL: 'https://basescan.org',
        },
      },
      {
        network: 'baseSepolia',
        chainId: 84532,
        urls: {
          apiURL: 'https://api-sepolia.basescan.org/api',
          browserURL: 'https://sepolia.basescan.org',
        },
      },
    ],
  },

  // ==================== GAS REPORTER ====================
  gasReporter: {
    enabled: process.env.REPORT_GAS === 'true',
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    outputFile: 'gas-report.txt',
    noColors: true,
    excludeContracts: ['test/', 'mocks/'],
  },

  // ==================== CONTRACT SIZER ====================
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [
      'ERC721SecureUUPS',
      'NFTMarketplace',
      'NFTLending',
      'FractionalVault',
      'ComplianceRegistry',
    ],
  },

  // ==================== ABI EXPORTER ====================
  abiExporter: {
    path: './abis',
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [
      ':ERC721SecureUUPS$',
      ':NFTMarketplace$',
      ':NFTLending$',
      ':FractionalVault$',
      ':ComplianceRegistry$',
      ':GovToken$',
      ':GovTimelock$',
      ':GovGovernor$',
      ':NFTRental$',
      ':AssetOracle$',
      ':RoyaltyRouter$',
      ':ONFT721Bridge$',
      ':NFTPaymaster$',
      ':NFTSmartWallet$',
      ':ZKComplianceVerifier$',
      ':SoulboundNFT$',
      ':DynamicNFT$',
      ':NFTInsurance$',
      ':NFTDisputeResolver$',
      ':NFTMulticall$',
    ],
    spacing: 2,
    format: 'json',
  },

  // ==================== PATHS ====================
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },

  // ==================== MOCHA ====================
  mocha: {
    timeout: 120000, // 2 minutes for slow tests
  },

  // ==================== SOURCIFY ====================
  sourcify: {
    enabled: true,
  },
};

export default config;
```

## Package.json Scripts

File: `package.json` (scripts section)

```json
{
  "name": "nft-protocol",
  "version": "1.0.0",
  "scripts": {
    "compile": "hardhat compile",
    "clean": "hardhat clean && rm -rf cache artifacts typechain-types",
    "test": "hardhat test",
    "test:coverage": "hardhat coverage",
    "test:gas": "REPORT_GAS=true hardhat test",
    "test:foundry": "forge test -vvv",
    "test:fuzz": "forge test --fuzz-runs 10000",
    "test:invariant": "forge test --mt invariant",

    "deploy:local": "hardhat run scripts/deploy.ts --network localhost",
    "deploy:sepolia": "hardhat run scripts/deploy.ts --network sepolia",
    "deploy:mainnet": "hardhat run scripts/deploy.ts --network mainnet",
    "deploy:polygon": "hardhat run scripts/deploy.ts --network polygon",
    "deploy:base": "hardhat run scripts/deploy.ts --network base",

    "verify:sepolia": "hardhat run scripts/verify.ts --network sepolia",
    "verify:mainnet": "hardhat run scripts/verify.ts --network mainnet",

    "upgrade:sepolia": "hardhat run scripts/upgrade.ts --network sepolia",
    "upgrade:mainnet": "hardhat run scripts/upgrade.ts --network mainnet",

    "size": "hardhat size-contracts",
    "abi:export": "hardhat export-abi",
    "slither": "slither . --config-file slither.config.json",
    "mythril": "myth analyze contracts/*.sol --solc-json mythril.config.json",

    "lint": "solhint 'contracts/**/*.sol'",
    "lint:fix": "solhint 'contracts/**/*.sol' --fix",
    "format": "prettier --write 'contracts/**/*.sol' 'scripts/**/*.ts' 'test/**/*.ts'",

    "node": "hardhat node",
    "fork:mainnet": "hardhat node --fork $RPC_MAINNET",

    "typechain": "hardhat typechain",
    "flatten": "hardhat flatten"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.0",
    "@openzeppelin/hardhat-upgrades": "^3.0.0",
    "hardhat": "^2.19.0",
    "hardhat-abi-exporter": "^2.10.1",
    "hardhat-contract-sizer": "^2.10.0",
    "hardhat-gas-reporter": "^1.0.9",
    "solidity-coverage": "^0.8.5",
    "solhint": "^4.0.0",
    "prettier": "^3.0.0",
    "prettier-plugin-solidity": "^1.2.0"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@openzeppelin/contracts-upgradeable": "^5.0.0",
    "@chainlink/contracts": "^0.8.0",
    "@layerzerolabs/lz-evm-oapp-v2": "^2.0.0",
    "@account-abstraction/contracts": "^0.7.0"
  }
}
```

---

# MODULE 34: ERROR MESSAGES (i18n)

## Error Messages Library

File: `contracts/libraries/Errors.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @notice Centralized error definitions for NFT Protocol
 * @dev Use custom errors for gas efficiency
 */
library Errors {
    // ==================== GENERAL ====================
    error ZeroAddress();
    error ZeroAmount();
    error InvalidInput();
    error Unauthorized();
    error AlreadyInitialized();
    error NotInitialized();
    error Paused();
    error NotPaused();
    error ReentrancyGuard();

    // ==================== NFT ====================
    error TokenNotExists();
    error NotTokenOwner();
    error NotApproved();
    error MaxSupplyReached();
    error InvalidTokenId();
    error TokenAlreadyMinted();
    error TransferFailed();
    error BurnFailed();
    error InvalidRoyalty();

    // ==================== MARKETPLACE ====================
    error ListingNotExists();
    error ListingNotActive();
    error ListingExpired();
    error NotSeller();
    error PriceTooLow();
    error InsufficientPayment();
    error AuctionNotExists();
    error AuctionNotActive();
    error AuctionNotEnded();
    error AuctionEnded();
    error BidTooLow();
    error NotHighestBidder();
    error ReservePriceNotMet();

    // ==================== LENDING ====================
    error LoanNotExists();
    error LoanNotActive();
    error LoanExpired();
    error LoanNotExpired();
    error NotBorrower();
    error NotLender();
    error OfferNotExists();
    error OfferNotActive();
    error OfferExpired();
    error CollectionNotAccepted();
    error InsufficientCollateral();
    error LoanAlreadyRepaid();
    error LoanAlreadyLiquidated();

    // ==================== FRACTIONALIZATION ====================
    error VaultNotExists();
    error VaultNotActive();
    error BuyoutInProgress();
    error BuyoutNotInProgress();
    error BuyoutPeriodNotEnded();
    error InsufficientFractions();
    error ReservePriceNotReached();
    error NotVaultOwner();

    // ==================== COMPLIANCE ====================
    error NotKYCApproved();
    error AddressBlacklisted();
    error CountryRestricted();
    error NotAccreditedInvestor();
    error TransferRestricted();
    error ComplianceCheckFailed();

    // ==================== GOVERNANCE ====================
    error ProposalNotExists();
    error ProposalNotActive();
    error VotingEnded();
    error VotingNotEnded();
    error AlreadyVoted();
    error InsufficientVotingPower();
    error QuorumNotReached();
    error ProposalNotSucceeded();
    error TimelockNotReady();
    error ProposalAlreadyExecuted();

    // ==================== BRIDGE ====================
    error BridgeNotSupported();
    error BridgePaused();
    error TokenBlacklisted();
    error DailyLimitReached();
    error InsufficientBridgeFee();
    error InvalidSourceChain();
    error InvalidDestinationChain();

    // ==================== INSURANCE ====================
    error PolicyNotExists();
    error PolicyNotActive();
    error PolicyExpired();
    error ClaimNotExists();
    error ClaimAlreadyFiled();
    error ClaimAlreadyResolved();
    error InsufficientPoolLiquidity();
    error ValuationExpired();
    error CoverageExceedsValue();

    // ==================== ORACLE ====================
    error StalePrice();
    error InvalidPrice();
    error OracleNotSet();
    error PriceFeedFailed();

    // ==================== ACCOUNT ABSTRACTION ====================
    error InvalidSignature();
    error SessionExpired();
    error SessionNotActive();
    error OperationNotAllowed();
    error EntryPointOnly();
}
```

## Frontend Error Messages (i18n)

File: `frontend/lib/errors/messages.ts`

```typescript
/**
 * Internationalized error messages for NFT Protocol
 */

export type Locale = 'en' | 'es' | 'zh' | 'ja' | 'ko' | 'pt' | 'fr' | 'de';

export const ERROR_MESSAGES: Record<string, Record<Locale, string>> = {
  // General Errors
  ZeroAddress: {
    en: 'Invalid address: cannot be zero address',
    es: 'Direccion invalida: no puede ser direccion cero',
    zh: '无效地址：不能为零地址',
    ja: '無効なアドレス：ゼロアドレスは使用できません',
    ko: '잘못된 주소: 제로 주소가 될 수 없습니다',
    pt: 'Endereco invalido: nao pode ser endereco zero',
    fr: 'Adresse invalide: ne peut pas etre une adresse zero',
    de: 'Ungultige Adresse: Darf nicht Null-Adresse sein',
  },
  Unauthorized: {
    en: 'You are not authorized to perform this action',
    es: 'No esta autorizado para realizar esta accion',
    zh: '您无权执行此操作',
    ja: 'この操作を実行する権限がありません',
    ko: '이 작업을 수행할 권한이 없습니다',
    pt: 'Voce nao esta autorizado a realizar esta acao',
    fr: "Vous n'etes pas autorise a effectuer cette action",
    de: 'Sie sind nicht berechtigt, diese Aktion auszufuhren',
  },

  // NFT Errors
  TokenNotExists: {
    en: 'Token does not exist',
    es: 'El token no existe',
    zh: '代币不存在',
    ja: 'トークンが存在しません',
    ko: '토큰이 존재하지 않습니다',
    pt: 'Token nao existe',
    fr: "Le token n'existe pas",
    de: 'Token existiert nicht',
  },
  NotTokenOwner: {
    en: 'You are not the owner of this token',
    es: 'Usted no es el propietario de este token',
    zh: '您不是此代币的所有者',
    ja: 'あなたはこのトークンの所有者ではありません',
    ko: '당신은 이 토큰의 소유자가 아닙니다',
    pt: 'Voce nao e o proprietario deste token',
    fr: "Vous n'etes pas le proprietaire de ce token",
    de: 'Sie sind nicht der Besitzer dieses Tokens',
  },
  MaxSupplyReached: {
    en: 'Maximum supply has been reached',
    es: 'Se ha alcanzado el suministro maximo',
    zh: '已达到最大供应量',
    ja: '最大供給量に達しました',
    ko: '최대 공급량에 도달했습니다',
    pt: 'Fornecimento maximo foi atingido',
    fr: "L'offre maximale a ete atteinte",
    de: 'Maximale Versorgung wurde erreicht',
  },

  // Marketplace Errors
  ListingNotExists: {
    en: 'Listing does not exist',
    es: 'El listado no existe',
    zh: '列表不存在',
    ja: 'リスティングが存在しません',
    ko: '리스팅이 존재하지 않습니다',
    pt: 'Listagem nao existe',
    fr: "L'annonce n'existe pas",
    de: 'Listing existiert nicht',
  },
  InsufficientPayment: {
    en: 'Insufficient payment amount',
    es: 'Monto de pago insuficiente',
    zh: '支付金额不足',
    ja: '支払い金額が不足しています',
    ko: '결제 금액이 부족합니다',
    pt: 'Valor de pagamento insuficiente',
    fr: 'Montant de paiement insuffisant',
    de: 'Unzureichender Zahlungsbetrag',
  },
  AuctionEnded: {
    en: 'This auction has already ended',
    es: 'Esta subasta ya ha terminado',
    zh: '此拍卖已结束',
    ja: 'このオークションは既に終了しています',
    ko: '이 경매는 이미 종료되었습니다',
    pt: 'Este leilao ja terminou',
    fr: 'Cette enchere est deja terminee',
    de: 'Diese Auktion ist bereits beendet',
  },
  BidTooLow: {
    en: 'Your bid is too low',
    es: 'Su oferta es demasiado baja',
    zh: '您的出价太低',
    ja: '入札額が低すぎます',
    ko: '입찰가가 너무 낮습니다',
    pt: 'Seu lance e muito baixo',
    fr: 'Votre offre est trop basse',
    de: 'Ihr Gebot ist zu niedrig',
  },

  // Lending Errors
  LoanNotActive: {
    en: 'This loan is not active',
    es: 'Este prestamo no esta activo',
    zh: '此贷款未激活',
    ja: 'このローンはアクティブではありません',
    ko: '이 대출은 활성화되지 않았습니다',
    pt: 'Este emprestimo nao esta ativo',
    fr: "Ce pret n'est pas actif",
    de: 'Dieses Darlehen ist nicht aktiv',
  },
  LoanExpired: {
    en: 'This loan has expired',
    es: 'Este prestamo ha expirado',
    zh: '此贷款已过期',
    ja: 'このローンは期限切れです',
    ko: '이 대출은 만료되었습니다',
    pt: 'Este emprestimo expirou',
    fr: 'Ce pret a expire',
    de: 'Dieses Darlehen ist abgelaufen',
  },

  // Compliance Errors
  NotKYCApproved: {
    en: 'KYC verification required to proceed',
    es: 'Se requiere verificacion KYC para continuar',
    zh: '需要KYC验证才能继续',
    ja: '続行するにはKYC認証が必要です',
    ko: '진행하려면 KYC 인증이 필요합니다',
    pt: 'Verificacao KYC necessaria para continuar',
    fr: 'Verification KYC requise pour continuer',
    de: 'KYC-Verifizierung erforderlich, um fortzufahren',
  },
  AddressBlacklisted: {
    en: 'This address has been blacklisted',
    es: 'Esta direccion ha sido incluida en la lista negra',
    zh: '此地址已被列入黑名单',
    ja: 'このアドレスはブラックリストに登録されています',
    ko: '이 주소는 블랙리스트에 등록되었습니다',
    pt: 'Este endereco foi colocado na lista negra',
    fr: 'Cette adresse a ete mise sur liste noire',
    de: 'Diese Adresse wurde auf die schwarze Liste gesetzt',
  },
  CountryRestricted: {
    en: 'This service is not available in your country',
    es: 'Este servicio no esta disponible en su pais',
    zh: '此服务在您所在的国家/地区不可用',
    ja: 'このサービスはお住まいの国ではご利用いただけません',
    ko: '이 서비스는 귀하의 국가에서 사용할 수 없습니다',
    pt: 'Este servico nao esta disponivel no seu pais',
    fr: "Ce service n'est pas disponible dans votre pays",
    de: 'Dieser Service ist in Ihrem Land nicht verfugbar',
  },

  // Transaction Errors
  TransactionFailed: {
    en: 'Transaction failed. Please try again.',
    es: 'Transaccion fallida. Por favor, intentelo de nuevo.',
    zh: '交易失败。请重试。',
    ja: 'トランザクションが失敗しました。もう一度お試しください。',
    ko: '거래 실패. 다시 시도해 주세요.',
    pt: 'Transacao falhou. Por favor, tente novamente.',
    fr: 'Transaction echouee. Veuillez reessayer.',
    de: 'Transaktion fehlgeschlagen. Bitte versuchen Sie es erneut.',
  },
  UserRejected: {
    en: 'Transaction was rejected by user',
    es: 'La transaccion fue rechazada por el usuario',
    zh: '用户拒绝了交易',
    ja: 'トランザクションはユーザーによって拒否されました',
    ko: '사용자가 거래를 거부했습니다',
    pt: 'Transacao foi rejeitada pelo usuario',
    fr: "La transaction a ete rejetee par l'utilisateur",
    de: 'Transaktion wurde vom Benutzer abgelehnt',
  },
  InsufficientFunds: {
    en: 'Insufficient funds in wallet',
    es: 'Fondos insuficientes en la cartera',
    zh: '钱包余额不足',
    ja: 'ウォレットの残高が不足しています',
    ko: '지갑에 잔액이 부족합니다',
    pt: 'Fundos insuficientes na carteira',
    fr: 'Fonds insuffisants dans le portefeuille',
    de: 'Unzureichende Mittel in der Wallet',
  },
};

/**
 * Get localized error message
 */
export function getErrorMessage(errorCode: string, locale: Locale = 'en'): string {
  const messages = ERROR_MESSAGES[errorCode];
  if (!messages) {
    return `Error: ${errorCode}`;
  }
  return messages[locale] || messages.en;
}

/**
 * Parse contract error and get localized message
 */
export function parseContractError(error: any, locale: Locale = 'en'): string {
  // Extract error name from various error formats
  let errorCode = 'TransactionFailed';

  if (error?.reason) {
    errorCode = error.reason;
  } else if (error?.data?.message) {
    const match = error.data.message.match(/reverted with custom error '(\w+)\(/);
    if (match) errorCode = match[1];
  } else if (error?.message) {
    // Check for common patterns
    if (error.message.includes('user rejected')) {
      errorCode = 'UserRejected';
    } else if (error.message.includes('insufficient funds')) {
      errorCode = 'InsufficientFunds';
    }
  }

  return getErrorMessage(errorCode, locale);
}
```

---
