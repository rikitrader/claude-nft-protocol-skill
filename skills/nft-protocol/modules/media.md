# Media & Art NFTs

Specialized media NFT contracts: music NFTs with streaming royalties, video NFTs with monetization, generative art engine with on-chain seeds, and fully on-chain SVG art.

---

# MODULE 50: MUSIC NFT SUPPORT

## Music NFT Contract

File: `contracts/media/MusicNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title MusicNFT
 * @notice NFTs representing music tracks with streaming royalties
 */
contract MusicNFT is ERC721, ERC2981, AccessControl, ReentrancyGuard {
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    uint256 private _tokenIdCounter;

    struct Track {
        string title;
        string artist;
        string album;
        uint256 duration;      // seconds
        string genre;
        string audioURI;       // IPFS/Arweave URI
        string coverArtURI;
        string metadataURI;
        uint256 releaseDate;
        bool explicit;
        // Royalty splits
        address[] collaborators;
        uint256[] splits;      // Basis points (total 10000)
    }

    struct StreamingData {
        uint256 totalStreams;
        uint256 lastStreamTime;
        uint256 accumulatedRoyalties;
    }

    mapping(uint256 => Track) public tracks;
    mapping(uint256 => StreamingData) public streamingData;

    // Streaming royalty pool
    uint256 public streamingPool;
    uint256 public royaltyPerStream = 0.0001 ether; // ~$0.003 at $30 ETH

    // Licensing
    mapping(uint256 => mapping(address => License)) public licenses;

    struct License {
        LicenseType licenseType;
        uint256 expiresAt;
        bool commercial;
    }

    enum LicenseType { None, Personal, Commercial, Exclusive }

    event TrackMinted(uint256 indexed tokenId, string title, address indexed artist);
    event StreamRecorded(uint256 indexed tokenId, address indexed listener, uint256 streams);
    event RoyaltiesDistributed(uint256 indexed tokenId, uint256 amount);
    event LicenseGranted(uint256 indexed tokenId, address indexed licensee, LicenseType licenseType);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARTIST_ROLE, msg.sender);
    }

    /**
     * @notice Mint a new music track NFT
     */
    function mintTrack(
        address to,
        string calldata title,
        string calldata artist,
        string calldata album,
        uint256 duration,
        string calldata genre,
        string calldata audioURI,
        string calldata coverArtURI,
        string calldata metadataURI,
        bool explicit,
        address[] calldata collaborators,
        uint256[] calldata splits,
        uint96 royaltyBps
    ) external onlyRole(ARTIST_ROLE) returns (uint256) {
        require(collaborators.length == splits.length, "Length mismatch");

        // Validate splits total 10000
        uint256 totalSplits;
        for (uint256 i = 0; i < splits.length; i++) {
            totalSplits += splits[i];
        }
        require(totalSplits == 10000, "Splits must total 10000");

        uint256 tokenId = ++_tokenIdCounter;

        tracks[tokenId] = Track({
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            genre: genre,
            audioURI: audioURI,
            coverArtURI: coverArtURI,
            metadataURI: metadataURI,
            releaseDate: block.timestamp,
            explicit: explicit,
            collaborators: collaborators,
            splits: splits
        });

        _safeMint(to, tokenId);
        _setTokenRoyalty(tokenId, to, royaltyBps);

        emit TrackMinted(tokenId, title, to);

        return tokenId;
    }

    /**
     * @notice Record streams (called by distributor/platform)
     */
    function recordStreams(
        uint256 tokenId,
        address listener,
        uint256 streamCount
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Track doesn't exist");

        StreamingData storage data = streamingData[tokenId];
        data.totalStreams += streamCount;
        data.lastStreamTime = block.timestamp;

        uint256 royaltyAmount = streamCount * royaltyPerStream;
        data.accumulatedRoyalties += royaltyAmount;

        emit StreamRecorded(tokenId, listener, streamCount);
    }

    /**
     * @notice Distribute accumulated streaming royalties
     */
    function distributeRoyalties(uint256 tokenId) external nonReentrant {
        StreamingData storage data = streamingData[tokenId];
        require(data.accumulatedRoyalties > 0, "No royalties");
        require(address(this).balance >= data.accumulatedRoyalties, "Insufficient pool");

        uint256 amount = data.accumulatedRoyalties;
        data.accumulatedRoyalties = 0;

        Track storage track = tracks[tokenId];

        // Distribute to collaborators
        for (uint256 i = 0; i < track.collaborators.length; i++) {
            uint256 share = (amount * track.splits[i]) / 10000;
            Address.sendValue(payable(track.collaborators[i]), share);
        }

        emit RoyaltiesDistributed(tokenId, amount);
    }

    /**
     * @notice Grant license for a track
     */
    function grantLicense(
        uint256 tokenId,
        address licensee,
        LicenseType licenseType,
        uint256 duration
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(licenseType != LicenseType.None, "Invalid type");

        licenses[tokenId][licensee] = License({
            licenseType: licenseType,
            expiresAt: block.timestamp + duration,
            commercial: licenseType == LicenseType.Commercial || licenseType == LicenseType.Exclusive
        });

        emit LicenseGranted(tokenId, licensee, licenseType);
    }

    /**
     * @notice Check if address has valid license
     */
    function hasValidLicense(uint256 tokenId, address licensee)
        external
        view
        returns (bool valid, LicenseType licenseType)
    {
        License storage lic = licenses[tokenId][licensee];
        valid = lic.licenseType != LicenseType.None && lic.expiresAt > block.timestamp;
        licenseType = lic.licenseType;
    }

    /**
     * @notice Get track info
     */
    function getTrack(uint256 tokenId)
        external
        view
        returns (
            string memory title,
            string memory artist,
            string memory album,
            uint256 duration,
            string memory audioURI,
            uint256 totalStreams
        )
    {
        Track storage track = tracks[tokenId];
        StreamingData storage data = streamingData[tokenId];

        return (
            track.title,
            track.artist,
            track.album,
            track.duration,
            track.audioURI,
            data.totalStreams
        );
    }

    /**
     * @notice Get collaborators and splits
     */
    function getCollaborators(uint256 tokenId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        Track storage track = tracks[tokenId];
        return (track.collaborators, track.splits);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return tracks[tokenId].metadataURI;
    }

    // ==================== Admin ====================

    function setRoyaltyPerStream(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        royaltyPerStream = amount;
    }

    function fundStreamingPool() external payable {
        streamingPool += msg.value;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {
        streamingPool += msg.value;
    }
}
```

---

# MODULE 51: VIDEO NFT SUPPORT

## Video NFT Contract

File: `contracts/media/VideoNFT.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title VideoNFT
 * @notice NFTs for video content with view tracking and monetization
 */
contract VideoNFT is ERC721, ERC2981, AccessControl, ReentrancyGuard {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant PLATFORM_ROLE = keccak256("PLATFORM_ROLE");

    uint256 private _tokenIdCounter;

    struct Video {
        string title;
        string description;
        string creator;
        uint256 duration;       // seconds
        string category;
        // Media URIs
        string videoURI;        // Full quality
        string previewURI;      // Preview/trailer
        string thumbnailURI;
        string metadataURI;
        // Content info
        uint256 releaseDate;
        bool adult;
        string[] tags;
        // Quality variants
        string[] qualityURIs;   // [480p, 720p, 1080p, 4k]
    }

    struct ViewData {
        uint256 totalViews;
        uint256 completedViews; // Watched >80%
        uint256 watchTimeMinutes;
        uint256 lastViewTime;
        uint256 accumulatedRevenue;
    }

    mapping(uint256 => Video) public videos;
    mapping(uint256 => ViewData) public viewData;

    // Access control
    mapping(uint256 => bool) public isPremium;
    mapping(uint256 => uint256) public premiumPrice;
    mapping(address => mapping(uint256 => bool)) public hasPurchased;

    // Revenue settings
    uint256 public revenuePerView = 0.00001 ether;
    uint256 public platformFee = 1000; // 10%

    event VideoMinted(uint256 indexed tokenId, string title, address indexed creator);
    event ViewRecorded(uint256 indexed tokenId, address indexed viewer, uint256 watchTime);
    event PremiumPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event RevenueWithdrawn(uint256 indexed tokenId, address indexed creator, uint256 amount);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(PLATFORM_ROLE, msg.sender);
    }

    /**
     * @notice Mint a new video NFT
     */
    function mintVideo(
        address to,
        string calldata title,
        string calldata description,
        string calldata creator,
        uint256 duration,
        string calldata category,
        string calldata videoURI,
        string calldata previewURI,
        string calldata thumbnailURI,
        string calldata metadataURI,
        bool adult,
        string[] calldata tags,
        string[] calldata qualityURIs,
        uint96 royaltyBps
    ) external onlyRole(CREATOR_ROLE) returns (uint256) {
        uint256 tokenId = ++_tokenIdCounter;

        videos[tokenId] = Video({
            title: title,
            description: description,
            creator: creator,
            duration: duration,
            category: category,
            videoURI: videoURI,
            previewURI: previewURI,
            thumbnailURI: thumbnailURI,
            metadataURI: metadataURI,
            releaseDate: block.timestamp,
            adult: adult,
            tags: tags,
            qualityURIs: qualityURIs
        });

        _safeMint(to, tokenId);
        _setTokenRoyalty(tokenId, to, royaltyBps);

        emit VideoMinted(tokenId, title, to);

        return tokenId;
    }

    /**
     * @notice Set video as premium content
     */
    function setPremium(uint256 tokenId, bool premium, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        isPremium[tokenId] = premium;
        premiumPrice[tokenId] = price;
    }

    /**
     * @notice Purchase access to premium video
     */
    function purchasePremium(uint256 tokenId) external payable nonReentrant {
        require(isPremium[tokenId], "Not premium");
        require(!hasPurchased[msg.sender][tokenId], "Already purchased");
        require(msg.value >= premiumPrice[tokenId], "Insufficient payment");

        hasPurchased[msg.sender][tokenId] = true;

        // Split payment
        uint256 platformAmount = (msg.value * platformFee) / 10000;
        uint256 creatorAmount = msg.value - platformAmount;

        viewData[tokenId].accumulatedRevenue += creatorAmount;

        emit PremiumPurchased(tokenId, msg.sender, msg.value);
    }

    /**
     * @notice Check if address can access video
     */
    function canAccess(uint256 tokenId, address viewer) external view returns (bool) {
        if (!isPremium[tokenId]) return true;
        if (ownerOf(tokenId) == viewer) return true;
        return hasPurchased[viewer][tokenId];
    }

    /**
     * @notice Record view data (platform only)
     */
    function recordView(
        uint256 tokenId,
        address viewer,
        uint256 watchTimeMinutes,
        bool completed
    ) external onlyRole(PLATFORM_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Video doesn't exist");

        ViewData storage data = viewData[tokenId];
        data.totalViews++;
        data.watchTimeMinutes += watchTimeMinutes;
        data.lastViewTime = block.timestamp;

        if (completed) {
            data.completedViews++;
        }

        // Accumulate ad revenue (for free content)
        if (!isPremium[tokenId]) {
            data.accumulatedRevenue += revenuePerView;
        }

        emit ViewRecorded(tokenId, viewer, watchTimeMinutes);
    }

    /**
     * @notice Creator withdraws accumulated revenue
     */
    function withdrawRevenue(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        ViewData storage data = viewData[tokenId];
        require(data.accumulatedRevenue > 0, "No revenue");

        uint256 amount = data.accumulatedRevenue;
        data.accumulatedRevenue = 0;

        Address.sendValue(payable(msg.sender), amount);

        emit RevenueWithdrawn(tokenId, msg.sender, amount);
    }

    /**
     * @notice Get video info
     */
    function getVideo(uint256 tokenId)
        external
        view
        returns (
            string memory title,
            string memory creator,
            uint256 duration,
            string memory previewURI,
            string memory thumbnailURI,
            bool premium,
            uint256 price
        )
    {
        Video storage video = videos[tokenId];
        return (
            video.title,
            video.creator,
            video.duration,
            video.previewURI,
            video.thumbnailURI,
            isPremium[tokenId],
            premiumPrice[tokenId]
        );
    }

    /**
     * @notice Get full video URI (access controlled)
     */
    function getVideoURI(uint256 tokenId, uint256 quality)
        external
        view
        returns (string memory)
    {
        require(
            !isPremium[tokenId] ||
            ownerOf(tokenId) == msg.sender ||
            hasPurchased[msg.sender][tokenId],
            "No access"
        );

        Video storage video = videos[tokenId];
        if (quality < video.qualityURIs.length) {
            return video.qualityURIs[quality];
        }
        return video.videoURI;
    }

    /**
     * @notice Get analytics for a video
     */
    function getAnalytics(uint256 tokenId)
        external
        view
        returns (
            uint256 totalViews,
            uint256 completedViews,
            uint256 watchTimeMinutes,
            uint256 completionRate,
            uint256 pendingRevenue
        )
    {
        ViewData storage data = viewData[tokenId];
        completionRate = data.totalViews > 0
            ? (data.completedViews * 100) / data.totalViews
            : 0;

        return (
            data.totalViews,
            data.completedViews,
            data.watchTimeMinutes,
            completionRate,
            data.accumulatedRevenue
        );
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        return videos[tokenId].metadataURI;
    }

    // ==================== Admin ====================

    function setRevenuePerView(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revenuePerView = amount;
    }

    function setPlatformFee(uint256 fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(fee <= 3000, "Fee too high"); // Max 30%
        platformFee = fee;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}
```

---

# MODULE 52: GENERATIVE ART ENGINE

## Generative Art NFT Contract

File: `contracts/art/GenerativeArt.sol`

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
 * @title GenerativeArt
 * @notice On-chain generative art with deterministic seeds
 */
contract GenerativeArt is ERC721, Ownable, ReentrancyGuard, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface immutable COORDINATOR;

    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    // VRF config
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;

    // Art generation
    string public scriptURI;        // JavaScript art generation script
    string public scriptType;       // p5js, threejs, custom
    string public previewBaseURI;   // Pre-rendered preview images

    struct TokenSeed {
        bytes32 seed;
        bool revealed;
        uint256 blockNumber;
    }

    mapping(uint256 => TokenSeed) public tokenSeeds;
    mapping(uint256 => uint256) public vrfRequests; // requestId => tokenId

    // Traits derived from seed
    struct Traits {
        uint8 palette;        // 0-15
        uint8 pattern;        // 0-31
        uint8 density;        // 0-255
        uint8 symmetry;       // 0-7
        uint8 animation;      // 0-15
        uint8 complexity;     // 0-255
        uint8 special;        // 0-3 (rare traits)
    }

    event Minted(uint256 indexed tokenId, address indexed minter);
    event SeedRevealed(uint256 indexed tokenId, bytes32 seed);
    event ScriptUpdated(string scriptURI);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        string memory _scriptURI,
        string memory _scriptType,
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
        mintPrice = _mintPrice;
        scriptURI = _scriptURI;
        scriptType = _scriptType;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    /**
     * @notice Mint with VRF seed generation
     */
    function mint() external payable nonReentrant returns (uint256) {
        require(_tokenIdCounter < maxSupply, "Sold out");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = ++_tokenIdCounter;

        _safeMint(msg.sender, tokenId);

        // Store block for fallback seed
        tokenSeeds[tokenId].blockNumber = block.number;

        // Request VRF for true randomness
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );

        vrfRequests[requestId] = tokenId;

        emit Minted(tokenId, msg.sender);

        return tokenId;
    }

    /**
     * @notice VRF callback - set seed
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 tokenId = vrfRequests[requestId];
        require(tokenId > 0, "Unknown request");

        bytes32 seed = keccak256(abi.encode(randomWords[0], tokenId, block.timestamp));

        tokenSeeds[tokenId].seed = seed;
        tokenSeeds[tokenId].revealed = true;

        emit SeedRevealed(tokenId, seed);
    }

    /**
     * @notice Fallback reveal using blockhash (if VRF fails)
     */
    function fallbackReveal(uint256 tokenId) external {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");
        require(!tokenSeeds[tokenId].revealed, "Already revealed");
        require(
            block.number > tokenSeeds[tokenId].blockNumber + 256,
            "Wait for blockhash"
        );

        bytes32 seed = keccak256(abi.encode(
            blockhash(tokenSeeds[tokenId].blockNumber + 1),
            tokenId,
            msg.sender
        ));

        tokenSeeds[tokenId].seed = seed;
        tokenSeeds[tokenId].revealed = true;

        emit SeedRevealed(tokenId, seed);
    }

    /**
     * @notice Get traits derived from seed
     */
    function getTraits(uint256 tokenId) public view returns (Traits memory) {
        require(tokenSeeds[tokenId].revealed, "Not revealed");

        bytes32 seed = tokenSeeds[tokenId].seed;

        return Traits({
            palette: uint8(uint256(seed) % 16),
            pattern: uint8(uint256(seed >> 8) % 32),
            density: uint8(uint256(seed >> 16)),
            symmetry: uint8(uint256(seed >> 24) % 8),
            animation: uint8(uint256(seed >> 32) % 16),
            complexity: uint8(uint256(seed >> 40)),
            special: uint8(uint256(seed >> 48) % 4)
        });
    }

    /**
     * @notice Get trait rarity percentages
     */
    function getTraitRarity(uint256 tokenId)
        external
        view
        returns (string memory)
    {
        Traits memory traits = getTraits(tokenId);

        // Calculate rarity score (simplified)
        uint256 rarityScore = 0;
        if (traits.special == 0) rarityScore += 75; // 75% chance
        if (traits.density > 200) rarityScore += 20; // 20% chance
        if (traits.symmetry == 0) rarityScore += 12; // 12.5% chance

        if (rarityScore >= 100) return "Common";
        if (rarityScore >= 75) return "Uncommon";
        if (rarityScore >= 50) return "Rare";
        if (rarityScore >= 25) return "Epic";
        return "Legendary";
    }

    /**
     * @notice Generate token metadata JSON
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        if (!tokenSeeds[tokenId].revealed) {
            return string(abi.encodePacked(previewBaseURI, "/unrevealed.json"));
        }

        Traits memory traits = getTraits(tokenId);
        bytes32 seed = tokenSeeds[tokenId].seed;

        // Build JSON metadata
        return string(abi.encodePacked(
            "data:application/json,{",
            '"name":"Generative #', _toString(tokenId), '",',
            '"description":"On-chain generative art",',
            '"seed":"', _toHexString(uint256(seed)), '",',
            '"animation_url":"', scriptURI, '?seed=', _toHexString(uint256(seed)), '",',
            '"attributes":[',
            '{"trait_type":"Palette","value":', _toString(traits.palette), '},',
            '{"trait_type":"Pattern","value":', _toString(traits.pattern), '},',
            '{"trait_type":"Symmetry","value":', _toString(traits.symmetry), '},',
            '{"trait_type":"Special","value":', _toString(traits.special), '}',
            ']}'
        ));
    }

    /**
     * @notice Get seed for rendering
     */
    function getSeed(uint256 tokenId) external view returns (bytes32) {
        require(tokenSeeds[tokenId].revealed, "Not revealed");
        return tokenSeeds[tokenId].seed;
    }

    // ==================== Admin ====================

    function setScriptURI(string calldata uri) external onlyOwner {
        scriptURI = uri;
        emit ScriptUpdated(uri);
    }

    function setPreviewBaseURI(string calldata uri) external onlyOwner {
        previewBaseURI = uri;
    }

    function withdraw() external onlyOwner {
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    // ==================== Helpers ====================

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _toHexString(uint256 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(66);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 65; i > 1; i--) {
            uint8 digit = uint8(value & 0xf);
            buffer[i] = digit < 10 ? bytes1(digit + 48) : bytes1(digit + 87);
            value >>= 4;
        }
        return string(buffer);
    }
}
```

---

# MODULE 66: ON-CHAIN SVG ART

## On-Chain SVG NFT Contract

File: `contracts/art/OnChainSVG.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title OnChainSVG
 * @notice Fully on-chain generative SVG art
 */
contract OnChainSVG is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    // Color palettes
    string[][] public palettes;

    // Shape types
    enum ShapeType { Circle, Rectangle, Triangle, Line, Ellipse }

    struct TokenData {
        bytes32 seed;
        uint8 paletteIndex;
        uint8 shapeCount;
        uint8 complexity;
    }

    mapping(uint256 => TokenData) public tokenData;

    event Minted(uint256 indexed tokenId, bytes32 seed);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;

        // Initialize default palettes
        palettes.push(["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7"]);
        palettes.push(["#2C3E50", "#E74C3C", "#ECF0F1", "#3498DB", "#2ECC71"]);
        palettes.push(["#1A1A2E", "#16213E", "#0F3460", "#E94560", "#533483"]);
        palettes.push(["#F8B500", "#FF6F61", "#5B5EA6", "#9B2335", "#DFCFBE"]);
    }

    /**
     * @notice Mint a new generative SVG NFT
     */
    function mint() external payable returns (uint256) {
        require(_tokenIdCounter < maxSupply, "Sold out");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = ++_tokenIdCounter;

        bytes32 seed = keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            tokenId
        ));

        tokenData[tokenId] = TokenData({
            seed: seed,
            paletteIndex: uint8(uint256(seed) % palettes.length),
            shapeCount: uint8(5 + (uint256(seed) % 10)),
            complexity: uint8(1 + (uint256(seed) % 5))
        });

        _safeMint(msg.sender, tokenId);

        emit Minted(tokenId, seed);

        return tokenId;
    }

    /**
     * @notice Generate SVG for a token
     */
    function generateSVG(uint256 tokenId) public view returns (string memory) {
        TokenData storage data = tokenData[tokenId];
        string[] storage palette = palettes[data.paletteIndex];

        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">',
            '<rect width="500" height="500" fill="', _getBackgroundColor(data.seed), '"/>'
        ));

        // Generate shapes
        for (uint256 i = 0; i < data.shapeCount; i++) {
            bytes32 shapeSeed = keccak256(abi.encodePacked(data.seed, i));
            string memory shape = _generateShape(shapeSeed, palette);
            svg = string(abi.encodePacked(svg, shape));
        }

        svg = string(abi.encodePacked(svg, '</svg>'));

        return svg;
    }

    /**
     * @notice Generate a random shape
     */
    function _generateShape(bytes32 seed, string[] storage palette)
        internal
        view
        returns (string memory)
    {
        uint256 shapeType = uint256(seed) % 5;
        string memory color = palette[uint256(keccak256(abi.encodePacked(seed, "color"))) % palette.length];
        uint256 x = (uint256(keccak256(abi.encodePacked(seed, "x"))) % 450) + 25;
        uint256 y = (uint256(keccak256(abi.encodePacked(seed, "y"))) % 450) + 25;
        uint256 size = (uint256(keccak256(abi.encodePacked(seed, "size"))) % 100) + 20;
        uint256 opacity = 30 + (uint256(keccak256(abi.encodePacked(seed, "opacity"))) % 70);

        if (shapeType == 0) {
            // Circle
            return string(abi.encodePacked(
                '<circle cx="', x.toString(), '" cy="', y.toString(),
                '" r="', size.toString(), '" fill="', color,
                '" opacity="0.', opacity.toString(), '"/>'
            ));
        } else if (shapeType == 1) {
            // Rectangle
            return string(abi.encodePacked(
                '<rect x="', x.toString(), '" y="', y.toString(),
                '" width="', size.toString(), '" height="', (size * 2 / 3).toString(),
                '" fill="', color, '" opacity="0.', opacity.toString(),
                '" rx="', (size / 10).toString(), '"/>'
            ));
        } else if (shapeType == 2) {
            // Triangle
            uint256 x2 = x + size;
            uint256 y2 = y + size;
            return string(abi.encodePacked(
                '<polygon points="', x.toString(), ',', y2.toString(), ' ',
                ((x + x2) / 2).toString(), ',', y.toString(), ' ',
                x2.toString(), ',', y2.toString(),
                '" fill="', color, '" opacity="0.', opacity.toString(), '"/>'
            ));
        } else if (shapeType == 3) {
            // Line
            uint256 x2 = x + size;
            uint256 y2 = y + (uint256(keccak256(abi.encodePacked(seed, "y2"))) % size);
            return string(abi.encodePacked(
                '<line x1="', x.toString(), '" y1="', y.toString(),
                '" x2="', x2.toString(), '" y2="', y2.toString(),
                '" stroke="', color, '" stroke-width="', (size / 20 + 1).toString(),
                '" opacity="0.', opacity.toString(), '"/>'
            ));
        } else {
            // Ellipse
            return string(abi.encodePacked(
                '<ellipse cx="', x.toString(), '" cy="', y.toString(),
                '" rx="', size.toString(), '" ry="', (size / 2).toString(),
                '" fill="', color, '" opacity="0.', opacity.toString(), '"/>'
            ));
        }
    }

    /**
     * @notice Get background color from seed
     */
    function _getBackgroundColor(bytes32 seed) internal pure returns (string memory) {
        uint256 bgType = uint256(seed) % 3;

        if (bgType == 0) {
            return "#FFFFFF";
        } else if (bgType == 1) {
            return "#1A1A1A";
        } else {
            return "#F5F5F5";
        }
    }

    /**
     * @notice Generate token URI with embedded SVG
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token doesn't exist");

        TokenData storage data = tokenData[tokenId];
        string memory svg = generateSVG(tokenId);
        string memory svgBase64 = Base64.encode(bytes(svg));

        string memory json = string(abi.encodePacked(
            '{"name":"On-Chain Art #', tokenId.toString(),
            '","description":"Fully on-chain generative SVG art",',
            '"attributes":[',
            '{"trait_type":"Palette","value":"', uint256(data.paletteIndex).toString(), '"},',
            '{"trait_type":"Shapes","value":"', uint256(data.shapeCount).toString(), '"},',
            '{"trait_type":"Complexity","value":"', uint256(data.complexity).toString(), '"}',
            '],"image":"data:image/svg+xml;base64,', svgBase64, '"}'
        ));

        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(bytes(json))
        ));
    }

    // ==================== Admin ====================

    function addPalette(string[] calldata colors) external onlyOwner {
        palettes.push(colors);
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
