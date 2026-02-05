# Minting Strategies

Advanced minting patterns: lazy minting, Merkle allowlists, gasless transactions (ERC-2771), commit-reveal anti-bot, Dutch auctions, and VRF raffle minting.

---

# MODULE 37: LAZY MINTING

## Lazy Mint Contract

File: `contracts/lazy/LazyMintNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title LazyMintNFT
 * @notice NFT contract with lazy minting - mint on first purchase
 * @dev Creator signs voucher off-chain, buyer mints + pays in single transaction
 */
contract LazyMintNFT is
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC2981Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using Address for address payable;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // EIP-712 domain
    bytes32 private constant VOUCHER_TYPEHASH = keccak256(
        "NFTVoucher(uint256 tokenId,string uri,uint256 minPrice,address creator,uint96 royaltyBps,uint256 deadline)"
    );
    bytes32 private DOMAIN_SEPARATOR;

    // Voucher tracking
    mapping(uint256 => bool) public voucherRedeemed;
    mapping(address => uint256) public creatorBalance;

    // Platform fee
    address public feeRecipient;
    uint256 public platformFeeBps; // Basis points (100 = 1%)

    struct NFTVoucher {
        uint256 tokenId;
        string uri;
        uint256 minPrice;
        address creator;
        uint96 royaltyBps;
        uint256 deadline;
        bytes signature;
    }

    event VoucherRedeemed(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed creator,
        uint256 price
    );
    event CreatorWithdrawal(address indexed creator, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address _feeRecipient,
        uint256 _platformFeeBps
    ) external initializer {
        __ERC721_init(name, symbol);
        __ERC721URIStorage_init();
        __ERC2981_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        feeRecipient = _feeRecipient;
        platformFeeBps = _platformFeeBps;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Redeem voucher and mint NFT
     * @dev Buyer calls this with payment, creator receives funds minus platform fee
     */
    function redeemVoucher(NFTVoucher calldata voucher)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        // Validate voucher
        require(!voucherRedeemed[voucher.tokenId], "Voucher already redeemed");
        require(block.timestamp <= voucher.deadline, "Voucher expired");
        require(msg.value >= voucher.minPrice, "Insufficient payment");

        // Verify signature
        address signer = _verifyVoucher(voucher);
        require(signer == voucher.creator, "Invalid signature");
        require(
            hasRole(MINTER_ROLE, signer) || hasRole(DEFAULT_ADMIN_ROLE, signer),
            "Creator not authorized"
        );

        // Mark voucher as redeemed
        voucherRedeemed[voucher.tokenId] = true;

        // Mint NFT to buyer
        _safeMint(msg.sender, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // Set royalty
        if (voucher.royaltyBps > 0) {
            _setTokenRoyalty(voucher.tokenId, voucher.creator, voucher.royaltyBps);
        }

        // Distribute payment
        uint256 platformFee = (msg.value * platformFeeBps) / 10000;
        uint256 creatorPayment = msg.value - platformFee;

        if (platformFee > 0) {
            Address.sendValue(payable(feeRecipient), platformFee);
        }
        creatorBalance[voucher.creator] += creatorPayment;

        emit VoucherRedeemed(voucher.tokenId, msg.sender, voucher.creator, msg.value);

        return voucher.tokenId;
    }

    /**
     * @notice Creator withdraws accumulated earnings
     */
    function withdrawCreatorBalance() external nonReentrant {
        uint256 balance = creatorBalance[msg.sender];
        require(balance > 0, "No balance");

        creatorBalance[msg.sender] = 0;
        Address.sendValue(payable(msg.sender), balance);

        emit CreatorWithdrawal(msg.sender, balance);
    }

    /**
     * @notice Verify voucher signature
     */
    function _verifyVoucher(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                VOUCHER_TYPEHASH,
                voucher.tokenId,
                keccak256(bytes(voucher.uri)),
                voucher.minPrice,
                voucher.creator,
                voucher.royaltyBps,
                voucher.deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        return digest.recover(voucher.signature);
    }

    /**
     * @notice Check if voucher is valid
     */
    function isVoucherValid(NFTVoucher calldata voucher) external view returns (bool, string memory) {
        if (voucherRedeemed[voucher.tokenId]) {
            return (false, "Voucher already redeemed");
        }
        if (block.timestamp > voucher.deadline) {
            return (false, "Voucher expired");
        }

        address signer = _verifyVoucher(voucher);
        if (signer != voucher.creator) {
            return (false, "Invalid signature");
        }
        if (!hasRole(MINTER_ROLE, signer) && !hasRole(DEFAULT_ADMIN_ROLE, signer)) {
            return (false, "Creator not authorized");
        }

        return (true, "Valid");
    }

    /**
     * @notice Get domain separator for signing
     */
    function getDomainSeparator() external view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    /**
     * @notice Get voucher type hash for signing
     */
    function getVoucherTypeHash() external pure returns (bytes32) {
        return VOUCHER_TYPEHASH;
    }

    // ==================== Admin Functions ====================

    function setPlatformFee(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeBps <= 1000, "Fee too high"); // Max 10%
        platformFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_recipient != address(0), "Invalid address");
        feeRecipient = _recipient;
    }

    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // ==================== Overrides ====================

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC2981Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }
}
```

## Voucher Signing Utility

File: `sdk/src/utils/lazyMint.ts`

```typescript
import { TypedDataDomain, TypedDataField } from 'viem';

export interface NFTVoucher {
  tokenId: bigint;
  uri: string;
  minPrice: bigint;
  creator: `0x${string}`;
  royaltyBps: number;
  deadline: bigint;
}

export const VOUCHER_TYPES: Record<string, TypedDataField[]> = {
  NFTVoucher: [
    { name: 'tokenId', type: 'uint256' },
    { name: 'uri', type: 'string' },
    { name: 'minPrice', type: 'uint256' },
    { name: 'creator', type: 'address' },
    { name: 'royaltyBps', type: 'uint96' },
    { name: 'deadline', type: 'uint256' },
  ],
};

export function createVoucherDomain(
  name: string,
  contractAddress: `0x${string}`,
  chainId: number
): TypedDataDomain {
  return {
    name,
    version: '1',
    chainId,
    verifyingContract: contractAddress,
  };
}

export async function signVoucher(
  walletClient: any,
  domain: TypedDataDomain,
  voucher: NFTVoucher
): Promise<`0x${string}`> {
  return walletClient.signTypedData({
    domain,
    types: VOUCHER_TYPES,
    primaryType: 'NFTVoucher',
    message: voucher,
  });
}

export function createVoucher(
  tokenId: bigint,
  uri: string,
  minPrice: bigint,
  creator: `0x${string}`,
  royaltyBps: number,
  daysValid: number = 30
): NFTVoucher {
  const deadline = BigInt(Math.floor(Date.now() / 1000) + daysValid * 24 * 60 * 60);

  return {
    tokenId,
    uri,
    minPrice,
    creator,
    royaltyBps,
    deadline,
  };
}
```

---

# MODULE 38: MERKLE ALLOWLIST & AIRDROPS

## Merkle Distributor Contract

File: `contracts/merkle/MerkleDistributor.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MerkleDistributor
 * @notice Merkle tree based token airdrop distribution
 */
contract MerkleDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public merkleRoot;

    // Claimed status
    mapping(uint256 => uint256) private claimedBitMap;

    // Claim deadline
    uint256 public claimDeadline;

    event Claimed(uint256 indexed index, address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event DeadlineExtended(uint256 newDeadline);

    constructor(address _token, bytes32 _merkleRoot, uint256 _claimDeadline) Ownable(msg.sender) {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        claimDeadline = _claimDeadline;
    }

    /**
     * @notice Check if index has been claimed
     */
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
     * @notice Mark index as claimed
     */
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] |= (1 << claimedBitIndex);
    }

    /**
     * @notice Claim airdrop tokens
     */
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(block.timestamp <= claimDeadline, "Claim period ended");
        require(!isClaimed(index), "Already claimed");

        // Verify proof
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof");

        // Mark as claimed and transfer
        _setClaimed(index);
        token.safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    /**
     * @notice Batch claim for multiple addresses (admin function for gas sponsorship)
     */
    function batchClaim(
        uint256[] calldata indices,
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes32[][] calldata merkleProofs
    ) external nonReentrant {
        require(block.timestamp <= claimDeadline, "Claim period ended");
        require(
            indices.length == accounts.length &&
            accounts.length == amounts.length &&
            amounts.length == merkleProofs.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < indices.length; i++) {
            if (isClaimed(indices[i])) continue;

            bytes32 node = keccak256(abi.encodePacked(indices[i], accounts[i], amounts[i]));
            if (!MerkleProof.verify(merkleProofs[i], merkleRoot, node)) continue;

            _setClaimed(indices[i]);
            token.safeTransfer(accounts[i], amounts[i]);

            emit Claimed(indices[i], accounts[i], amounts[i]);
        }
    }

    // ==================== Admin Functions ====================

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        emit MerkleRootUpdated(merkleRoot, _merkleRoot);
        merkleRoot = _merkleRoot;
    }

    function extendDeadline(uint256 _newDeadline) external onlyOwner {
        require(_newDeadline > claimDeadline, "Must extend");
        claimDeadline = _newDeadline;
        emit DeadlineExtended(_newDeadline);
    }

    function withdrawUnclaimed() external onlyOwner {
        require(block.timestamp > claimDeadline, "Claim period not ended");
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(owner(), balance);
    }
}
```

## NFT Allowlist Mint Contract

File: `contracts/merkle/AllowlistMint.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title AllowlistMint
 * @notice NFT with Merkle tree based allowlist for presale
 */
contract AllowlistMint is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;

    // Merkle roots for different tiers
    bytes32 public ogMerkleRoot;      // OG list
    bytes32 public whitelistRoot;     // Whitelist
    bytes32 public publicRoot;        // Public (optional verification)

    // Prices per tier
    uint256 public ogPrice;
    uint256 public whitelistPrice;
    uint256 public publicPrice;

    // Max mints per tier
    uint256 public ogMaxMint = 3;
    uint256 public whitelistMaxMint = 2;
    uint256 public publicMaxMint = 5;

    // Supply
    uint256 public maxSupply;
    uint256 public totalMinted;

    // Sale phases
    enum Phase { CLOSED, OG, WHITELIST, PUBLIC }
    Phase public currentPhase;

    // Tracking mints
    mapping(address => uint256) public ogMinted;
    mapping(address => uint256) public whitelistMinted;
    mapping(address => uint256) public publicMinted;

    // Metadata
    string private _baseTokenURI;
    bool public revealed;

    event PhaseChanged(Phase newPhase);
    event Minted(address indexed to, uint256 indexed tokenId, Phase phase);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _ogPrice,
        uint256 _whitelistPrice,
        uint256 _publicPrice
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        ogPrice = _ogPrice;
        whitelistPrice = _whitelistPrice;
        publicPrice = _publicPrice;
    }

    /**
     * @notice OG mint with merkle proof
     */
    function ogMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        nonReentrant
    {
        require(currentPhase == Phase.OG, "OG sale not active");
        require(ogMinted[msg.sender] + quantity <= ogMaxMint, "Exceeds max");
        require(totalMinted + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= ogPrice * quantity, "Insufficient payment");

        // Verify proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, ogMerkleRoot, leaf), "Invalid proof");

        ogMinted[msg.sender] += quantity;
        _mintBatch(msg.sender, quantity, Phase.OG);
    }

    /**
     * @notice Whitelist mint with merkle proof
     */
    function whitelistMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        nonReentrant
    {
        require(currentPhase == Phase.WHITELIST || currentPhase == Phase.OG, "WL sale not active");
        require(whitelistMinted[msg.sender] + quantity <= whitelistMaxMint, "Exceeds max");
        require(totalMinted + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= whitelistPrice * quantity, "Insufficient payment");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, whitelistRoot, leaf), "Invalid proof");

        whitelistMinted[msg.sender] += quantity;
        _mintBatch(msg.sender, quantity, Phase.WHITELIST);
    }

    /**
     * @notice Public mint
     */
    function publicMint(uint256 quantity)
        external
        payable
        nonReentrant
    {
        require(currentPhase == Phase.PUBLIC, "Public sale not active");
        require(publicMinted[msg.sender] + quantity <= publicMaxMint, "Exceeds max");
        require(totalMinted + quantity <= maxSupply, "Exceeds supply");
        require(msg.value >= publicPrice * quantity, "Insufficient payment");

        publicMinted[msg.sender] += quantity;
        _mintBatch(msg.sender, quantity, Phase.PUBLIC);
    }

    /**
     * @notice Check if address is on OG list
     */
    function isOG(address account, bytes32[] calldata proof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, ogMerkleRoot, leaf);
    }

    /**
     * @notice Check if address is on whitelist
     */
    function isWhitelisted(address account, bytes32[] calldata proof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, whitelistRoot, leaf);
    }

    /**
     * @notice Internal batch mint
     */
    function _mintBatch(address to, uint256 quantity, Phase phase) internal {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = ++totalMinted;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId, phase);
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        if (!revealed) {
            return string(abi.encodePacked(_baseTokenURI, "hidden.json"));
        }

        return string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId), ".json"));
    }

    // ==================== Admin Functions ====================

    function setPhase(Phase _phase) external onlyOwner {
        currentPhase = _phase;
        emit PhaseChanged(_phase);
    }

    function setOGMerkleRoot(bytes32 _root) external onlyOwner {
        ogMerkleRoot = _root;
    }

    function setWhitelistRoot(bytes32 _root) external onlyOwner {
        whitelistRoot = _root;
    }

    function setPrices(uint256 _og, uint256 _wl, uint256 _public) external onlyOwner {
        ogPrice = _og;
        whitelistPrice = _wl;
        publicPrice = _public;
    }

    function setMaxMints(uint256 _og, uint256 _wl, uint256 _public) external onlyOwner {
        ogMaxMint = _og;
        whitelistMaxMint = _wl;
        publicMaxMint = _public;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function withdraw() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }
}
```

## Merkle Tree Generator

File: `scripts/generateMerkleTree.ts`

```typescript
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import * as fs from 'fs';

interface AirdropEntry {
  index: number;
  address: string;
  amount: string;
}

interface AllowlistEntry {
  address: string;
}

/**
 * Generate Merkle tree for token airdrop
 */
export function generateAirdropTree(entries: AirdropEntry[]) {
  const values = entries.map((e) => [e.index, e.address, e.amount]);

  const tree = StandardMerkleTree.of(values, ['uint256', 'address', 'uint256']);

  console.log('Merkle Root:', tree.root);

  // Generate proofs for each entry
  const proofs: Record<string, { proof: string[]; amount: string; index: number }> = {};

  for (const [i, v] of tree.entries()) {
    const address = v[1] as string;
    proofs[address.toLowerCase()] = {
      proof: tree.getProof(i),
      amount: v[2] as string,
      index: v[0] as number,
    };
  }

  return { root: tree.root, proofs, tree };
}

/**
 * Generate Merkle tree for NFT allowlist
 */
export function generateAllowlistTree(addresses: string[]) {
  const values = addresses.map((addr) => [addr]);

  const tree = StandardMerkleTree.of(values, ['address']);

  console.log('Merkle Root:', tree.root);

  // Generate proofs
  const proofs: Record<string, string[]> = {};

  for (const [i, v] of tree.entries()) {
    const address = v[0] as string;
    proofs[address.toLowerCase()] = tree.getProof(i);
  }

  return { root: tree.root, proofs, tree };
}

/**
 * Example usage
 */
async function main() {
  // Airdrop example
  const airdropData: AirdropEntry[] = [
    { index: 0, address: '0x1111111111111111111111111111111111111111', amount: '1000000000000000000000' },
    { index: 1, address: '0x2222222222222222222222222222222222222222', amount: '500000000000000000000' },
    { index: 2, address: '0x3333333333333333333333333333333333333333', amount: '250000000000000000000' },
  ];

  const airdrop = generateAirdropTree(airdropData);
  fs.writeFileSync('airdrop-proofs.json', JSON.stringify(airdrop.proofs, null, 2));
  console.log('Airdrop root:', airdrop.root);

  // Allowlist example
  const allowlistAddresses = [
    '0x1111111111111111111111111111111111111111',
    '0x2222222222222222222222222222222222222222',
    '0x3333333333333333333333333333333333333333',
  ];

  const allowlist = generateAllowlistTree(allowlistAddresses);
  fs.writeFileSync('allowlist-proofs.json', JSON.stringify(allowlist.proofs, null, 2));
  console.log('Allowlist root:', allowlist.root);
}

main().catch(console.error);
```

---

# MODULE 39: GASLESS TRANSACTIONS (ERC-2771)

## Trusted Forwarder

File: `contracts/gasless/TrustedForwarder.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title TrustedForwarder
 * @notice ERC-2771 compatible forwarder for gasless transactions
 */
contract TrustedForwarder is EIP712, Ownable {
    using ECDSA for bytes32;
    using Address for address payable;

    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        uint256 deadline;
        bytes data;
    }

    bytes32 private constant _TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint256 deadline,bytes data)"
    );

    mapping(address => uint256) private _nonces;

    // Relayer whitelist (optional)
    mapping(address => bool) public trustedRelayers;
    bool public relayerWhitelistEnabled;

    event Executed(address indexed from, address indexed to, bool success, bytes returnData);
    event RelayerUpdated(address indexed relayer, bool trusted);

    constructor() EIP712("TrustedForwarder", "1") Ownable(msg.sender) {}

    /**
     * @notice Get nonce for an address
     */
    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    /**
     * @notice Verify a forward request
     */
    function verify(ForwardRequest calldata req, bytes calldata signature)
        public
        view
        returns (bool)
    {
        address signer = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    req.from,
                    req.to,
                    req.value,
                    req.gas,
                    req.nonce,
                    req.deadline,
                    keccak256(req.data)
                )
            )
        ).recover(signature);

        return
            signer == req.from &&
            _nonces[req.from] == req.nonce &&
            block.timestamp <= req.deadline;
    }

    /**
     * @notice Execute a forward request
     */
    function execute(ForwardRequest calldata req, bytes calldata signature)
        public
        payable
        returns (bool, bytes memory)
    {
        // Check relayer whitelist if enabled
        if (relayerWhitelistEnabled) {
            require(trustedRelayers[msg.sender], "Relayer not trusted");
        }

        require(verify(req, signature), "Invalid signature");
        _nonces[req.from]++;

        // Append sender address to calldata for ERC-2771
        (bool success, bytes memory returnData) = req.to.call{gas: req.gas, value: req.value}(
            abi.encodePacked(req.data, req.from)
        );

        // Validate gas was sufficient
        if (!success) {
            assembly {
                // Check if out of gas
                if iszero(returndatasize()) {
                    // Likely out of gas, revert with message
                    mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(4, 32)
                    mstore(36, 11)
                    mstore(68, "Out of gas")
                    revert(0, 100)
                }
            }
        }

        emit Executed(req.from, req.to, success, returnData);

        return (success, returnData);
    }

    /**
     * @notice Execute batch of forward requests
     */
    function executeBatch(
        ForwardRequest[] calldata requests,
        bytes[] calldata signatures
    ) external payable returns (bool[] memory successes, bytes[] memory results) {
        require(requests.length == signatures.length, "Length mismatch");

        successes = new bool[](requests.length);
        results = new bytes[](requests.length);

        for (uint256 i = 0; i < requests.length; i++) {
            (successes[i], results[i]) = execute(requests[i], signatures[i]);
        }
    }

    // ==================== Admin Functions ====================

    function setTrustedRelayer(address relayer, bool trusted) external onlyOwner {
        trustedRelayers[relayer] = trusted;
        emit RelayerUpdated(relayer, trusted);
    }

    function setRelayerWhitelistEnabled(bool enabled) external onlyOwner {
        relayerWhitelistEnabled = enabled;
    }

    function withdrawFees() external onlyOwner {
        Address.sendValue(payable(owner()), address(this).balance);
    }

    receive() external payable {}
}
```

## ERC-2771 Context for Recipient Contracts

File: `contracts/gasless/ERC2771Context.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC2771Context
 * @notice Base contract for ERC-2771 meta-transaction recipients
 */
abstract contract ERC2771Context {
    address private immutable _trustedForwarder;

    constructor(address trustedForwarder_) {
        _trustedForwarder = trustedForwarder_;
    }

    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual returns (address sender) {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            // Extract sender from calldata (last 20 bytes)
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = msg.sender;
        }
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            return msg.data[:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}
```

## Gasless NFT Contract

File: `contracts/gasless/GaslessNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2771Context.sol";

/**
 * @title GaslessNFT
 * @notice NFT contract supporting gasless transactions via ERC-2771
 */
contract GaslessNFT is ERC721, Ownable, ERC2771Context {
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        address trustedForwarder
    ) ERC721(name, symbol) Ownable(msg.sender) ERC2771Context(trustedForwarder) {}

    /**
     * @notice Mint NFT (gasless compatible)
     */
    function mint(address to) external returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Safe transfer (gasless compatible)
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Not approved or owner"
        );
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @notice Approve (gasless compatible)
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "Approval to current owner");
        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "Not authorized"
        );
        _approve(to, tokenId, _msgSender());
    }

    /**
     * @notice Set approval for all (gasless compatible)
     */
    function setApprovalForAll(address operator, bool approved) public override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Override _msgSender and _msgData to use ERC2771Context
    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }
}
```

## Relayer Service

File: `backend/src/services/relayer.ts`

```typescript
import { createWalletClient, createPublicClient, http, encodeFunctionData } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { mainnet } from 'viem/chains';

const FORWARDER_ABI = [
  {
    inputs: [
      {
        components: [
          { name: 'from', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'gas', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
        name: 'req',
        type: 'tuple',
      },
      { name: 'signature', type: 'bytes' },
    ],
    name: 'execute',
    outputs: [
      { name: '', type: 'bool' },
      { name: '', type: 'bytes' },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [{ name: 'from', type: 'address' }],
    name: 'getNonce',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
];

interface ForwardRequest {
  from: `0x${string}`;
  to: `0x${string}`;
  value: bigint;
  gas: bigint;
  nonce: bigint;
  deadline: bigint;
  data: `0x${string}`;
}

export class RelayerService {
  private walletClient;
  private publicClient;
  private forwarderAddress: `0x${string}`;

  constructor(
    rpcUrl: string,
    relayerPrivateKey: `0x${string}`,
    forwarderAddress: `0x${string}`
  ) {
    const account = privateKeyToAccount(relayerPrivateKey);

    this.publicClient = createPublicClient({
      chain: mainnet,
      transport: http(rpcUrl),
    });

    this.walletClient = createWalletClient({
      chain: mainnet,
      transport: http(rpcUrl),
      account,
    });

    this.forwarderAddress = forwarderAddress;
  }

  /**
   * Get nonce for user
   */
  async getNonce(userAddress: `0x${string}`): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.forwarderAddress,
      abi: FORWARDER_ABI,
      functionName: 'getNonce',
      args: [userAddress],
    }) as Promise<bigint>;
  }

  /**
   * Relay a signed forward request
   */
  async relay(request: ForwardRequest, signature: `0x${string}`) {
    // Estimate gas
    const gasEstimate = await this.publicClient.estimateGas({
      account: this.walletClient.account,
      to: this.forwarderAddress,
      data: encodeFunctionData({
        abi: FORWARDER_ABI,
        functionName: 'execute',
        args: [request, signature],
      }),
    });

    // Execute with buffer
    const hash = await this.walletClient.writeContract({
      address: this.forwarderAddress,
      abi: FORWARDER_ABI,
      functionName: 'execute',
      args: [request, signature],
      gas: (gasEstimate * 120n) / 100n, // 20% buffer
    });

    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    return {
      hash,
      success: receipt.status === 'success',
      gasUsed: receipt.gasUsed,
    };
  }

  /**
   * Check if relay would succeed
   */
  async simulateRelay(request: ForwardRequest, signature: `0x${string}`) {
    try {
      await this.publicClient.simulateContract({
        address: this.forwarderAddress,
        abi: FORWARDER_ABI,
        functionName: 'execute',
        args: [request, signature],
        account: this.walletClient.account,
      });
      return { success: true, error: null };
    } catch (error: any) {
      return { success: false, error: error.message };
    }
  }
}
```

---

# MODULE 47: COMMIT-REVEAL MINTING (ANTI-BOT)

## Commit-Reveal Mint Contract

File: `contracts/minting/CommitRevealMint.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title CommitRevealMint
 * @notice Anti-bot minting using commit-reveal scheme
 */
contract CommitRevealMint is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;

    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    // Commit-reveal parameters
    uint256 public commitWindow = 1 hours;
    uint256 public revealWindow = 2 hours;
    uint256 public maxCommitsPerAddress = 3;

    // Commit storage
    mapping(bytes32 => Commit) public commits;
    mapping(address => uint256) public commitCount;
    mapping(address => bytes32[]) public userCommits;

    struct Commit {
        address committer;
        uint256 amount;
        uint256 timestamp;
        bool revealed;
    }

    // Minting phases
    enum Phase { Closed, Commit, Reveal, Open }
    Phase public currentPhase;
    uint256 public phaseStartTime;

    string private _baseTokenURI;

    event Committed(address indexed user, bytes32 indexed commitHash, uint256 amount);
    event Revealed(address indexed user, bytes32 indexed commitHash, uint256 startTokenId, uint256 amount);
    event PhaseChanged(Phase phase);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        currentPhase = Phase.Closed;
    }

    /**
     * @notice Commit to mint (Phase 1)
     * @param commitHash keccak256(abi.encodePacked(sender, amount, secret))
     */
    function commit(bytes32 commitHash, uint256 amount) external payable nonReentrant {
        require(currentPhase == Phase.Commit, "Not in commit phase");
        require(block.timestamp < phaseStartTime + commitWindow, "Commit window closed");
        require(amount > 0 && amount <= 5, "Invalid amount");
        require(commitCount[msg.sender] < maxCommitsPerAddress, "Too many commits");
        require(msg.value == mintPrice * amount, "Wrong payment");
        require(commits[commitHash].committer == address(0), "Commit exists");

        commits[commitHash] = Commit({
            committer: msg.sender,
            amount: amount,
            timestamp: block.timestamp,
            revealed: false
        });

        commitCount[msg.sender]++;
        userCommits[msg.sender].push(commitHash);

        emit Committed(msg.sender, commitHash, amount);
    }

    /**
     * @notice Reveal commit and mint (Phase 2)
     * @param amount Same amount used in commit
     * @param secret Secret used in commit hash
     */
    function reveal(uint256 amount, bytes32 secret) external nonReentrant {
        require(currentPhase == Phase.Reveal, "Not in reveal phase");
        require(
            block.timestamp >= phaseStartTime + commitWindow &&
            block.timestamp < phaseStartTime + commitWindow + revealWindow,
            "Not in reveal window"
        );

        bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, amount, secret));
        Commit storage userCommit = commits[commitHash];

        require(userCommit.committer == msg.sender, "Invalid commit");
        require(!userCommit.revealed, "Already revealed");
        require(userCommit.amount == amount, "Amount mismatch");
        require(_tokenIdCounter + amount <= maxSupply, "Exceeds supply");

        userCommit.revealed = true;

        uint256 startTokenId = _tokenIdCounter + 1;

        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter++;
            _safeMint(msg.sender, _tokenIdCounter);
        }

        emit Revealed(msg.sender, commitHash, startTokenId, amount);
    }

    /**
     * @notice Refund unrevealed commits
     */
    function refundUnrevealed(bytes32 commitHash) external nonReentrant {
        require(
            currentPhase == Phase.Open ||
            block.timestamp > phaseStartTime + commitWindow + revealWindow,
            "Reveal not ended"
        );

        Commit storage userCommit = commits[commitHash];
        require(userCommit.committer == msg.sender, "Not your commit");
        require(!userCommit.revealed, "Already revealed");

        uint256 refundAmount = mintPrice * userCommit.amount;
        delete commits[commitHash];

        Address.sendValue(payable(msg.sender), refundAmount);
    }

    /**
     * @notice Generate commit hash (view helper)
     */
    function generateCommitHash(
        address user,
        uint256 amount,
        bytes32 secret
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amount, secret));
    }

    /**
     * @notice Get user's commits
     */
    function getUserCommits(address user) external view returns (bytes32[] memory) {
        return userCommits[user];
    }

    // ==================== Phase Management ====================

    function startCommitPhase() external onlyOwner {
        require(currentPhase == Phase.Closed, "Already started");
        currentPhase = Phase.Commit;
        phaseStartTime = block.timestamp;
        emit PhaseChanged(Phase.Commit);
    }

    function advanceToReveal() external onlyOwner {
        require(currentPhase == Phase.Commit, "Not in commit phase");
        require(block.timestamp >= phaseStartTime + commitWindow, "Commit window not ended");
        currentPhase = Phase.Reveal;
        emit PhaseChanged(Phase.Reveal);
    }

    function advanceToOpen() external onlyOwner {
        require(currentPhase == Phase.Reveal, "Not in reveal phase");
        currentPhase = Phase.Open;
        emit PhaseChanged(Phase.Open);
    }

    function closeMint() external onlyOwner {
        currentPhase = Phase.Closed;
        emit PhaseChanged(Phase.Closed);
    }

    // ==================== Admin ====================

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

# MODULE 48: DUTCH AUCTION MINTING

## Dutch Auction Contract

File: `contracts/minting/DutchAuctionMint.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title DutchAuctionMint
 * @notice NFT minting with descending price auction
 */
contract DutchAuctionMint is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;

    uint256 private _tokenIdCounter;

    // Auction parameters
    uint256 public startPrice;
    uint256 public endPrice;
    uint256 public priceDecrement;
    uint256 public decrementInterval;
    uint256 public auctionStartTime;
    uint256 public auctionDuration;

    // Supply
    uint256 public maxSupply;
    uint256 public maxPerWallet;

    // Refund tracking (for rebate model)
    mapping(address => uint256) public totalPaid;
    mapping(address => uint256) public mintCount;
    uint256 public finalPrice;
    bool public auctionFinalized;

    string private _baseTokenURI;

    event AuctionStarted(uint256 startPrice, uint256 endPrice, uint256 duration);
    event Minted(address indexed minter, uint256 tokenId, uint256 price);
    event AuctionFinalized(uint256 finalPrice);
    event Refunded(address indexed user, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _maxPerWallet
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        maxPerWallet = _maxPerWallet;
    }

    /**
     * @notice Start the Dutch auction
     */
    function startAuction(
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _priceDecrement,
        uint256 _decrementInterval,
        uint256 _duration
    ) external onlyOwner {
        require(auctionStartTime == 0, "Auction already configured");
        require(_startPrice > _endPrice, "Invalid prices");
        require(_priceDecrement > 0, "Invalid decrement");

        startPrice = _startPrice;
        endPrice = _endPrice;
        priceDecrement = _priceDecrement;
        decrementInterval = _decrementInterval;
        auctionDuration = _duration;
        auctionStartTime = block.timestamp;

        emit AuctionStarted(_startPrice, _endPrice, _duration);
    }

    /**
     * @notice Get current auction price
     */
    function getCurrentPrice() public view returns (uint256) {
        if (auctionStartTime == 0) return startPrice;
        if (auctionFinalized) return finalPrice;

        uint256 elapsed = block.timestamp - auctionStartTime;

        if (elapsed >= auctionDuration) {
            return endPrice;
        }

        uint256 decrements = elapsed / decrementInterval;
        uint256 reduction = decrements * priceDecrement;

        if (reduction >= startPrice - endPrice) {
            return endPrice;
        }

        return startPrice - reduction;
    }

    /**
     * @notice Mint during auction
     */
    function mint(uint256 quantity) external payable nonReentrant {
        require(auctionStartTime > 0, "Auction not started");
        require(!auctionFinalized, "Auction ended");
        require(block.timestamp < auctionStartTime + auctionDuration, "Auction ended");
        require(quantity > 0, "Invalid quantity");
        require(_tokenIdCounter + quantity <= maxSupply, "Exceeds supply");
        require(mintCount[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");

        uint256 price = getCurrentPrice();
        uint256 totalCost = price * quantity;
        require(msg.value >= totalCost, "Insufficient payment");

        mintCount[msg.sender] += quantity;
        totalPaid[msg.sender] += msg.value;

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter++;
            _safeMint(msg.sender, _tokenIdCounter);
            emit Minted(msg.sender, _tokenIdCounter, price);
        }

        // Refund excess
        if (msg.value > totalCost) {
            Address.sendValue(payable(msg.sender), msg.value - totalCost);
        }
    }

    /**
     * @notice Finalize auction and set final price for rebates
     */
    function finalizeAuction() external onlyOwner {
        require(!auctionFinalized, "Already finalized");
        require(
            _tokenIdCounter >= maxSupply ||
            block.timestamp >= auctionStartTime + auctionDuration,
            "Auction ongoing"
        );

        finalPrice = getCurrentPrice();
        auctionFinalized = true;

        emit AuctionFinalized(finalPrice);
    }

    /**
     * @notice Claim rebate (difference between paid and final price)
     */
    function claimRebate() external nonReentrant {
        require(auctionFinalized, "Auction not finalized");

        uint256 paid = totalPaid[msg.sender];
        uint256 shouldHavePaid = mintCount[msg.sender] * finalPrice;

        require(paid > shouldHavePaid, "No rebate available");

        uint256 rebate = paid - shouldHavePaid;
        totalPaid[msg.sender] = shouldHavePaid;

        Address.sendValue(payable(msg.sender), rebate);

        emit Refunded(msg.sender, rebate);
    }

    /**
     * @notice Get rebate amount for address
     */
    function getRebateAmount(address user) external view returns (uint256) {
        if (!auctionFinalized) return 0;

        uint256 paid = totalPaid[user];
        uint256 shouldHavePaid = mintCount[user] * finalPrice;

        return paid > shouldHavePaid ? paid - shouldHavePaid : 0;
    }

    /**
     * @notice Check auction status
     */
    function getAuctionStatus()
        external
        view
        returns (
            bool started,
            bool ended,
            uint256 currentPrice,
            uint256 timeRemaining,
            uint256 minted
        )
    {
        started = auctionStartTime > 0;
        ended = auctionFinalized ||
            (started && block.timestamp >= auctionStartTime + auctionDuration);
        currentPrice = getCurrentPrice();
        timeRemaining = started && !ended
            ? (auctionStartTime + auctionDuration) - block.timestamp
            : 0;
        minted = _tokenIdCounter;
    }

    // ==================== Admin ====================

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw() external onlyOwner {
        require(auctionFinalized, "Finalize first");
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
```

---

# MODULE 49: RAFFLE MINTING SYSTEM

## NFT Raffle Contract

File: `contracts/minting/NFTRaffle.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title NFTRaffle
 * @notice Fair raffle system for NFT minting using Chainlink VRF
 */
contract NFTRaffle is ERC721, Ownable, ReentrancyGuard, VRFConsumerBaseV2 {
    using Address for address payable;

    VRFCoordinatorV2Interface immutable COORDINATOR;

    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public rafflePrice;
    uint256 public maxEntriesPerAddress;

    // VRF config
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;

    // Raffle state
    enum RaffleState { Closed, Open, Drawing, Complete }
    RaffleState public raffleState;

    // Entries
    address[] public entries;
    mapping(address => uint256) public entryCount;
    mapping(address => bool) public hasWon;
    mapping(address => bool) public hasClaimed;

    // Winners
    address[] public winners;
    uint256 public winnersCount;

    // VRF request
    uint256 public vrfRequestId;

    string private _baseTokenURI;

    event EntryPurchased(address indexed user, uint256 entries);
    event RaffleDrawn(uint256 requestId);
    event WinnersSelected(uint256 count);
    event PrizeClaimed(address indexed winner, uint256 tokenId);
    event EntryRefunded(address indexed user, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _rafflePrice,
        uint256 _maxEntries,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        ERC721(name, symbol)
        Ownable(msg.sender)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        maxSupply = _maxSupply;
        rafflePrice = _rafflePrice;
        maxEntriesPerAddress = _maxEntries;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        raffleState = RaffleState.Closed;
    }

    /**
     * @notice Purchase raffle entries
     */
    function buyEntries(uint256 numEntries) external payable nonReentrant {
        require(raffleState == RaffleState.Open, "Raffle not open");
        require(numEntries > 0, "Invalid entries");
        require(
            entryCount[msg.sender] + numEntries <= maxEntriesPerAddress,
            "Exceeds max entries"
        );
        require(msg.value == rafflePrice * numEntries, "Wrong payment");

        for (uint256 i = 0; i < numEntries; i++) {
            entries.push(msg.sender);
        }
        entryCount[msg.sender] += numEntries;

        emit EntryPurchased(msg.sender, numEntries);
    }

    /**
     * @notice Draw winners using Chainlink VRF
     */
    function drawWinners(uint256 _winnersCount) external onlyOwner {
        require(raffleState == RaffleState.Open, "Raffle not open");
        require(entries.length >= _winnersCount, "Not enough entries");
        require(_winnersCount <= maxSupply, "Too many winners");

        winnersCount = _winnersCount;
        raffleState = RaffleState.Drawing;

        vrfRequestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // Single random word, we'll derive multiple from it
        );

        emit RaffleDrawn(vrfRequestId);
    }

    /**
     * @notice VRF callback - select winners
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(requestId == vrfRequestId, "Wrong request");

        uint256 randomSeed = randomWords[0];

        // Fisher-Yates shuffle to select winners
        uint256 entriesLength = entries.length;
        address[] memory shuffled = entries;

        for (uint256 i = 0; i < winnersCount && i < entriesLength; i++) {
            uint256 j = i + (uint256(keccak256(abi.encode(randomSeed, i))) % (entriesLength - i));

            // Swap
            address temp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = temp;
        }

        // First winnersCount addresses are winners
        for (uint256 i = 0; i < winnersCount; i++) {
            address winner = shuffled[i];
            if (!hasWon[winner]) {
                winners.push(winner);
                hasWon[winner] = true;
            }
        }

        raffleState = RaffleState.Complete;

        emit WinnersSelected(winners.length);
    }

    /**
     * @notice Winners claim their NFT
     */
    function claimPrize() external nonReentrant {
        require(raffleState == RaffleState.Complete, "Raffle not complete");
        require(hasWon[msg.sender], "Not a winner");
        require(!hasClaimed[msg.sender], "Already claimed");

        hasClaimed[msg.sender] = true;
        _tokenIdCounter++;

        _safeMint(msg.sender, _tokenIdCounter);

        emit PrizeClaimed(msg.sender, _tokenIdCounter);
    }

    /**
     * @notice Non-winners can get refund
     */
    function claimRefund() external nonReentrant {
        require(raffleState == RaffleState.Complete, "Raffle not complete");
        require(!hasWon[msg.sender], "You won!");
        require(entryCount[msg.sender] > 0, "No entries");

        uint256 refundAmount = entryCount[msg.sender] * rafflePrice;
        entryCount[msg.sender] = 0;

        Address.sendValue(payable(msg.sender), refundAmount);

        emit EntryRefunded(msg.sender, refundAmount);
    }

    /**
     * @notice Get all winners
     */
    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    /**
     * @notice Get raffle stats
     */
    function getRaffleStats()
        external
        view
        returns (
            uint256 totalEntries,
            uint256 uniqueEntrants,
            uint256 prizePool
        )
    {
        totalEntries = entries.length;
        prizePool = address(this).balance;

        // Count unique (expensive, for view only)
        address[] memory seen = new address[](entries.length);
        uint256 count = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < count; j++) {
                if (seen[j] == entries[i]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                seen[count] = entries[i];
                count++;
            }
        }
        uniqueEntrants = count;
    }

    // ==================== Admin ====================

    function openRaffle() external onlyOwner {
        require(raffleState == RaffleState.Closed, "Already open");
        raffleState = RaffleState.Open;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw() external onlyOwner {
        require(raffleState == RaffleState.Complete, "Raffle not complete");
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
```

---
