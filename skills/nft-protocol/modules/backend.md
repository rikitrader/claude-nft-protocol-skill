# API Backend

Express/Node.js API backend for NFT protocol: REST endpoints, webhook handlers, indexing services, and database models.

---

# MODULE 19: API BACKEND

## Directory Structure

```
backend/
├── src/
│   ├── index.ts
│   ├── config/
│   │   ├── index.ts
│   │   └── chains.ts
│   ├── routes/
│   │   ├── index.ts
│   │   ├── nft.ts
│   │   ├── marketplace.ts
│   │   ├── lending.ts
│   │   └── metadata.ts
│   ├── services/
│   │   ├── blockchain.ts
│   │   ├── ipfs.ts
│   │   ├── indexer.ts
│   │   └── webhook.ts
│   ├── middleware/
│   │   ├── auth.ts
│   │   ├── rateLimit.ts
│   │   └── validate.ts
│   ├── models/
│   │   ├── NFT.ts
│   │   ├── Listing.ts
│   │   ├── Loan.ts
│   │   └── User.ts
│   ├── utils/
│   │   ├── logger.ts
│   │   └── errors.ts
│   └── types/
│       └── index.ts
├── prisma/
│   └── schema.prisma
├── package.json
├── tsconfig.json
├── Dockerfile
└── docker-compose.yml
```

## Main Server

File: `backend/src/index.ts`

```typescript
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { rateLimiter } from './middleware/rateLimit';
import routes from './routes';

const app = express();

// Middleware
app.use(helmet());
app.use(cors({ origin: config.corsOrigins }));
app.use(express.json());
app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));
app.use(rateLimiter);

// Routes
app.use('/api/v1', routes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handler
app.use(errorHandler);

// Start server
const PORT = config.port || 3001;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

export default app;
```

## Configuration

File: `backend/src/config/index.ts`

```typescript
import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 3001,
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],

  // Database
  databaseUrl: process.env.DATABASE_URL!,

  // Blockchain
  rpcUrls: {
    mainnet: process.env.RPC_MAINNET || `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
    polygon: process.env.RPC_POLYGON || `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
    base: process.env.RPC_BASE || 'https://mainnet.base.org',
  },

  // IPFS
  pinataJwt: process.env.PINATA_JWT!,
  pinataGateway: process.env.PINATA_GATEWAY || 'https://gateway.pinata.cloud',

  // Contract addresses (per chain)
  contracts: {
    mainnet: {
      nft: process.env.NFT_CONTRACT_MAINNET as `0x${string}`,
      marketplace: process.env.MARKETPLACE_CONTRACT_MAINNET as `0x${string}`,
      lending: process.env.LENDING_CONTRACT_MAINNET as `0x${string}`,
    },
    polygon: {
      nft: process.env.NFT_CONTRACT_POLYGON as `0x${string}`,
      marketplace: process.env.MARKETPLACE_CONTRACT_POLYGON as `0x${string}`,
      lending: process.env.LENDING_CONTRACT_POLYGON as `0x${string}`,
    },
  },

  // API Keys
  alchemyKey: process.env.ALCHEMY_KEY,
  webhookSecret: process.env.WEBHOOK_SECRET,

  // Redis
  redisUrl: process.env.REDIS_URL,
};
```

## Routes

File: `backend/src/routes/index.ts`

```typescript
import { Router } from 'express';
import nftRoutes from './nft';
import marketplaceRoutes from './marketplace';
import lendingRoutes from './lending';
import metadataRoutes from './metadata';

const router = Router();

router.use('/nft', nftRoutes);
router.use('/marketplace', marketplaceRoutes);
router.use('/lending', lendingRoutes);
router.use('/metadata', metadataRoutes);

export default router;
```

File: `backend/src/routes/nft.ts`

```typescript
import { Router } from 'express';
import { z } from 'zod';
import { validateRequest } from '../middleware/validate';
import { BlockchainService } from '../services/blockchain';
import { IPFSService } from '../services/ipfs';
import { prisma } from '../utils/prisma';

const router = Router();

// Get NFT by contract and tokenId
router.get('/:chainId/:contract/:tokenId', async (req, res, next) => {
  try {
    const { chainId, contract, tokenId } = req.params;

    // Check cache/database first
    let nft = await prisma.nFT.findUnique({
      where: {
        contract_tokenId_chainId: {
          contract: contract.toLowerCase(),
          tokenId,
          chainId: parseInt(chainId),
        },
      },
      include: {
        attributes: true,
        owner: true,
      },
    });

    if (!nft) {
      // Fetch from blockchain
      const blockchain = new BlockchainService(parseInt(chainId));
      const onChainData = await blockchain.getNFTData(contract as `0x${string}`, BigInt(tokenId));

      // Fetch metadata from IPFS
      const ipfs = new IPFSService();
      const metadata = await ipfs.fetchMetadata(onChainData.tokenURI);

      // Store in database
      nft = await prisma.nFT.create({
        data: {
          contract: contract.toLowerCase(),
          tokenId,
          chainId: parseInt(chainId),
          name: metadata.name,
          description: metadata.description,
          image: metadata.image,
          tokenURI: onChainData.tokenURI,
          ownerId: onChainData.owner.toLowerCase(),
          attributes: {
            create: metadata.attributes?.map((attr: any) => ({
              traitType: attr.trait_type,
              value: attr.value,
              displayType: attr.display_type,
            })) || [],
          },
        },
        include: {
          attributes: true,
          owner: true,
        },
      });
    }

    res.json(nft);
  } catch (error) {
    next(error);
  }
});

// Get NFTs by owner
router.get('/owner/:chainId/:address', async (req, res, next) => {
  try {
    const { chainId, address } = req.params;
    const { page = '1', limit = '20' } = req.query;

    const nfts = await prisma.nFT.findMany({
      where: {
        ownerId: address.toLowerCase(),
        chainId: parseInt(chainId),
      },
      include: {
        attributes: true,
      },
      skip: (parseInt(page as string) - 1) * parseInt(limit as string),
      take: parseInt(limit as string),
      orderBy: { createdAt: 'desc' },
    });

    const total = await prisma.nFT.count({
      where: {
        ownerId: address.toLowerCase(),
        chainId: parseInt(chainId),
      },
    });

    res.json({
      items: nfts,
      pagination: {
        page: parseInt(page as string),
        limit: parseInt(limit as string),
        total,
        pages: Math.ceil(total / parseInt(limit as string)),
      },
    });
  } catch (error) {
    next(error);
  }
});

// Refresh metadata
router.post('/:chainId/:contract/:tokenId/refresh', async (req, res, next) => {
  try {
    const { chainId, contract, tokenId } = req.params;

    const blockchain = new BlockchainService(parseInt(chainId));
    const onChainData = await blockchain.getNFTData(contract as `0x${string}`, BigInt(tokenId));

    const ipfs = new IPFSService();
    const metadata = await ipfs.fetchMetadata(onChainData.tokenURI);

    const nft = await prisma.nFT.update({
      where: {
        contract_tokenId_chainId: {
          contract: contract.toLowerCase(),
          tokenId,
          chainId: parseInt(chainId),
        },
      },
      data: {
        name: metadata.name,
        description: metadata.description,
        image: metadata.image,
        ownerId: onChainData.owner.toLowerCase(),
        updatedAt: new Date(),
      },
    });

    res.json({ message: 'Metadata refreshed', nft });
  } catch (error) {
    next(error);
  }
});

export default router;
```

File: `backend/src/routes/marketplace.ts`

```typescript
import { Router } from 'express';
import { prisma } from '../utils/prisma';
import { BlockchainService } from '../services/blockchain';

const router = Router();

// Get active listings
router.get('/:chainId/listings', async (req, res, next) => {
  try {
    const { chainId } = req.params;
    const { page = '1', limit = '20', sort = 'newest' } = req.query;

    const orderBy = sort === 'price_asc'
      ? { price: 'asc' as const }
      : sort === 'price_desc'
      ? { price: 'desc' as const }
      : { createdAt: 'desc' as const };

    const listings = await prisma.listing.findMany({
      where: {
        chainId: parseInt(chainId),
        isActive: true,
        expiresAt: { gt: new Date() },
      },
      include: {
        nft: {
          include: { attributes: true },
        },
        seller: true,
      },
      orderBy,
      skip: (parseInt(page as string) - 1) * parseInt(limit as string),
      take: parseInt(limit as string),
    });

    const total = await prisma.listing.count({
      where: {
        chainId: parseInt(chainId),
        isActive: true,
        expiresAt: { gt: new Date() },
      },
    });

    res.json({
      items: listings,
      pagination: {
        page: parseInt(page as string),
        limit: parseInt(limit as string),
        total,
        pages: Math.ceil(total / parseInt(limit as string)),
      },
    });
  } catch (error) {
    next(error);
  }
});

// Get active auctions
router.get('/:chainId/auctions', async (req, res, next) => {
  try {
    const { chainId } = req.params;
    const { status = 'active' } = req.query;

    const auctions = await prisma.auction.findMany({
      where: {
        chainId: parseInt(chainId),
        isActive: status === 'active',
        endTime: status === 'active' ? { gt: new Date() } : undefined,
      },
      include: {
        nft: true,
        seller: true,
        bids: {
          orderBy: { amount: 'desc' },
          take: 5,
        },
      },
      orderBy: { endTime: 'asc' },
    });

    res.json(auctions);
  } catch (error) {
    next(error);
  }
});

// Get collection stats
router.get('/:chainId/collection/:contract/stats', async (req, res, next) => {
  try {
    const { chainId, contract } = req.params;

    const [totalSupply, totalVolume, floorListing, uniqueOwners] = await Promise.all([
      prisma.nFT.count({
        where: { contract: contract.toLowerCase(), chainId: parseInt(chainId) },
      }),
      prisma.sale.aggregate({
        where: { nft: { contract: contract.toLowerCase(), chainId: parseInt(chainId) } },
        _sum: { price: true },
      }),
      prisma.listing.findFirst({
        where: {
          nft: { contract: contract.toLowerCase(), chainId: parseInt(chainId) },
          isActive: true,
        },
        orderBy: { price: 'asc' },
      }),
      prisma.nFT.groupBy({
        by: ['ownerId'],
        where: { contract: contract.toLowerCase(), chainId: parseInt(chainId) },
      }),
    ]);

    res.json({
      totalSupply,
      totalVolume: totalVolume._sum.price || '0',
      floorPrice: floorListing?.price || '0',
      uniqueOwners: uniqueOwners.length,
    });
  } catch (error) {
    next(error);
  }
});

export default router;
```

File: `backend/src/routes/metadata.ts`

```typescript
import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { IPFSService } from '../services/ipfs';
import { validateRequest } from '../middleware/validate';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

const metadataSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(5000),
  image: z.string().optional(),
  animation_url: z.string().optional(),
  external_url: z.string().url().optional(),
  attributes: z.array(z.object({
    trait_type: z.string(),
    value: z.union([z.string(), z.number()]),
    display_type: z.string().optional(),
  })).optional(),
  properties: z.record(z.any()).optional(),
});

// Upload image to IPFS
router.post('/upload/image', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file provided' });
    }

    const ipfs = new IPFSService();
    const cid = await ipfs.uploadFile(req.file.buffer, req.file.originalname);

    res.json({
      cid,
      url: `ipfs://${cid}`,
      gateway: `${ipfs.gatewayUrl}/ipfs/${cid}`,
    });
  } catch (error) {
    next(error);
  }
});

// Upload metadata to IPFS
router.post('/upload/metadata', validateRequest(metadataSchema), async (req, res, next) => {
  try {
    const metadata = req.body;
    const ipfs = new IPFSService();
    const cid = await ipfs.uploadJSON(metadata);

    res.json({
      cid,
      url: `ipfs://${cid}`,
      gateway: `${ipfs.gatewayUrl}/ipfs/${cid}`,
    });
  } catch (error) {
    next(error);
  }
});

// Fetch and parse metadata
router.get('/fetch', async (req, res, next) => {
  try {
    const { uri } = req.query;

    if (!uri || typeof uri !== 'string') {
      return res.status(400).json({ error: 'URI required' });
    }

    const ipfs = new IPFSService();
    const metadata = await ipfs.fetchMetadata(uri);

    res.json(metadata);
  } catch (error) {
    next(error);
  }
});

export default router;
```

## Services

File: `backend/src/services/blockchain.ts`

```typescript
import { createPublicClient, http, parseAbi, getContract } from 'viem';
import { mainnet, polygon, base } from 'viem/chains';
import { config } from '../config';

const chains = {
  1: mainnet,
  137: polygon,
  8453: base,
};

const ERC721_ABI = parseAbi([
  'function ownerOf(uint256 tokenId) view returns (address)',
  'function tokenURI(uint256 tokenId) view returns (string)',
  'function balanceOf(address owner) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)',
]);

export class BlockchainService {
  private client;
  private chainId: number;

  constructor(chainId: number) {
    this.chainId = chainId;
    const chain = chains[chainId as keyof typeof chains];
    const rpcUrl = config.rpcUrls[chain.network as keyof typeof config.rpcUrls];

    this.client = createPublicClient({
      chain,
      transport: http(rpcUrl),
    });
  }

  async getNFTData(contract: `0x${string}`, tokenId: bigint) {
    const nftContract = getContract({
      address: contract,
      abi: ERC721_ABI,
      client: this.client,
    });

    const [owner, tokenURI] = await Promise.all([
      nftContract.read.ownerOf([tokenId]),
      nftContract.read.tokenURI([tokenId]),
    ]);

    return { owner, tokenURI };
  }

  async getOwnerBalance(contract: `0x${string}`, owner: `0x${string}`) {
    const nftContract = getContract({
      address: contract,
      abi: ERC721_ABI,
      client: this.client,
    });

    return nftContract.read.balanceOf([owner]);
  }

  async getTotalSupply(contract: `0x${string}`) {
    const nftContract = getContract({
      address: contract,
      abi: ERC721_ABI,
      client: this.client,
    });

    return nftContract.read.totalSupply();
  }

  async getTransferEvents(contract: `0x${string}`, fromBlock: bigint, toBlock: bigint) {
    const logs = await this.client.getLogs({
      address: contract,
      event: {
        type: 'event',
        name: 'Transfer',
        inputs: [
          { type: 'address', indexed: true, name: 'from' },
          { type: 'address', indexed: true, name: 'to' },
          { type: 'uint256', indexed: true, name: 'tokenId' },
        ],
      },
      fromBlock,
      toBlock,
    });

    return logs.map((log) => ({
      from: log.args.from,
      to: log.args.to,
      tokenId: log.args.tokenId?.toString(),
      blockNumber: log.blockNumber,
      transactionHash: log.transactionHash,
    }));
  }
}
```

File: `backend/src/services/ipfs.ts`

```typescript
import axios from 'axios';
import FormData from 'form-data';
import { config } from '../config';

export class IPFSService {
  private pinataJwt: string;
  public gatewayUrl: string;

  constructor() {
    this.pinataJwt = config.pinataJwt;
    this.gatewayUrl = config.pinataGateway;
  }

  async uploadFile(buffer: Buffer, filename: string): Promise<string> {
    const formData = new FormData();
    formData.append('file', buffer, { filename });

    const response = await axios.post(
      'https://api.pinata.cloud/pinning/pinFileToIPFS',
      formData,
      {
        headers: {
          Authorization: `Bearer ${this.pinataJwt}`,
          ...formData.getHeaders(),
        },
        maxContentLength: Infinity,
      }
    );

    return response.data.IpfsHash;
  }

  async uploadJSON(json: object): Promise<string> {
    const response = await axios.post(
      'https://api.pinata.cloud/pinning/pinJSONToIPFS',
      {
        pinataContent: json,
        pinataMetadata: {
          name: `metadata-${Date.now()}.json`,
        },
      },
      {
        headers: {
          Authorization: `Bearer ${this.pinataJwt}`,
          'Content-Type': 'application/json',
        },
      }
    );

    return response.data.IpfsHash;
  }

  async fetchMetadata(uri: string): Promise<any> {
    let url = uri;

    if (uri.startsWith('ipfs://')) {
      url = `${this.gatewayUrl}/ipfs/${uri.replace('ipfs://', '')}`;
    } else if (uri.startsWith('ar://')) {
      url = `https://arweave.net/${uri.replace('ar://', '')}`;
    }

    const response = await axios.get(url, { timeout: 10000 });
    return response.data;
  }

  resolveIPFSUrl(uri: string): string {
    if (uri.startsWith('ipfs://')) {
      return `${this.gatewayUrl}/ipfs/${uri.replace('ipfs://', '')}`;
    }
    return uri;
  }
}
```

File: `backend/src/services/webhook.ts`

```typescript
import { createHmac } from 'crypto';
import { config } from '../config';
import { prisma } from '../utils/prisma';
import { logger } from '../utils/logger';

interface AlchemyWebhookEvent {
  webhookId: string;
  id: string;
  createdAt: string;
  type: string;
  event: {
    network: string;
    activity: Array<{
      fromAddress: string;
      toAddress: string;
      blockNum: string;
      hash: string;
      erc721TokenId?: string;
      asset: string;
      category: string;
      rawContract: {
        address: string;
      };
    }>;
  };
}

export class WebhookService {
  verifySignature(payload: string, signature: string): boolean {
    const hmac = createHmac('sha256', config.webhookSecret!);
    const digest = hmac.update(payload).digest('hex');
    return signature === digest;
  }

  async processAlchemyWebhook(event: AlchemyWebhookEvent) {
    logger.info(`Processing webhook: ${event.type}`);

    for (const activity of event.event.activity) {
      if (activity.category === 'erc721' && activity.erc721TokenId) {
        await this.processNFTTransfer({
          contract: activity.rawContract.address.toLowerCase(),
          tokenId: activity.erc721TokenId,
          from: activity.fromAddress.toLowerCase(),
          to: activity.toAddress.toLowerCase(),
          txHash: activity.hash,
          blockNumber: parseInt(activity.blockNum, 16),
          network: event.event.network,
        });
      }
    }
  }

  private async processNFTTransfer(data: {
    contract: string;
    tokenId: string;
    from: string;
    to: string;
    txHash: string;
    blockNumber: number;
    network: string;
  }) {
    const chainId = this.getChainId(data.network);

    // Update NFT owner
    await prisma.nFT.upsert({
      where: {
        contract_tokenId_chainId: {
          contract: data.contract,
          tokenId: data.tokenId,
          chainId,
        },
      },
      update: {
        ownerId: data.to,
        updatedAt: new Date(),
      },
      create: {
        contract: data.contract,
        tokenId: data.tokenId,
        chainId,
        ownerId: data.to,
        name: `Token #${data.tokenId}`,
        tokenURI: '',
      },
    });

    // Record transfer
    await prisma.transfer.create({
      data: {
        nftId: `${data.contract}-${data.tokenId}-${chainId}`,
        fromAddress: data.from,
        toAddress: data.to,
        txHash: data.txHash,
        blockNumber: data.blockNumber,
      },
    });

    logger.info(`Processed transfer: ${data.contract}/${data.tokenId} -> ${data.to}`);
  }

  private getChainId(network: string): number {
    const networks: Record<string, number> = {
      'ETH_MAINNET': 1,
      'MATIC_MAINNET': 137,
      'BASE_MAINNET': 8453,
    };
    return networks[network] || 1;
  }
}
```

## Database Schema

File: `backend/prisma/schema.prisma`

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String     @id @default(uuid())
  address       String     @unique
  nftsOwned     NFT[]
  listings      Listing[]
  auctions      Auction[]
  bids          Bid[]
  loans         Loan[]     @relation("borrower")
  loanOffers    LoanOffer[] @relation("lender")
  sales         Sale[]     @relation("seller")
  purchases     Sale[]     @relation("buyer")
  isKYCApproved Boolean    @default(false)
  isAccredited  Boolean    @default(false)
  isBlacklisted Boolean    @default(false)
  createdAt     DateTime   @default(now())
  updatedAt     DateTime   @updatedAt
}

model NFT {
  id          String      @id @default(uuid())
  contract    String
  tokenId     String
  chainId     Int
  name        String?
  description String?
  image       String?
  tokenURI    String
  owner       User        @relation(fields: [ownerId], references: [address])
  ownerId     String
  attributes  Attribute[]
  listings    Listing[]
  auctions    Auction[]
  loans       Loan[]
  sales       Sale[]
  transfers   Transfer[]
  createdAt   DateTime    @default(now())
  updatedAt   DateTime    @updatedAt

  @@unique([contract, tokenId, chainId])
  @@index([ownerId])
  @@index([contract, chainId])
}

model Attribute {
  id          String  @id @default(uuid())
  nft         NFT     @relation(fields: [nftId], references: [id])
  nftId       String
  traitType   String
  value       String
  displayType String?

  @@index([nftId])
}

model Listing {
  id            String   @id @default(uuid())
  listingId     String
  chainId       Int
  nft           NFT      @relation(fields: [nftId], references: [id])
  nftId         String
  seller        User     @relation(fields: [sellerId], references: [address])
  sellerId      String
  price         String
  expiresAt     DateTime
  isActive      Boolean  @default(true)
  sale          Sale?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@unique([listingId, chainId])
  @@index([isActive, expiresAt])
}

model Auction {
  id             String      @id @default(uuid())
  auctionId      String
  chainId        Int
  nft            NFT         @relation(fields: [nftId], references: [id])
  nftId          String
  seller         User        @relation(fields: [sellerId], references: [address])
  sellerId       String
  auctionType    AuctionType
  startPrice     String
  reservePrice   String
  currentBid     String?
  currentBidder  String?
  startTime      DateTime
  endTime        DateTime
  isActive       Boolean     @default(true)
  bids           Bid[]
  sale           Sale?
  createdAt      DateTime    @default(now())
  updatedAt      DateTime    @updatedAt

  @@unique([auctionId, chainId])
}

enum AuctionType {
  ENGLISH
  DUTCH
}

model Bid {
  id        String   @id @default(uuid())
  auction   Auction  @relation(fields: [auctionId], references: [id])
  auctionId String
  bidder    User     @relation(fields: [bidderId], references: [address])
  bidderId  String
  amount    String
  txHash    String
  createdAt DateTime @default(now())

  @@index([auctionId])
}

model Sale {
  id          String   @id @default(uuid())
  nft         NFT      @relation(fields: [nftId], references: [id])
  nftId       String
  seller      User     @relation("seller", fields: [sellerId], references: [address])
  sellerId    String
  buyer       User     @relation("buyer", fields: [buyerId], references: [address])
  buyerId     String
  price       String
  royaltyPaid String?
  protocolFee String?
  listing     Listing? @relation(fields: [listingId], references: [id])
  listingId   String?  @unique
  auction     Auction? @relation(fields: [auctionId], references: [id])
  auctionId   String?  @unique
  txHash      String
  createdAt   DateTime @default(now())

  @@index([sellerId])
  @@index([buyerId])
}

model Loan {
  id              String     @id @default(uuid())
  loanId          String
  chainId         Int
  nft             NFT        @relation(fields: [nftId], references: [id])
  nftId           String
  borrower        User       @relation("borrower", fields: [borrowerId], references: [address])
  borrowerId      String
  lender          String
  principal       String
  interestRateBps Int
  accruedInterest String     @default("0")
  startTime       DateTime
  duration        Int
  status          LoanStatus @default(ACTIVE)
  repaidAt        DateTime?
  liquidatedAt    DateTime?
  createdAt       DateTime   @default(now())
  updatedAt       DateTime   @updatedAt

  @@unique([loanId, chainId])
}

model LoanOffer {
  id              String   @id @default(uuid())
  offerId         String
  chainId         Int
  lender          User     @relation("lender", fields: [lenderId], references: [address])
  lenderId        String
  principal       String
  interestRateBps Int
  duration        Int
  expiresAt       DateTime
  isActive        Boolean  @default(true)
  createdAt       DateTime @default(now())

  @@unique([offerId, chainId])
}

enum LoanStatus {
  ACTIVE
  REPAID
  DEFAULTED
  LIQUIDATED
}

model Transfer {
  id          String   @id @default(uuid())
  nft         NFT      @relation(fields: [nftId], references: [id])
  nftId       String
  fromAddress String
  toAddress   String
  txHash      String
  blockNumber Int
  createdAt   DateTime @default(now())

  @@index([nftId])
  @@index([txHash])
}
```

## Docker Configuration

File: `backend/Dockerfile`

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

COPY . .

RUN npm run build
RUN npx prisma generate

FROM node:20-alpine AS runner

WORKDIR /app

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./

EXPOSE 3001

CMD ["npm", "start"]
```

File: `backend/docker-compose.yml`

```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "3001:3001"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/nft_protocol
      - REDIS_URL=redis://redis:6379
      - NODE_ENV=production
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=nft_protocol
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

---
