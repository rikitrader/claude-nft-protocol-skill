# Social & Attestation

Ethereum Attestation Service (EAS) integration and on-chain curation/gallery system with curator profiles, exhibitions, and tipping.

---

# MODULE 67: ETHEREUM ATTESTATION SERVICE

## EAS Integration Contract

File: `contracts/attestation/EASIntegration.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// EAS Interfaces
interface IEAS {
    struct AttestationRequest {
        bytes32 schema;
        AttestationRequestData data;
    }

    struct AttestationRequestData {
        address recipient;
        uint64 expirationTime;
        bool revocable;
        bytes32 refUID;
        bytes data;
        uint256 value;
    }

    function attest(AttestationRequest calldata request) external payable returns (bytes32);
    function revoke(RevocationRequest calldata request) external payable;
    function getAttestation(bytes32 uid) external view returns (Attestation memory);

    struct RevocationRequest {
        bytes32 schema;
        RevocationRequestData data;
    }

    struct RevocationRequestData {
        bytes32 uid;
        uint256 value;
    }

    struct Attestation {
        bytes32 uid;
        bytes32 schema;
        uint64 time;
        uint64 expirationTime;
        uint64 revocationTime;
        bytes32 refUID;
        address recipient;
        address attester;
        bool revocable;
        bytes data;
    }
}

interface ISchemaRegistry {
    function register(string calldata schema, address resolver, bool revocable) external returns (bytes32);
}

/**
 * @title EASIntegration
 * @notice NFT attestations using Ethereum Attestation Service
 */
contract EASIntegration is ERC721, AccessControl {
    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    IEAS public immutable eas;
    ISchemaRegistry public immutable schemaRegistry;

    uint256 private _tokenIdCounter;

    // Schemas
    bytes32 public ownershipSchema;
    bytes32 public provenanceSchema;
    bytes32 public authenticationSchema;

    // Token attestations
    mapping(uint256 => bytes32[]) public tokenAttestations;
    mapping(bytes32 => uint256) public attestationToToken;

    // Attestation types
    enum AttestationType {
        Ownership,
        Provenance,
        Authentication,
        Appraisal,
        Exhibition,
        Custom
    }

    struct TokenAttestation {
        AttestationType attestationType;
        bytes32 uid;
        address attester;
        uint64 timestamp;
        string data;
    }

    mapping(bytes32 => TokenAttestation) public attestationDetails;

    string private _baseTokenURI;

    event SchemaRegistered(bytes32 indexed schemaId, string schemaType);
    event AttestationCreated(uint256 indexed tokenId, bytes32 indexed uid, AttestationType attestationType);
    event AttestationRevoked(uint256 indexed tokenId, bytes32 indexed uid);

    constructor(
        string memory name,
        string memory symbol,
        address _eas,
        address _schemaRegistry
    ) ERC721(name, symbol) {
        eas = IEAS(_eas);
        schemaRegistry = ISchemaRegistry(_schemaRegistry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ATTESTER_ROLE, msg.sender);
    }

    // ==================== Schema Registration ====================

    function registerSchemas() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ownership schema
        ownershipSchema = schemaRegistry.register(
            "address owner, uint256 tokenId, uint64 timestamp",
            address(0),
            true
        );
        emit SchemaRegistered(ownershipSchema, "Ownership");

        // Provenance schema
        provenanceSchema = schemaRegistry.register(
            "uint256 tokenId, address from, address to, uint64 timestamp, string txHash",
            address(0),
            false
        );
        emit SchemaRegistered(provenanceSchema, "Provenance");

        // Authentication schema
        authenticationSchema = schemaRegistry.register(
            "uint256 tokenId, string authenticator, bool isAuthentic, string report",
            address(0),
            true
        );
        emit SchemaRegistered(authenticationSchema, "Authentication");
    }

    // ==================== Attestation Functions ====================

    /**
     * @notice Create ownership attestation
     */
    function attestOwnership(uint256 tokenId) external onlyRole(ATTESTER_ROLE) returns (bytes32) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        bytes memory data = abi.encode(
            ownerOf(tokenId),
            tokenId,
            uint64(block.timestamp)
        );

        bytes32 uid = eas.attest(IEAS.AttestationRequest({
            schema: ownershipSchema,
            data: IEAS.AttestationRequestData({
                recipient: ownerOf(tokenId),
                expirationTime: 0,
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        }));

        _recordAttestation(tokenId, uid, AttestationType.Ownership, "");

        return uid;
    }

    /**
     * @notice Create provenance attestation on transfer
     */
    function attestProvenance(
        uint256 tokenId,
        address from,
        address to,
        string calldata txHash
    ) external onlyRole(ATTESTER_ROLE) returns (bytes32) {
        bytes memory data = abi.encode(
            tokenId,
            from,
            to,
            uint64(block.timestamp),
            txHash
        );

        bytes32 uid = eas.attest(IEAS.AttestationRequest({
            schema: provenanceSchema,
            data: IEAS.AttestationRequestData({
                recipient: to,
                expirationTime: 0,
                revocable: false,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        }));

        _recordAttestation(tokenId, uid, AttestationType.Provenance, txHash);

        return uid;
    }

    /**
     * @notice Create authentication attestation
     */
    function attestAuthentication(
        uint256 tokenId,
        string calldata authenticator,
        bool isAuthentic,
        string calldata report
    ) external onlyRole(ATTESTER_ROLE) returns (bytes32) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        bytes memory data = abi.encode(
            tokenId,
            authenticator,
            isAuthentic,
            report
        );

        bytes32 uid = eas.attest(IEAS.AttestationRequest({
            schema: authenticationSchema,
            data: IEAS.AttestationRequestData({
                recipient: ownerOf(tokenId),
                expirationTime: 0,
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        }));

        _recordAttestation(tokenId, uid, AttestationType.Authentication, report);

        return uid;
    }

    /**
     * @notice Record attestation internally
     */
    function _recordAttestation(
        uint256 tokenId,
        bytes32 uid,
        AttestationType attestationType,
        string memory data
    ) internal {
        tokenAttestations[tokenId].push(uid);
        attestationToToken[uid] = tokenId;

        attestationDetails[uid] = TokenAttestation({
            attestationType: attestationType,
            uid: uid,
            attester: msg.sender,
            timestamp: uint64(block.timestamp),
            data: data
        });

        emit AttestationCreated(tokenId, uid, attestationType);
    }

    /**
     * @notice Revoke an attestation
     */
    function revokeAttestation(bytes32 uid, bytes32 schema) external onlyRole(ATTESTER_ROLE) {
        uint256 tokenId = attestationToToken[uid];

        eas.revoke(IEAS.RevocationRequest({
            schema: schema,
            data: IEAS.RevocationRequestData({
                uid: uid,
                value: 0
            })
        }));

        emit AttestationRevoked(tokenId, uid);
    }

    // ==================== View Functions ====================

    /**
     * @notice Get all attestations for a token
     */
    function getTokenAttestations(uint256 tokenId)
        external
        view
        returns (bytes32[] memory)
    {
        return tokenAttestations[tokenId];
    }

    /**
     * @notice Get attestation details
     */
    function getAttestationDetails(bytes32 uid)
        external
        view
        returns (TokenAttestation memory)
    {
        return attestationDetails[uid];
    }

    /**
     * @notice Verify attestation is valid
     */
    function verifyAttestation(bytes32 uid) external view returns (bool valid, string memory status) {
        IEAS.Attestation memory attestation = eas.getAttestation(uid);

        if (attestation.uid == bytes32(0)) {
            return (false, "Attestation not found");
        }

        if (attestation.revocationTime > 0) {
            return (false, "Attestation revoked");
        }

        if (attestation.expirationTime > 0 && attestation.expirationTime < block.timestamp) {
            return (false, "Attestation expired");
        }

        return (true, "Valid");
    }

    // ==================== NFT Functions ====================

    function mint(address to) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function setBaseURI(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 68: CURATION/GALLERY SYSTEM

## On-Chain Gallery Contract

File: `contracts/curation/Gallery.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Gallery
 * @notice On-chain curation and gallery system for NFTs
 */
contract Gallery is AccessControl, ReentrancyGuard {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");

    struct Exhibition {
        string name;
        string description;
        address curator;
        uint256 startTime;
        uint256 endTime;
        ExhibitionStatus status;
        uint256 entryFee;
        uint256 totalVisits;
        string[] tags;
    }

    enum ExhibitionStatus { Draft, Active, Ended, Cancelled }

    struct ExhibitedNFT {
        address nftContract;
        uint256 tokenId;
        address owner;
        string curatorNote;
        uint256 position;
        uint256 addedAt;
        uint256 views;
        bool forSale;
        uint256 price;
    }

    struct CuratorProfile {
        string name;
        string bio;
        uint256 totalExhibitions;
        uint256 totalViews;
        uint256 reputation;
        bool verified;
    }

    // Exhibitions
    mapping(uint256 => Exhibition) public exhibitions;
    mapping(uint256 => ExhibitedNFT[]) public exhibitionNFTs;
    uint256 public exhibitionCount;

    // Curator profiles
    mapping(address => CuratorProfile) public curatorProfiles;

    // Visitor tracking
    mapping(uint256 => mapping(address => bool)) public hasVisited;
    mapping(uint256 => mapping(address => uint256)) public visitorTips;

    // Voting/Rating
    mapping(uint256 => mapping(address => uint8)) public exhibitionRatings;
    mapping(uint256 => uint256) public totalRatings;
    mapping(uint256 => uint256) public ratingCount;

    // Gallery fees
    uint256 public galleryFee = 500; // 5%
    address public feeRecipient;

    event ExhibitionCreated(uint256 indexed exhibitionId, string name, address indexed curator);
    event NFTExhibited(uint256 indexed exhibitionId, address indexed nftContract, uint256 tokenId);
    event NFTRemoved(uint256 indexed exhibitionId, address indexed nftContract, uint256 tokenId);
    event ExhibitionVisited(uint256 indexed exhibitionId, address indexed visitor);
    event TipSent(uint256 indexed exhibitionId, address indexed visitor, uint256 amount);
    event NFTSold(uint256 indexed exhibitionId, address indexed nftContract, uint256 tokenId, address buyer, uint256 price);
    event ExhibitionRated(uint256 indexed exhibitionId, address indexed rater, uint8 rating);

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURATOR_ROLE, msg.sender);
    }

    // ==================== Curator Functions ====================

    /**
     * @notice Register as a curator
     */
    function registerCurator(string calldata name, string calldata bio) external {
        require(bytes(curatorProfiles[msg.sender].name).length == 0, "Already registered");

        curatorProfiles[msg.sender] = CuratorProfile({
            name: name,
            bio: bio,
            totalExhibitions: 0,
            totalViews: 0,
            reputation: 0,
            verified: false
        });

        _grantRole(CURATOR_ROLE, msg.sender);
    }

    /**
     * @notice Create a new exhibition
     */
    function createExhibition(
        string calldata name,
        string calldata description,
        uint256 startTime,
        uint256 endTime,
        uint256 entryFee,
        string[] calldata tags
    ) external onlyRole(CURATOR_ROLE) returns (uint256) {
        require(startTime < endTime, "Invalid time range");

        uint256 exhibitionId = ++exhibitionCount;

        exhibitions[exhibitionId] = Exhibition({
            name: name,
            description: description,
            curator: msg.sender,
            startTime: startTime,
            endTime: endTime,
            status: ExhibitionStatus.Draft,
            entryFee: entryFee,
            totalVisits: 0,
            tags: tags
        });

        curatorProfiles[msg.sender].totalExhibitions++;

        emit ExhibitionCreated(exhibitionId, name, msg.sender);

        return exhibitionId;
    }

    /**
     * @notice Add NFT to exhibition
     */
    function addNFT(
        uint256 exhibitionId,
        address nftContract,
        uint256 tokenId,
        string calldata curatorNote,
        bool forSale,
        uint256 price
    ) external {
        Exhibition storage exhibition = exhibitions[exhibitionId];
        require(exhibition.curator == msg.sender, "Not curator");
        require(
            exhibition.status == ExhibitionStatus.Draft ||
            exhibition.status == ExhibitionStatus.Active,
            "Cannot modify"
        );

        // Verify ownership
        address owner = IERC721(nftContract).ownerOf(tokenId);

        exhibitionNFTs[exhibitionId].push(ExhibitedNFT({
            nftContract: nftContract,
            tokenId: tokenId,
            owner: owner,
            curatorNote: curatorNote,
            position: exhibitionNFTs[exhibitionId].length,
            addedAt: block.timestamp,
            views: 0,
            forSale: forSale,
            price: price
        }));

        emit NFTExhibited(exhibitionId, nftContract, tokenId);
    }

    /**
     * @notice Remove NFT from exhibition
     */
    function removeNFT(uint256 exhibitionId, uint256 index) external {
        Exhibition storage exhibition = exhibitions[exhibitionId];
        require(exhibition.curator == msg.sender, "Not curator");

        ExhibitedNFT[] storage nfts = exhibitionNFTs[exhibitionId];
        require(index < nfts.length, "Invalid index");

        address nftContract = nfts[index].nftContract;
        uint256 tokenId = nfts[index].tokenId;

        // Swap and pop
        nfts[index] = nfts[nfts.length - 1];
        nfts[index].position = index;
        nfts.pop();

        emit NFTRemoved(exhibitionId, nftContract, tokenId);
    }

    /**
     * @notice Activate exhibition
     */
    function activateExhibition(uint256 exhibitionId) external {
        Exhibition storage exhibition = exhibitions[exhibitionId];
        require(exhibition.curator == msg.sender, "Not curator");
        require(exhibition.status == ExhibitionStatus.Draft, "Not draft");

        exhibition.status = ExhibitionStatus.Active;
    }

    /**
     * @notice End exhibition
     */
    function endExhibition(uint256 exhibitionId) external {
        Exhibition storage exhibition = exhibitions[exhibitionId];
        require(exhibition.curator == msg.sender, "Not curator");

        exhibition.status = ExhibitionStatus.Ended;
    }

    // ==================== Visitor Functions ====================

    /**
     * @notice Visit an exhibition
     */
    function visitExhibition(uint256 exhibitionId) external payable nonReentrant {
        Exhibition storage exhibition = exhibitions[exhibitionId];
        require(exhibition.status == ExhibitionStatus.Active, "Not active");
        require(block.timestamp >= exhibition.startTime, "Not started");
        require(block.timestamp <= exhibition.endTime, "Ended");
        require(msg.value >= exhibition.entryFee, "Insufficient fee");

        if (!hasVisited[exhibitionId][msg.sender]) {
            hasVisited[exhibitionId][msg.sender] = true;
            exhibition.totalVisits++;
            curatorProfiles[exhibition.curator].totalViews++;
        }

        // Distribute entry fee
        if (msg.value > 0) {
            uint256 fee = (msg.value * galleryFee) / 10000;
            uint256 curatorAmount = msg.value - fee;

            if (fee > 0) {
                Address.sendValue(payable(feeRecipient), fee);
            }

            Address.sendValue(payable(exhibition.curator), curatorAmount);
        }

        emit ExhibitionVisited(exhibitionId, msg.sender);
    }

    /**
     * @notice Tip the curator
     */
    function tipCurator(uint256 exhibitionId) external payable nonReentrant {
        require(msg.value > 0, "No tip");

        Exhibition storage exhibition = exhibitions[exhibitionId];
        visitorTips[exhibitionId][msg.sender] += msg.value;

        uint256 fee = (msg.value * galleryFee) / 10000;
        uint256 curatorAmount = msg.value - fee;

        if (fee > 0) {
            Address.sendValue(payable(feeRecipient), fee);
        }

        Address.sendValue(payable(exhibition.curator), curatorAmount);

        emit TipSent(exhibitionId, msg.sender, msg.value);
    }

    /**
     * @notice Rate an exhibition
     */
    function rateExhibition(uint256 exhibitionId, uint8 rating) external {
        require(rating >= 1 && rating <= 5, "Rating 1-5");
        require(hasVisited[exhibitionId][msg.sender], "Must visit first");
        require(exhibitionRatings[exhibitionId][msg.sender] == 0, "Already rated");

        exhibitionRatings[exhibitionId][msg.sender] = rating;
        totalRatings[exhibitionId] += rating;
        ratingCount[exhibitionId]++;

        // Update curator reputation
        Exhibition storage exhibition = exhibitions[exhibitionId];
        curatorProfiles[exhibition.curator].reputation += rating;

        emit ExhibitionRated(exhibitionId, msg.sender, rating);
    }

    /**
     * @notice Buy exhibited NFT
     */
    function buyExhibitedNFT(uint256 exhibitionId, uint256 index) external payable nonReentrant {
        ExhibitedNFT storage nft = exhibitionNFTs[exhibitionId][index];
        require(nft.forSale, "Not for sale");
        require(msg.value >= nft.price, "Insufficient payment");

        address seller = nft.owner;

        // Verify still owned
        require(IERC721(nft.nftContract).ownerOf(nft.tokenId) == seller, "No longer owned");

        nft.forSale = false;

        // Calculate fees
        uint256 fee = (nft.price * galleryFee) / 10000;
        uint256 sellerAmount = nft.price - fee;

        // Transfer NFT
        IERC721(nft.nftContract).safeTransferFrom(seller, msg.sender, nft.tokenId);

        // Distribute payment
        if (fee > 0) {
            Address.sendValue(payable(feeRecipient), fee);
        }

        Address.sendValue(payable(seller), sellerAmount);

        // Refund excess
        if (msg.value > nft.price) {
            Address.sendValue(payable(msg.sender), msg.value - nft.price);
        }

        emit NFTSold(exhibitionId, nft.nftContract, nft.tokenId, msg.sender, nft.price);
    }

    // ==================== View Functions ====================

    function getExhibitionNFTs(uint256 exhibitionId)
        external
        view
        returns (ExhibitedNFT[] memory)
    {
        return exhibitionNFTs[exhibitionId];
    }

    function getAverageRating(uint256 exhibitionId) external view returns (uint256) {
        if (ratingCount[exhibitionId] == 0) return 0;
        return (totalRatings[exhibitionId] * 100) / ratingCount[exhibitionId]; // Returns rating * 100
    }

    function getCuratorProfile(address curator)
        external
        view
        returns (CuratorProfile memory)
    {
        return curatorProfiles[curator];
    }

    // ==================== Admin ====================

    function verifyCurator(address curator, bool verified) external onlyRole(DEFAULT_ADMIN_ROLE) {
        curatorProfiles[curator].verified = verified;
    }

    function setGalleryFee(uint256 fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(fee <= 2000, "Fee too high"); // Max 20%
        galleryFee = fee;
    }

    function setFeeRecipient(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeRecipient = recipient;
    }
}
```

---
