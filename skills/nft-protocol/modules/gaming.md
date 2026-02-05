# Gaming NFTs

Game-oriented NFT contracts: achievement badge systems and RPG-style loot/equipment systems.

---

# MODULE 64: ACHIEVEMENT BADGES

## Gaming Achievement NFT Contract

File: `contracts/gaming/AchievementBadges.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AchievementBadges
 * @notice On-chain gaming achievements as soulbound NFTs
 */
contract AchievementBadges is ERC1155, AccessControl, ReentrancyGuard {
    bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");
    bytes32 public constant ACHIEVEMENT_GRANTER = keccak256("ACHIEVEMENT_GRANTER");

    struct Achievement {
        string name;
        string description;
        string imageURI;
        uint256 points;
        AchievementRarity rarity;
        uint256 maxSupply; // 0 = unlimited
        uint256 totalAwarded;
        bool soulbound;
        bool active;
    }

    enum AchievementRarity { Common, Uncommon, Rare, Epic, Legendary }

    // Achievement ID => Achievement data
    mapping(uint256 => Achievement) public achievements;
    uint256 public achievementCount;

    // Player stats
    mapping(address => uint256) public playerPoints;
    mapping(address => uint256[]) public playerAchievements;
    mapping(address => mapping(uint256 => bool)) public hasAchievement;
    mapping(address => mapping(uint256 => uint256)) public achievementTimestamp;

    // Leaderboard
    address[] public leaderboardPlayers;
    mapping(address => bool) public isOnLeaderboard;

    // Prerequisites
    mapping(uint256 => uint256[]) public achievementPrerequisites;

    event AchievementCreated(uint256 indexed achievementId, string name, AchievementRarity rarity);
    event AchievementAwarded(address indexed player, uint256 indexed achievementId, uint256 timestamp);
    event PointsEarned(address indexed player, uint256 points, uint256 totalPoints);

    constructor(string memory uri) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MASTER, msg.sender);
        _grantRole(ACHIEVEMENT_GRANTER, msg.sender);
    }

    // ==================== Achievement Management ====================

    /**
     * @notice Create a new achievement type
     */
    function createAchievement(
        string calldata name,
        string calldata description,
        string calldata imageURI,
        uint256 points,
        AchievementRarity rarity,
        uint256 maxSupply,
        bool soulbound,
        uint256[] calldata prerequisites
    ) external onlyRole(GAME_MASTER) returns (uint256) {
        uint256 achievementId = ++achievementCount;

        achievements[achievementId] = Achievement({
            name: name,
            description: description,
            imageURI: imageURI,
            points: points,
            rarity: rarity,
            maxSupply: maxSupply,
            totalAwarded: 0,
            soulbound: soulbound,
            active: true
        });

        if (prerequisites.length > 0) {
            achievementPrerequisites[achievementId] = prerequisites;
        }

        emit AchievementCreated(achievementId, name, rarity);

        return achievementId;
    }

    /**
     * @notice Award achievement to a player
     */
    function awardAchievement(
        address player,
        uint256 achievementId
    ) external onlyRole(ACHIEVEMENT_GRANTER) nonReentrant {
        Achievement storage achievement = achievements[achievementId];

        require(achievement.active, "Achievement not active");
        require(!hasAchievement[player][achievementId], "Already has achievement");
        require(
            achievement.maxSupply == 0 ||
            achievement.totalAwarded < achievement.maxSupply,
            "Max supply reached"
        );

        // Check prerequisites
        uint256[] storage prereqs = achievementPrerequisites[achievementId];
        for (uint256 i = 0; i < prereqs.length; i++) {
            require(hasAchievement[player][prereqs[i]], "Missing prerequisite");
        }

        // Award achievement
        hasAchievement[player][achievementId] = true;
        achievementTimestamp[player][achievementId] = block.timestamp;
        playerAchievements[player].push(achievementId);
        achievement.totalAwarded++;

        // Award points
        playerPoints[player] += achievement.points;

        // Update leaderboard
        if (!isOnLeaderboard[player]) {
            leaderboardPlayers.push(player);
            isOnLeaderboard[player] = true;
        }

        // Mint NFT
        _mint(player, achievementId, 1, "");

        emit AchievementAwarded(player, achievementId, block.timestamp);
        emit PointsEarned(player, achievement.points, playerPoints[player]);
    }

    /**
     * @notice Batch award achievements
     */
    function batchAwardAchievements(
        address[] calldata players,
        uint256 achievementId
    ) external onlyRole(ACHIEVEMENT_GRANTER) {
        for (uint256 i = 0; i < players.length; i++) {
            if (!hasAchievement[players[i]][achievementId]) {
                // Simplified - in production, use internal function
                hasAchievement[players[i]][achievementId] = true;
                achievementTimestamp[players[i]][achievementId] = block.timestamp;
                playerAchievements[players[i]].push(achievementId);
                achievements[achievementId].totalAwarded++;
                playerPoints[players[i]] += achievements[achievementId].points;

                _mint(players[i], achievementId, 1, "");

                emit AchievementAwarded(players[i], achievementId, block.timestamp);
            }
        }
    }

    // ==================== Player Functions ====================

    /**
     * @notice Get player's achievements
     */
    function getPlayerAchievements(address player)
        external
        view
        returns (uint256[] memory)
    {
        return playerAchievements[player];
    }

    /**
     * @notice Get player stats
     */
    function getPlayerStats(address player)
        external
        view
        returns (
            uint256 totalPoints,
            uint256 achievementCount_,
            uint256 commonCount,
            uint256 rareCount,
            uint256 legendaryCount
        )
    {
        totalPoints = playerPoints[player];
        achievementCount_ = playerAchievements[player].length;

        uint256[] memory playerAchievs = playerAchievements[player];
        for (uint256 i = 0; i < playerAchievs.length; i++) {
            Achievement storage a = achievements[playerAchievs[i]];
            if (a.rarity == AchievementRarity.Common) commonCount++;
            else if (a.rarity == AchievementRarity.Rare) rareCount++;
            else if (a.rarity == AchievementRarity.Legendary) legendaryCount++;
        }
    }

    /**
     * @notice Check eligibility for achievement
     */
    function canEarnAchievement(address player, uint256 achievementId)
        external
        view
        returns (bool eligible, string memory reason)
    {
        Achievement storage achievement = achievements[achievementId];

        if (!achievement.active) return (false, "Achievement not active");
        if (hasAchievement[player][achievementId]) return (false, "Already earned");
        if (achievement.maxSupply > 0 && achievement.totalAwarded >= achievement.maxSupply) {
            return (false, "Max supply reached");
        }

        uint256[] storage prereqs = achievementPrerequisites[achievementId];
        for (uint256 i = 0; i < prereqs.length; i++) {
            if (!hasAchievement[player][prereqs[i]]) {
                return (false, "Missing prerequisite");
            }
        }

        return (true, "Eligible");
    }

    // ==================== Leaderboard ====================

    /**
     * @notice Get top players by points
     */
    function getLeaderboard(uint256 limit)
        external
        view
        returns (address[] memory players, uint256[] memory points)
    {
        uint256 count = leaderboardPlayers.length < limit ? leaderboardPlayers.length : limit;
        players = new address[](count);
        points = new uint256[](count);

        // Simple bubble sort for small leaderboards
        // For production, use off-chain sorting
        address[] memory sorted = leaderboardPlayers;

        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (playerPoints[sorted[j]] > playerPoints[sorted[i]]) {
                    address temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }

        for (uint256 i = 0; i < count; i++) {
            players[i] = sorted[i];
            points[i] = playerPoints[sorted[i]];
        }
    }

    // ==================== Soulbound Override ====================

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        // Check if any tokens are soulbound
        for (uint256 i = 0; i < ids.length; i++) {
            if (from != address(0) && to != address(0)) {
                require(!achievements[ids[i]].soulbound, "Soulbound: non-transferable");
            }
        }
        super._update(from, to, ids, values);
    }

    // ==================== Admin ====================

    function setAchievementActive(uint256 achievementId, bool active)
        external
        onlyRole(GAME_MASTER)
    {
        achievements[achievementId].active = active;
    }

    function uri(uint256 achievementId) public view override returns (string memory) {
        Achievement storage achievement = achievements[achievementId];
        return achievement.imageURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

# MODULE 65: LOOT/EQUIPMENT SYSTEM

## RPG Equipment NFT Contract

File: `contracts/gaming/EquipmentSystem.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title EquipmentSystem
 * @notice RPG-style equipment NFTs with stats and crafting
 */
contract EquipmentSystem is ERC721, AccessControl, ReentrancyGuard {
    bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");
    bytes32 public constant CRAFTER_ROLE = keccak256("CRAFTER_ROLE");

    uint256 private _tokenIdCounter;

    enum EquipmentSlot { Weapon, Armor, Helmet, Shield, Boots, Accessory }
    enum Rarity { Common, Uncommon, Rare, Epic, Legendary, Mythic }

    struct Stats {
        uint16 attack;
        uint16 defense;
        uint16 speed;
        uint16 magic;
        uint16 luck;
        uint16 durability;
    }

    struct Equipment {
        string name;
        EquipmentSlot slot;
        Rarity rarity;
        Stats baseStats;
        Stats bonusStats;
        uint8 level;
        uint8 maxLevel;
        uint256 experience;
        bool equipped;
        uint256 equippedTo; // Character token ID
    }

    // Equipment templates
    struct EquipmentTemplate {
        string name;
        EquipmentSlot slot;
        Rarity rarity;
        Stats baseStats;
        uint8 maxLevel;
        bool active;
    }

    mapping(uint256 => Equipment) public equipment;
    mapping(uint256 => EquipmentTemplate) public templates;
    uint256 public templateCount;

    // Equipped items per character
    mapping(uint256 => mapping(EquipmentSlot => uint256)) public characterEquipment;

    // Crafting recipes
    struct Recipe {
        uint256[] inputTemplates;
        uint256[] inputAmounts;
        uint256 outputTemplate;
        uint256 craftingFee;
        bool active;
    }

    mapping(uint256 => Recipe) public recipes;
    uint256 public recipeCount;

    // Experience required per level
    uint256[] public expRequired = [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500];

    string private _baseTokenURI;

    event EquipmentMinted(uint256 indexed tokenId, uint256 templateId, address indexed owner);
    event EquipmentEquipped(uint256 indexed equipmentId, uint256 indexed characterId, EquipmentSlot slot);
    event EquipmentUnequipped(uint256 indexed equipmentId, uint256 indexed characterId);
    event EquipmentLeveledUp(uint256 indexed tokenId, uint8 newLevel);
    event EquipmentCrafted(uint256 indexed tokenId, uint256 recipeId, address indexed crafter);

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MASTER, msg.sender);
        _grantRole(CRAFTER_ROLE, msg.sender);
    }

    // ==================== Template Management ====================

    function createTemplate(
        string calldata name,
        EquipmentSlot slot,
        Rarity rarity,
        Stats calldata baseStats,
        uint8 maxLevel
    ) external onlyRole(GAME_MASTER) returns (uint256) {
        uint256 templateId = ++templateCount;

        templates[templateId] = EquipmentTemplate({
            name: name,
            slot: slot,
            rarity: rarity,
            baseStats: baseStats,
            maxLevel: maxLevel,
            active: true
        });

        return templateId;
    }

    // ==================== Minting ====================

    function mintEquipment(
        address to,
        uint256 templateId
    ) external onlyRole(GAME_MASTER) returns (uint256) {
        EquipmentTemplate storage template = templates[templateId];
        require(template.active, "Template not active");

        uint256 tokenId = ++_tokenIdCounter;

        equipment[tokenId] = Equipment({
            name: template.name,
            slot: template.slot,
            rarity: template.rarity,
            baseStats: template.baseStats,
            bonusStats: Stats(0, 0, 0, 0, 0, 0),
            level: 1,
            maxLevel: template.maxLevel,
            experience: 0,
            equipped: false,
            equippedTo: 0
        });

        _safeMint(to, tokenId);

        emit EquipmentMinted(tokenId, templateId, to);

        return tokenId;
    }

    // ==================== Equipment Management ====================

    function equip(uint256 equipmentId, uint256 characterId) external {
        require(ownerOf(equipmentId) == msg.sender, "Not equipment owner");

        Equipment storage item = equipment[equipmentId];
        require(!item.equipped, "Already equipped");

        // Unequip current item in slot
        uint256 currentEquipped = characterEquipment[characterId][item.slot];
        if (currentEquipped != 0) {
            _unequip(currentEquipped);
        }

        item.equipped = true;
        item.equippedTo = characterId;
        characterEquipment[characterId][item.slot] = equipmentId;

        emit EquipmentEquipped(equipmentId, characterId, item.slot);
    }

    function unequip(uint256 equipmentId) external {
        require(ownerOf(equipmentId) == msg.sender, "Not equipment owner");
        _unequip(equipmentId);
    }

    function _unequip(uint256 equipmentId) internal {
        Equipment storage item = equipment[equipmentId];
        require(item.equipped, "Not equipped");

        uint256 characterId = item.equippedTo;

        item.equipped = false;
        item.equippedTo = 0;
        characterEquipment[characterId][item.slot] = 0;

        emit EquipmentUnequipped(equipmentId, characterId);
    }

    // ==================== Leveling ====================

    function addExperience(uint256 tokenId, uint256 exp) external onlyRole(GAME_MASTER) {
        Equipment storage item = equipment[tokenId];
        require(item.level < item.maxLevel, "Max level reached");

        item.experience += exp;

        // Check for level up
        while (item.level < item.maxLevel && item.experience >= expRequired[item.level]) {
            item.experience -= expRequired[item.level];
            item.level++;

            // Increase stats on level up
            item.bonusStats.attack += 2;
            item.bonusStats.defense += 2;
            item.bonusStats.speed += 1;
            item.bonusStats.magic += 1;

            emit EquipmentLeveledUp(tokenId, item.level);
        }
    }

    // ==================== Crafting ====================

    function createRecipe(
        uint256[] calldata inputTemplates,
        uint256[] calldata inputAmounts,
        uint256 outputTemplate,
        uint256 craftingFee
    ) external onlyRole(GAME_MASTER) returns (uint256) {
        require(inputTemplates.length == inputAmounts.length, "Length mismatch");

        uint256 recipeId = ++recipeCount;

        recipes[recipeId] = Recipe({
            inputTemplates: inputTemplates,
            inputAmounts: inputAmounts,
            outputTemplate: outputTemplate,
            craftingFee: craftingFee,
            active: true
        });

        return recipeId;
    }

    function craft(uint256 recipeId, uint256[] calldata inputTokenIds)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        Recipe storage recipe = recipes[recipeId];
        require(recipe.active, "Recipe not active");
        require(msg.value >= recipe.craftingFee, "Insufficient fee");

        // Verify and burn inputs
        uint256 inputIndex = 0;
        for (uint256 i = 0; i < recipe.inputTemplates.length; i++) {
            for (uint256 j = 0; j < recipe.inputAmounts[i]; j++) {
                uint256 tokenId = inputTokenIds[inputIndex++];
                require(ownerOf(tokenId) == msg.sender, "Not owner of input");
                // Verify template matches (simplified - would need template tracking)
                _burn(tokenId);
            }
        }

        // Mint output
        uint256 outputTokenId = ++_tokenIdCounter;
        EquipmentTemplate storage outputTemplate = templates[recipe.outputTemplate];

        equipment[outputTokenId] = Equipment({
            name: outputTemplate.name,
            slot: outputTemplate.slot,
            rarity: outputTemplate.rarity,
            baseStats: outputTemplate.baseStats,
            bonusStats: Stats(0, 0, 0, 0, 0, 0),
            level: 1,
            maxLevel: outputTemplate.maxLevel,
            experience: 0,
            equipped: false,
            equippedTo: 0
        });

        _safeMint(msg.sender, outputTokenId);

        emit EquipmentCrafted(outputTokenId, recipeId, msg.sender);

        return outputTokenId;
    }

    // ==================== View Functions ====================

    function getEquipmentStats(uint256 tokenId)
        external
        view
        returns (Stats memory totalStats)
    {
        Equipment storage item = equipment[tokenId];

        totalStats = Stats({
            attack: item.baseStats.attack + item.bonusStats.attack,
            defense: item.baseStats.defense + item.bonusStats.defense,
            speed: item.baseStats.speed + item.bonusStats.speed,
            magic: item.baseStats.magic + item.bonusStats.magic,
            luck: item.baseStats.luck + item.bonusStats.luck,
            durability: item.baseStats.durability + item.bonusStats.durability
        });
    }

    function getCharacterEquipment(uint256 characterId)
        external
        view
        returns (uint256[6] memory equipped)
    {
        equipped[0] = characterEquipment[characterId][EquipmentSlot.Weapon];
        equipped[1] = characterEquipment[characterId][EquipmentSlot.Armor];
        equipped[2] = characterEquipment[characterId][EquipmentSlot.Helmet];
        equipped[3] = characterEquipment[characterId][EquipmentSlot.Shield];
        equipped[4] = characterEquipment[characterId][EquipmentSlot.Boots];
        equipped[5] = characterEquipment[characterId][EquipmentSlot.Accessory];
    }

    // ==================== Admin ====================

    function setBaseURI(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        Address.sendValue(payable(msg.sender), address(this).balance);
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
