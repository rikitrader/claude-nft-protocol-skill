# Frontend Integration

React hooks, Web3 integration patterns, and reusable frontend components for NFT applications.

---

# MODULE 12: FRONTEND INTEGRATION

## React Hooks with wagmi/viem

### File: `hooks/useNFT.ts`

```typescript
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { NFT_ABI, MARKETPLACE_ABI, LENDING_ABI } from '../abis';

// ==================== NFT Hooks ====================

export function useTokenOwner(contractAddress: `0x${string}`, tokenId: bigint) {
  return useReadContract({
    address: contractAddress,
    abi: NFT_ABI,
    functionName: 'ownerOf',
    args: [tokenId],
  });
}

export function useTokenURI(contractAddress: `0x${string}`, tokenId: bigint) {
  return useReadContract({
    address: contractAddress,
    abi: NFT_ABI,
    functionName: 'tokenURI',
    args: [tokenId],
  });
}

export function useMintNFT() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const mint = async (
    contractAddress: `0x${string}`,
    to: `0x${string}`,
    tokenId: bigint,
    uri: string,
    royaltyBps: number
  ) => {
    return writeContract({
      address: contractAddress,
      abi: NFT_ABI,
      functionName: 'mint',
      args: [to, tokenId, uri, royaltyBps],
    });
  };

  return { mint, hash, isPending, isConfirming, isSuccess, error };
}

// ==================== Marketplace Hooks ====================

export function useCreateListing() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createListing = async (
    marketplaceAddress: `0x${string}`,
    nftContract: `0x${string}`,
    tokenId: bigint,
    priceInEth: string,
    durationSeconds: bigint
  ) => {
    return writeContract({
      address: marketplaceAddress,
      abi: MARKETPLACE_ABI,
      functionName: 'createListing',
      args: [nftContract, tokenId, parseEther(priceInEth), durationSeconds],
    });
  };

  return { createListing, hash, isPending, isConfirming, isSuccess, error };
}

export function useBuyNFT() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const buy = async (
    marketplaceAddress: `0x${string}`,
    listingId: bigint,
    priceInWei: bigint
  ) => {
    return writeContract({
      address: marketplaceAddress,
      abi: MARKETPLACE_ABI,
      functionName: 'buy',
      args: [listingId],
      value: priceInWei,
    });
  };

  return { buy, hash, isPending, isConfirming, isSuccess, error };
}

export function usePlaceBid() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const placeBid = async (
    marketplaceAddress: `0x${string}`,
    auctionId: bigint,
    bidAmountInWei: bigint
  ) => {
    return writeContract({
      address: marketplaceAddress,
      abi: MARKETPLACE_ABI,
      functionName: 'placeBid',
      args: [auctionId],
      value: bidAmountInWei,
    });
  };

  return { placeBid, hash, isPending, isConfirming, isSuccess, error };
}

// ==================== Lending Hooks ====================

export function useBorrow() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const borrow = async (
    lendingAddress: `0x${string}`,
    offerId: bigint,
    nftContract: `0x${string}`,
    tokenId: bigint
  ) => {
    return writeContract({
      address: lendingAddress,
      abi: LENDING_ABI,
      functionName: 'borrow',
      args: [offerId, nftContract, tokenId],
    });
  };

  return { borrow, hash, isPending, isConfirming, isSuccess, error };
}

export function useRepayLoan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const repay = async (
    lendingAddress: `0x${string}`,
    loanId: bigint,
    amountInWei: bigint
  ) => {
    return writeContract({
      address: lendingAddress,
      abi: LENDING_ABI,
      functionName: 'repay',
      args: [loanId],
      value: amountInWei,
    });
  };

  return { repay, hash, isPending, isConfirming, isSuccess, error };
}

// ==================== Approval Hook ====================

export function useApproveNFT() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const approve = async (
    nftContract: `0x${string}`,
    operator: `0x${string}`,
    tokenId: bigint
  ) => {
    return writeContract({
      address: nftContract,
      abi: NFT_ABI,
      functionName: 'approve',
      args: [operator, tokenId],
    });
  };

  const setApprovalForAll = async (
    nftContract: `0x${string}`,
    operator: `0x${string}`,
    approved: boolean
  ) => {
    return writeContract({
      address: nftContract,
      abi: NFT_ABI,
      functionName: 'setApprovalForAll',
      args: [operator, approved],
    });
  };

  return { approve, setApprovalForAll, hash, isPending, isConfirming, isSuccess, error };
}
```

### File: `hooks/useIPFS.ts`

```typescript
import { useState } from 'react';

const PINATA_JWT = process.env.NEXT_PUBLIC_PINATA_JWT;
const PINATA_GATEWAY = process.env.NEXT_PUBLIC_PINATA_GATEWAY;

interface NFTMetadata {
  name: string;
  description: string;
  image: string;
  animation_url?: string;
  external_url?: string;
  attributes: Array<{
    trait_type: string;
    value: string | number;
    display_type?: string;
  }>;
  properties?: Record<string, unknown>;
}

export function useIPFS() {
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const uploadFile = async (file: File): Promise<string> => {
    setIsUploading(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch('https://api.pinata.cloud/pinning/pinFileToIPFS', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${PINATA_JWT}`,
        },
        body: formData,
      });

      if (!response.ok) {
        throw new Error('Failed to upload to IPFS');
      }

      const data = await response.json();
      return `ipfs://${data.IpfsHash}`;
    } catch (err) {
      setError(err as Error);
      throw err;
    } finally {
      setIsUploading(false);
    }
  };

  const uploadMetadata = async (metadata: NFTMetadata): Promise<string> => {
    setIsUploading(true);
    setError(null);

    try {
      const response = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${PINATA_JWT}`,
        },
        body: JSON.stringify({
          pinataContent: metadata,
          pinataMetadata: {
            name: `${metadata.name}.json`,
          },
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to upload metadata to IPFS');
      }

      const data = await response.json();
      return `ipfs://${data.IpfsHash}`;
    } catch (err) {
      setError(err as Error);
      throw err;
    } finally {
      setIsUploading(false);
    }
  };

  const getIPFSUrl = (cid: string): string => {
    if (cid.startsWith('ipfs://')) {
      cid = cid.replace('ipfs://', '');
    }
    return `${PINATA_GATEWAY}/ipfs/${cid}`;
  };

  return { uploadFile, uploadMetadata, getIPFSUrl, isUploading, error };
}
```

### File: `components/WalletConnect.tsx`

```tsx
'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useBalance } from 'wagmi';

export function WalletConnect() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });

  return (
    <div className="flex items-center gap-4">
      <ConnectButton />
      {isConnected && balance && (
        <span className="text-sm text-gray-600">
          {parseFloat(balance.formatted).toFixed(4)} {balance.symbol}
        </span>
      )}
    </div>
  );
}
```

### File: `lib/wagmi.ts`

```typescript
import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { mainnet, polygon, base, arbitrum, sepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Institutional NFT Protocol',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID!,
  chains: [mainnet, polygon, base, arbitrum, sepolia],
  ssr: true,
});

export const CONTRACT_ADDRESSES = {
  mainnet: {
    nft: '0x...',
    marketplace: '0x...',
    lending: '0x...',
    compliance: '0x...',
  },
  polygon: {
    nft: '0x...',
    marketplace: '0x...',
    lending: '0x...',
    compliance: '0x...',
  },
  base: {
    nft: '0x...',
    marketplace: '0x...',
    lending: '0x...',
    compliance: '0x...',
  },
} as const;
```

---

# MODULE 18: FRONTEND COMPONENTS

## Directory Structure

```
frontend/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── marketplace/
│   │   └── page.tsx
│   ├── mint/
│   │   └── page.tsx
│   ├── lending/
│   │   └── page.tsx
│   └── portfolio/
│       └── page.tsx
├── components/
│   ├── layout/
│   │   ├── Header.tsx
│   │   └── Footer.tsx
│   ├── nft/
│   │   ├── NFTCard.tsx
│   │   ├── NFTGrid.tsx
│   │   └── NFTDetail.tsx
│   ├── marketplace/
│   │   ├── ListingCard.tsx
│   │   ├── CreateListing.tsx
│   │   ├── AuctionCard.tsx
│   │   └── BuyModal.tsx
│   ├── lending/
│   │   ├── LoanCard.tsx
│   │   ├── CreateLoanOffer.tsx
│   │   └── BorrowModal.tsx
│   ├── mint/
│   │   └── MintForm.tsx
│   └── common/
│       ├── Button.tsx
│       ├── Modal.tsx
│       └── LoadingSpinner.tsx
├── hooks/
│   ├── useNFT.ts
│   ├── useMarketplace.ts
│   ├── useLending.ts
│   └── useIPFS.ts
├── lib/
│   ├── wagmi.ts
│   ├── contracts.ts
│   └── utils.ts
└── types/
    └── index.ts
```

## App Layout

File: `frontend/app/layout.tsx`

```tsx
'use client';

import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit';
import { config } from '@/lib/wagmi';
import { Header } from '@/components/layout/Header';
import '@rainbow-me/rainbowkit/styles.css';
import './globals.css';

const queryClient = new QueryClient();

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            <RainbowKitProvider theme={darkTheme()}>
              <Header />
              <main className="container mx-auto px-4 py-8">
                {children}
              </main>
            </RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}
```

## Header Component

File: `frontend/components/layout/Header.tsx`

```tsx
'use client';

import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';

export function Header() {
  const { isConnected } = useAccount();

  return (
    <header className="border-b border-gray-800 bg-gray-900">
      <div className="container mx-auto px-4">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold text-white">
              NFT Protocol
            </Link>

            <nav className="hidden md:flex items-center gap-6">
              <Link href="/marketplace" className="text-gray-300 hover:text-white">
                Marketplace
              </Link>
              <Link href="/mint" className="text-gray-300 hover:text-white">
                Mint
              </Link>
              <Link href="/lending" className="text-gray-300 hover:text-white">
                Lending
              </Link>
              {isConnected && (
                <Link href="/portfolio" className="text-gray-300 hover:text-white">
                  Portfolio
                </Link>
              )}
            </nav>
          </div>

          <ConnectButton />
        </div>
      </div>
    </header>
  );
}
```

## NFT Card Component

File: `frontend/components/nft/NFTCard.tsx`

```tsx
'use client';

import Image from 'next/image';
import Link from 'next/link';
import { formatEther } from 'viem';

interface NFTCardProps {
  tokenId: string;
  name: string;
  image: string;
  price?: bigint;
  owner?: string;
  contractAddress: string;
}

export function NFTCard({
  tokenId,
  name,
  image,
  price,
  owner,
  contractAddress,
}: NFTCardProps) {
  return (
    <Link href={`/nft/${contractAddress}/${tokenId}`}>
      <div className="rounded-xl bg-gray-800 overflow-hidden hover:ring-2 hover:ring-blue-500 transition-all">
        <div className="aspect-square relative">
          <Image
            src={image.replace('ipfs://', 'https://ipfs.io/ipfs/')}
            alt={name}
            fill
            className="object-cover"
          />
        </div>
        <div className="p-4">
          <h3 className="font-semibold text-white truncate">{name}</h3>
          <p className="text-sm text-gray-400">#{tokenId}</p>

          {price && (
            <div className="mt-2 flex items-center justify-between">
              <span className="text-sm text-gray-400">Price</span>
              <span className="font-semibold text-white">
                {formatEther(price)} ETH
              </span>
            </div>
          )}

          {owner && (
            <p className="mt-2 text-xs text-gray-500 truncate">
              Owner: {owner.slice(0, 6)}...{owner.slice(-4)}
            </p>
          )}
        </div>
      </div>
    </Link>
  );
}
```

## Marketplace Listing

File: `frontend/components/marketplace/ListingCard.tsx`

```tsx
'use client';

import { useState } from 'react';
import { formatEther } from 'viem';
import { useAccount } from 'wagmi';
import { useBuyNFT } from '@/hooks/useMarketplace';
import { Button } from '@/components/common/Button';
import { NFTCard } from '@/components/nft/NFTCard';

interface ListingCardProps {
  listingId: bigint;
  tokenId: string;
  name: string;
  image: string;
  price: bigint;
  seller: string;
  contractAddress: string;
  marketplaceAddress: `0x${string}`;
}

export function ListingCard({
  listingId,
  tokenId,
  name,
  image,
  price,
  seller,
  contractAddress,
  marketplaceAddress,
}: ListingCardProps) {
  const { address } = useAccount();
  const { buy, isPending, isConfirming } = useBuyNFT();
  const [error, setError] = useState<string | null>(null);

  const isOwner = address?.toLowerCase() === seller.toLowerCase();

  const handleBuy = async () => {
    setError(null);
    try {
      await buy(marketplaceAddress, listingId, price);
    } catch (err: any) {
      setError(err.message || 'Failed to buy');
    }
  };

  return (
    <div className="rounded-xl bg-gray-800 overflow-hidden">
      <NFTCard
        tokenId={tokenId}
        name={name}
        image={image}
        contractAddress={contractAddress}
      />

      <div className="p-4 border-t border-gray-700">
        <div className="flex items-center justify-between mb-4">
          <span className="text-gray-400">Price</span>
          <span className="text-xl font-bold text-white">
            {formatEther(price)} ETH
          </span>
        </div>

        {!isOwner && (
          <Button
            onClick={handleBuy}
            disabled={isPending || isConfirming}
            className="w-full"
          >
            {isPending ? 'Confirming...' : isConfirming ? 'Processing...' : 'Buy Now'}
          </Button>
        )}

        {isOwner && (
          <p className="text-center text-gray-500">You own this listing</p>
        )}

        {error && (
          <p className="mt-2 text-sm text-red-500">{error}</p>
        )}
      </div>
    </div>
  );
}
```

## Create Listing Form

File: `frontend/components/marketplace/CreateListing.tsx`

```tsx
'use client';

import { useState } from 'react';
import { parseEther } from 'viem';
import { useAccount } from 'wagmi';
import { useCreateListing, useApproveNFT } from '@/hooks/useMarketplace';
import { Button } from '@/components/common/Button';

interface CreateListingProps {
  nftContract: `0x${string}`;
  marketplaceAddress: `0x${string}`;
  tokenId: bigint;
  onSuccess?: () => void;
}

export function CreateListing({
  nftContract,
  marketplaceAddress,
  tokenId,
  onSuccess,
}: CreateListingProps) {
  const { address } = useAccount();
  const [price, setPrice] = useState('');
  const [duration, setDuration] = useState('7'); // days
  const [step, setStep] = useState<'approve' | 'list'>('approve');
  const [error, setError] = useState<string | null>(null);

  const { setApprovalForAll, isPending: isApproving } = useApproveNFT();
  const { createListing, isPending: isListing, isSuccess } = useCreateListing();

  const handleApprove = async () => {
    setError(null);
    try {
      await setApprovalForAll(nftContract, marketplaceAddress, true);
      setStep('list');
    } catch (err: any) {
      setError(err.message || 'Failed to approve');
    }
  };

  const handleList = async () => {
    setError(null);
    if (!price || parseFloat(price) <= 0) {
      setError('Please enter a valid price');
      return;
    }

    try {
      const durationSeconds = BigInt(parseInt(duration) * 24 * 60 * 60);
      await createListing(marketplaceAddress, nftContract, tokenId, price, durationSeconds);
      onSuccess?.();
    } catch (err: any) {
      setError(err.message || 'Failed to create listing');
    }
  };

  if (isSuccess) {
    return (
      <div className="text-center py-8">
        <div className="text-green-500 text-4xl mb-4">✓</div>
        <h3 className="text-xl font-bold text-white">Listed Successfully!</h3>
        <p className="text-gray-400 mt-2">Your NFT is now listed for sale.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold text-white">Create Listing</h2>

      {step === 'approve' && (
        <div className="space-y-4">
          <p className="text-gray-400">
            First, approve the marketplace to transfer your NFT.
          </p>
          <Button onClick={handleApprove} disabled={isApproving} className="w-full">
            {isApproving ? 'Approving...' : 'Approve Marketplace'}
          </Button>
        </div>
      )}

      {step === 'list' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Price (ETH)
            </label>
            <input
              type="number"
              step="0.001"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
              placeholder="0.00"
            />
          </div>

          <div>
            <label className="block text-sm text-gray-400 mb-2">
              Duration (days)
            </label>
            <select
              value={duration}
              onChange={(e) => setDuration(e.target.value)}
              className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
            >
              <option value="1">1 day</option>
              <option value="3">3 days</option>
              <option value="7">7 days</option>
              <option value="14">14 days</option>
              <option value="30">30 days</option>
            </select>
          </div>

          <Button onClick={handleList} disabled={isListing} className="w-full">
            {isListing ? 'Creating Listing...' : 'List for Sale'}
          </Button>
        </div>
      )}

      {error && (
        <p className="text-sm text-red-500">{error}</p>
      )}
    </div>
  );
}
```

## Mint Form

File: `frontend/components/mint/MintForm.tsx`

```tsx
'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useMintNFT } from '@/hooks/useNFT';
import { useIPFS } from '@/hooks/useIPFS';
import { Button } from '@/components/common/Button';

interface MintFormProps {
  nftContract: `0x${string}`;
  onSuccess?: (tokenId: bigint) => void;
}

export function MintForm({ nftContract, onSuccess }: MintFormProps) {
  const { address } = useAccount();
  const { mint, isPending, isConfirming, isSuccess } = useMintNFT();
  const { uploadFile, uploadMetadata, isUploading } = useIPFS();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [image, setImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [attributes, setAttributes] = useState<{ trait_type: string; value: string }[]>([
    { trait_type: '', value: '' },
  ]);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState<'form' | 'uploading' | 'minting' | 'success'>('form');

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setImage(file);
      setImagePreview(URL.createObjectURL(file));
    }
  };

  const addAttribute = () => {
    setAttributes([...attributes, { trait_type: '', value: '' }]);
  };

  const updateAttribute = (index: number, field: 'trait_type' | 'value', value: string) => {
    const newAttributes = [...attributes];
    newAttributes[index][field] = value;
    setAttributes(newAttributes);
  };

  const handleMint = async () => {
    setError(null);

    if (!name || !description || !image) {
      setError('Please fill in all required fields');
      return;
    }

    try {
      // Upload image
      setStep('uploading');
      const imageCID = await uploadFile(image);

      // Create and upload metadata
      const metadata = {
        name,
        description,
        image: imageCID,
        attributes: attributes.filter((a) => a.trait_type && a.value),
      };
      const metadataCID = await uploadMetadata(metadata);

      // Mint NFT
      setStep('minting');
      const nextTokenId = BigInt(Date.now()); // In production, get from contract
      await mint(nftContract, address!, nextTokenId, metadataCID, 500);

      setStep('success');
      onSuccess?.(nextTokenId);
    } catch (err: any) {
      setError(err.message || 'Failed to mint');
      setStep('form');
    }
  };

  if (step === 'success') {
    return (
      <div className="text-center py-8">
        <div className="text-green-500 text-4xl mb-4">✓</div>
        <h3 className="text-xl font-bold text-white">Minted Successfully!</h3>
        <p className="text-gray-400 mt-2">Your NFT has been minted.</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <h2 className="text-2xl font-bold text-white">Mint NFT</h2>

      {/* Image Upload */}
      <div>
        <label className="block text-sm text-gray-400 mb-2">Image *</label>
        <div className="border-2 border-dashed border-gray-600 rounded-lg p-8 text-center">
          {imagePreview ? (
            <img
              src={imagePreview}
              alt="Preview"
              className="max-h-64 mx-auto rounded-lg"
            />
          ) : (
            <p className="text-gray-500">Click or drag to upload</p>
          )}
          <input
            type="file"
            accept="image/*"
            onChange={handleImageChange}
            className="absolute inset-0 opacity-0 cursor-pointer"
          />
        </div>
      </div>

      {/* Name */}
      <div>
        <label className="block text-sm text-gray-400 mb-2">Name *</label>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
          placeholder="My NFT"
        />
      </div>

      {/* Description */}
      <div>
        <label className="block text-sm text-gray-400 mb-2">Description *</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={4}
          className="w-full px-4 py-2 bg-gray-700 rounded-lg text-white"
          placeholder="Describe your NFT..."
        />
      </div>

      {/* Attributes */}
      <div>
        <label className="block text-sm text-gray-400 mb-2">Attributes</label>
        {attributes.map((attr, index) => (
          <div key={index} className="flex gap-2 mb-2">
            <input
              type="text"
              value={attr.trait_type}
              onChange={(e) => updateAttribute(index, 'trait_type', e.target.value)}
              className="flex-1 px-4 py-2 bg-gray-700 rounded-lg text-white"
              placeholder="Trait"
            />
            <input
              type="text"
              value={attr.value}
              onChange={(e) => updateAttribute(index, 'value', e.target.value)}
              className="flex-1 px-4 py-2 bg-gray-700 rounded-lg text-white"
              placeholder="Value"
            />
          </div>
        ))}
        <button
          type="button"
          onClick={addAttribute}
          className="text-sm text-blue-500 hover:text-blue-400"
        >
          + Add Attribute
        </button>
      </div>

      {/* Submit */}
      <Button
        onClick={handleMint}
        disabled={isPending || isConfirming || isUploading}
        className="w-full"
      >
        {step === 'uploading'
          ? 'Uploading to IPFS...'
          : step === 'minting'
          ? 'Minting...'
          : 'Mint NFT'}
      </Button>

      {error && <p className="text-sm text-red-500">{error}</p>}
    </div>
  );
}
```

## Lending Components

File: `frontend/components/lending/LoanCard.tsx`

```tsx
'use client';

import { formatEther } from 'viem';
import { useAccount } from 'wagmi';
import { useBorrow, useRepayLoan } from '@/hooks/useLending';
import { Button } from '@/components/common/Button';

interface LoanCardProps {
  loanId?: bigint;
  offerId?: bigint;
  principal: bigint;
  interestRateBps: bigint;
  duration: bigint;
  status?: 'active' | 'available';
  nftContract?: `0x${string}`;
  tokenId?: bigint;
  outstandingBalance?: bigint;
  lendingAddress: `0x${string}`;
}

export function LoanCard({
  loanId,
  offerId,
  principal,
  interestRateBps,
  duration,
  status = 'available',
  nftContract,
  tokenId,
  outstandingBalance,
  lendingAddress,
}: LoanCardProps) {
  const { address } = useAccount();
  const { borrow, isPending: isBorrowing } = useBorrow();
  const { repay, isPending: isRepaying } = useRepayLoan();

  const interestRate = Number(interestRateBps) / 100;
  const durationDays = Number(duration) / (24 * 60 * 60);

  const handleBorrow = async () => {
    if (!offerId || !nftContract || !tokenId) return;
    await borrow(lendingAddress, offerId, nftContract, tokenId);
  };

  const handleRepay = async () => {
    if (!loanId || !outstandingBalance) return;
    await repay(lendingAddress, loanId, outstandingBalance);
  };

  return (
    <div className="rounded-xl bg-gray-800 p-6">
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="text-lg font-semibold text-white">
            {status === 'active' ? `Loan #${loanId}` : `Offer #${offerId}`}
          </h3>
          <span
            className={`text-xs px-2 py-1 rounded ${
              status === 'active'
                ? 'bg-green-500/20 text-green-400'
                : 'bg-blue-500/20 text-blue-400'
            }`}
          >
            {status === 'active' ? 'Active Loan' : 'Available'}
          </span>
        </div>
      </div>

      <div className="space-y-3 text-sm">
        <div className="flex justify-between">
          <span className="text-gray-400">Principal</span>
          <span className="text-white font-medium">
            {formatEther(principal)} ETH
          </span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-400">Interest Rate</span>
          <span className="text-white">{interestRate}% APR</span>
        </div>

        <div className="flex justify-between">
          <span className="text-gray-400">Duration</span>
          <span className="text-white">{durationDays} days</span>
        </div>

        {outstandingBalance && (
          <div className="flex justify-between pt-3 border-t border-gray-700">
            <span className="text-gray-400">Outstanding</span>
            <span className="text-white font-bold">
              {formatEther(outstandingBalance)} ETH
            </span>
          </div>
        )}
      </div>

      <div className="mt-6">
        {status === 'available' && (
          <Button onClick={handleBorrow} disabled={isBorrowing} className="w-full">
            {isBorrowing ? 'Borrowing...' : 'Borrow'}
          </Button>
        )}

        {status === 'active' && (
          <Button onClick={handleRepay} disabled={isRepaying} className="w-full">
            {isRepaying ? 'Repaying...' : 'Repay Loan'}
          </Button>
        )}
      </div>
    </div>
  );
}
```

## Common Components

File: `frontend/components/common/Button.tsx`

```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
}

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  className = '',
  disabled,
  ...props
}: ButtonProps) {
  const baseStyles = 'font-semibold rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  const variants = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500',
    secondary: 'bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500',
    outline: 'border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white focus:ring-blue-500',
  };

  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2',
    lg: 'px-6 py-3 text-lg',
  };

  return (
    <button
      className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`}
      disabled={disabled}
      {...props}
    >
      {children}
    </button>
  );
}
```

File: `frontend/components/common/Modal.tsx`

```tsx
'use client';

import { useEffect } from 'react';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
}

export function Modal({ isOpen, onClose, title, children }: ModalProps) {
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="absolute inset-0 bg-black/70"
        onClick={onClose}
      />
      <div className="relative bg-gray-800 rounded-xl max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto">
        {title && (
          <div className="flex items-center justify-between p-4 border-b border-gray-700">
            <h2 className="text-xl font-bold text-white">{title}</h2>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-white text-2xl"
            >
              ×
            </button>
          </div>
        )}
        <div className="p-6">{children}</div>
      </div>
    </div>
  );
}
```

---
