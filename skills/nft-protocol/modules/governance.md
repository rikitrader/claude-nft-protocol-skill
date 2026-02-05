# Governance, Compliance & Legal

DAO governance, compliance registry (KYC/AML/whitelist), ZK compliance proofs, and legal templates for RWA tokenization.

---

## MODULE 4: DAO VOTING CONTRACT (TOKEN + GOVERNOR + TIMELOCK)

The canonical, safe baseline:
- **GovToken** = ERC20Votes (delegation & snapshots)
- **GovTimelock** = TimelockController (queued execution)
- **GovGovernor** = Governor + quorum + settings + timelock control

### File: `contracts/GovToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovToken is ERC20, ERC20Permit, ERC20Votes {
    constructor(address initialHolder, uint256 initialSupply)
        ERC20("Governance Token", "GOV")
        ERC20Permit("Governance Token")
    {
        _mint(initialHolder, initialSupply);
    }

    // Required overrides
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
```

### File: `contracts/GovTimelock.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovTimelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
```

### File: `contracts/GovGovernor.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract GovGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    constructor(
        IVotes token_,
        TimelockController timelock_,
        uint48 votingDelayBlocks,   // e.g. 1 day in blocks
        uint32 votingPeriodBlocks,  // e.g. 1 week in blocks
        uint256 proposalThreshold_,
        uint256 quorumPercent       // e.g. 4 = 4%
    )
        Governor("ProtocolGovernor")
        GovernorSettings(votingDelayBlocks, votingPeriodBlocks, proposalThreshold_)
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(quorumPercent)
        GovernorTimelockControl(timelock_)
    {}

    // Required overrides
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    { return super.votingDelay(); }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    { return super.votingPeriod(); }

    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    { return super.quorum(blockNumber); }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    { return super.proposalThreshold(); }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    { return super.state(proposalId); }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    { return super.proposalNeedsQueuing(proposalId); }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    { return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash); }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    { super._executeOperations(proposalId, targets, values, calldatas, descriptionHash); }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    { return super._cancel(targets, values, calldatas, descriptionHash); }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    { return super._executor(); }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    { return super.supportsInterface(interfaceId); }
}
```

---

## DAO DEPLOYMENT SCRIPT

File: `scripts/deploy_dao.js`

```javascript
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // 1. Deploy GovToken
  const GovToken = await ethers.getContractFactory("GovToken");
  const initialSupply = ethers.parseEther("1000000"); // 1M tokens
  const govToken = await GovToken.deploy(deployer.address, initialSupply);
  await govToken.waitForDeployment();
  console.log("GovToken:", await govToken.getAddress());

  // 2. Deploy Timelock
  const GovTimelock = await ethers.getContractFactory("GovTimelock");
  const minDelay = 3600; // 1 hour
  const proposers = []; // Will add governor later
  const executors = [ethers.ZeroAddress]; // Anyone can execute
  const admin = deployer.address;

  const timelock = await GovTimelock.deploy(minDelay, proposers, executors, admin);
  await timelock.waitForDeployment();
  console.log("GovTimelock:", await timelock.getAddress());

  // 3. Deploy Governor
  const GovGovernor = await ethers.getContractFactory("GovGovernor");
  const votingDelay = 7200;      // ~1 day in blocks (12s blocks)
  const votingPeriod = 50400;    // ~1 week in blocks
  const proposalThreshold = ethers.parseEther("1000"); // 1000 tokens to propose
  const quorumPercent = 4;       // 4% quorum

  const governor = await GovGovernor.deploy(
    await govToken.getAddress(),
    await timelock.getAddress(),
    votingDelay,
    votingPeriod,
    proposalThreshold,
    quorumPercent
  );
  await governor.waitForDeployment();
  console.log("GovGovernor:", await governor.getAddress());

  // 4. Setup roles
  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  const ADMIN_ROLE = await timelock.DEFAULT_ADMIN_ROLE();

  await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress());
  await timelock.grantRole(EXECUTOR_ROLE, await governor.getAddress());

  // Optionally revoke admin role from deployer (fully decentralized)
  // await timelock.revokeRole(ADMIN_ROLE, deployer.address);

  console.log("DAO deployment complete!");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

---

# TEST FILES

## test/ERC721SecureUUPS.test.js

```javascript
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ERC721SecureUUPS", function () {
  let nft, owner, minter, user;

  beforeEach(async function () {
    [owner, minter, user] = await ethers.getSigners();

    const ERC721SecureUUPS = await ethers.getContractFactory("ERC721SecureUUPS");
    nft = await upgrades.deployProxy(
      ERC721SecureUUPS,
      ["TestNFT", "TNFT", "ipfs://base/", 1000, owner.address, owner.address, 500],
      { kind: "uups" }
    );
    await nft.waitForDeployment();

    // Grant minter role
    const MINTER_ROLE = await nft.MINTER_ROLE();
    await nft.grantRole(MINTER_ROLE, minter.address);
  });

  describe("Minting", function () {
    it("should mint with auto ID", async function () {
      await nft.connect(minter).safeMintAutoId(user.address);
      expect(await nft.ownerOf(1)).to.equal(user.address);
      expect(await nft.totalMinted()).to.equal(1);
    });

    it("should enforce supply cap", async function () {
      await nft.setMaxSupply(1);
      await nft.connect(minter).safeMintAutoId(user.address);
      await expect(nft.connect(minter).safeMintAutoId(user.address))
        .to.be.revertedWith("maxSupply reached");
    });

    it("should reject non-minter", async function () {
      await expect(nft.connect(user).safeMintAutoId(user.address))
        .to.be.reverted;
    });
  });

  describe("Pausable", function () {
    it("should pause transfers", async function () {
      await nft.connect(minter).safeMintAutoId(user.address);
      await nft.pause();
      await expect(nft.connect(user).transferFrom(user.address, owner.address, 1))
        .to.be.revertedWith("Pausable: paused");
    });
  });

  describe("Royalties", function () {
    it("should return correct royalty info", async function () {
      await nft.connect(minter).safeMintAutoId(user.address);
      const [receiver, amount] = await nft.royaltyInfo(1, 10000);
      expect(receiver).to.equal(owner.address);
      expect(amount).to.equal(500); // 5%
    });
  });
});
```

## test/FractionalVault.test.js

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FractionalVault", function () {
  let nft, vault, owner, curator, buyer;
  const tokenId = 1;

  beforeEach(async function () {
    [owner, curator, buyer] = await ethers.getSigners();

    // Deploy simple NFT for testing
    const SimpleNFT = await ethers.getContractFactory("ERC721SecureUUPS");
    // ... or use a mock

    // For simplicity, we'll assume NFT is deployed and curator owns tokenId
    const FractionalVault = await ethers.getContractFactory("FractionalVault");
    vault = await FractionalVault.deploy(
      nft.target, // assuming nft is deployed
      tokenId,
      "Fractions",
      "FRAC"
    );
  });

  describe("Deposit", function () {
    it("should deposit NFT and mint fractions", async function () {
      // Approve vault
      await nft.connect(curator).approve(vault.target, tokenId);

      // Deposit
      const fractions = ethers.parseEther("1000");
      await vault.connect(curator).depositNFT(fractions, curator.address);

      expect(await vault.deposited()).to.be.true;
      expect(await vault.balanceOf(curator.address)).to.equal(fractions);
      expect(await nft.ownerOf(tokenId)).to.equal(vault.target);
    });
  });

  describe("Buyout", function () {
    it("should allow buyout and claim", async function () {
      // Setup: deposit first
      await nft.connect(curator).approve(vault.target, tokenId);
      const fractions = ethers.parseEther("1000");
      await vault.connect(curator).depositNFT(fractions, curator.address);

      // Start buyout
      const price = ethers.parseEther("10");
      await vault.connect(curator).startBuyout(price);

      // Buyer executes buyout
      await vault.connect(buyer).buyout({ value: price });
      expect(await nft.ownerOf(tokenId)).to.equal(buyer.address);

      // Curator claims proceeds
      const balanceBefore = await ethers.provider.getBalance(curator.address);
      await vault.connect(curator).claimProceeds(fractions);
      const balanceAfter = await ethers.provider.getBalance(curator.address);

      expect(balanceAfter).to.be.gt(balanceBefore);
    });
  });
});
```

## test/Governance.test.js

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

describe("Governance", function () {
  let govToken, timelock, governor;
  let owner, voter1, voter2;

  beforeEach(async function () {
    [owner, voter1, voter2] = await ethers.getSigners();

    // Deploy GovToken
    const GovToken = await ethers.getContractFactory("GovToken");
    const supply = ethers.parseEther("1000000");
    govToken = await GovToken.deploy(owner.address, supply);

    // Deploy Timelock
    const GovTimelock = await ethers.getContractFactory("GovTimelock");
    timelock = await GovTimelock.deploy(
      3600, // 1 hour delay
      [],   // proposers (governor added later)
      [ethers.ZeroAddress], // anyone can execute
      owner.address
    );

    // Deploy Governor
    const GovGovernor = await ethers.getContractFactory("GovGovernor");
    governor = await GovGovernor.deploy(
      govToken.target,
      timelock.target,
      1,      // voting delay (blocks)
      100,    // voting period (blocks)
      ethers.parseEther("1000"), // proposal threshold
      4       // 4% quorum
    );

    // Setup roles
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    await timelock.grantRole(PROPOSER_ROLE, governor.target);

    // Distribute tokens and delegate
    await govToken.transfer(voter1.address, ethers.parseEther("100000"));
    await govToken.connect(voter1).delegate(voter1.address);
    await govToken.connect(owner).delegate(owner.address);
  });

  describe("Proposal lifecycle", function () {
    it("should create and vote on proposal", async function () {
      // Create proposal
      const targets = [govToken.target];
      const values = [0];
      const calldatas = [govToken.interface.encodeFunctionData("transfer", [voter2.address, 1000])];
      const description = "Transfer tokens";

      const proposalId = await governor.hashProposal(targets, values, calldatas, ethers.id(description));

      await governor.propose(targets, values, calldatas, description);

      // Wait for voting delay
      await mine(2);

      // Vote
      await governor.connect(voter1).castVote(proposalId, 1); // 1 = For

      // Check state
      expect(await governor.state(proposalId)).to.equal(1); // Active
    });
  });
});
```

---

# QUICK START COMMANDS

```bash
# Clone and install
git clone <repo>
cd institutional-nft-protocol
npm install

# Compile contracts
npm run compile

# Run tests
npm run test

# Deploy to testnet (set .env first)
npm run deploy:nft -- --network sepolia

# Deploy DAO
npm run deploy:dao -- --network sepolia

# Verify on Etherscan
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

---

# MODULE 5: COMPLIANCE REGISTRY (KYC/AML/WHITELIST)

File: `contracts/ComplianceRegistry.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
COMPLIANCE REGISTRY
- KYC status tracking per wallet
- Whitelist/Blacklist management
- Geo-restriction by country code
- Accredited investor verification
- Transfer restriction hooks
- Integration with NFT contracts via IComplianceRegistry interface
*/

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IComplianceRegistry {
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool);
    function isWhitelisted(address account) external view returns (bool);
    function isAccredited(address account) external view returns (bool);
    function getKYCStatus(address account) external view returns (uint8);
}

contract ComplianceRegistry is IComplianceRegistry, AccessControl, Pausable {
    bytes32 public constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");
    bytes32 public constant KYC_PROVIDER = keccak256("KYC_PROVIDER");

    // KYC Status: 0=None, 1=Pending, 2=Approved, 3=Rejected, 4=Expired
    enum KYCStatus { None, Pending, Approved, Rejected, Expired }

    struct WalletCompliance {
        KYCStatus kycStatus;
        bool isAccredited;          // Accredited investor status
        uint64 kycExpiry;           // KYC expiration timestamp
        bytes2 countryCode;         // ISO 3166-1 alpha-2 (e.g., "US", "GB")
        bool isBlacklisted;
        uint256 dailyTransferLimit; // Max transfer value per day (0 = unlimited)
        uint256 dailyTransferred;   // Today's transfer total
        uint64 lastTransferDay;     // Day number for reset
    }

    mapping(address => WalletCompliance) public compliance;
    mapping(bytes2 => bool) public restrictedCountries;

    // Global settings
    bool public requireKYC = true;
    bool public requireAccreditation = false;
    bool public enforceCountryRestrictions = true;
    uint256 public globalDailyLimit = 0; // 0 = no global limit

    // Events
    event KYCUpdated(address indexed account, KYCStatus status, uint64 expiry);
    event AccreditationUpdated(address indexed account, bool isAccredited);
    event WalletBlacklisted(address indexed account, bool blacklisted);
    event CountryRestrictionUpdated(bytes2 indexed countryCode, bool restricted);
    event TransferLimitSet(address indexed account, uint256 limit);
    event ComplianceSettingsUpdated(bool requireKYC, bool requireAccreditation, bool enforceCountry);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ADMIN, admin);
        _grantRole(KYC_PROVIDER, admin);
    }

    // ==================== KYC Management ====================

    function setKYCStatus(
        address account,
        KYCStatus status,
        uint64 expiry
    ) external onlyRole(KYC_PROVIDER) {
        compliance[account].kycStatus = status;
        compliance[account].kycExpiry = expiry;
        emit KYCUpdated(account, status, expiry);
    }

    function batchSetKYC(
        address[] calldata accounts,
        KYCStatus status,
        uint64 expiry
    ) external onlyRole(KYC_PROVIDER) {
        for (uint256 i = 0; i < accounts.length; i++) {
            compliance[accounts[i]].kycStatus = status;
            compliance[accounts[i]].kycExpiry = expiry;
            emit KYCUpdated(accounts[i], status, expiry);
        }
    }

    function setAccreditation(address account, bool accredited) external onlyRole(COMPLIANCE_ADMIN) {
        compliance[account].isAccredited = accredited;
        emit AccreditationUpdated(account, accredited);
    }

    function setCountryCode(address account, bytes2 countryCode) external onlyRole(KYC_PROVIDER) {
        compliance[account].countryCode = countryCode;
    }

    // ==================== Blacklist Management ====================

    function blacklist(address account, bool status) external onlyRole(COMPLIANCE_ADMIN) {
        compliance[account].isBlacklisted = status;
        emit WalletBlacklisted(account, status);
    }

    function batchBlacklist(address[] calldata accounts, bool status) external onlyRole(COMPLIANCE_ADMIN) {
        for (uint256 i = 0; i < accounts.length; i++) {
            compliance[accounts[i]].isBlacklisted = status;
            emit WalletBlacklisted(accounts[i], status);
        }
    }

    // ==================== Country Restrictions ====================

    function setCountryRestriction(bytes2 countryCode, bool restricted) external onlyRole(COMPLIANCE_ADMIN) {
        restrictedCountries[countryCode] = restricted;
        emit CountryRestrictionUpdated(countryCode, restricted);
    }

    function batchSetCountryRestrictions(
        bytes2[] calldata countryCodes,
        bool restricted
    ) external onlyRole(COMPLIANCE_ADMIN) {
        for (uint256 i = 0; i < countryCodes.length; i++) {
            restrictedCountries[countryCodes[i]] = restricted;
            emit CountryRestrictionUpdated(countryCodes[i], restricted);
        }
    }

    // ==================== Transfer Limits ====================

    function setTransferLimit(address account, uint256 limit) external onlyRole(COMPLIANCE_ADMIN) {
        compliance[account].dailyTransferLimit = limit;
        emit TransferLimitSet(account, limit);
    }

    function recordTransfer(address account, uint256 value) external onlyRole(COMPLIANCE_ADMIN) {
        uint64 today = uint64(block.timestamp / 1 days);
        if (compliance[account].lastTransferDay < today) {
            compliance[account].dailyTransferred = 0;
            compliance[account].lastTransferDay = today;
        }
        compliance[account].dailyTransferred += value;
    }

    // ==================== Global Settings ====================

    function setComplianceSettings(
        bool _requireKYC,
        bool _requireAccreditation,
        bool _enforceCountry
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        requireKYC = _requireKYC;
        requireAccreditation = _requireAccreditation;
        enforceCountryRestrictions = _enforceCountry;
        emit ComplianceSettingsUpdated(_requireKYC, _requireAccreditation, _enforceCountry);
    }

    function setGlobalDailyLimit(uint256 limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalDailyLimit = limit;
    }

    // ==================== View Functions ====================

    function canTransfer(address from, address to, uint256 /* tokenId */)
        external
        view
        override
        returns (bool)
    {
        // Minting (from = 0) - only check receiver
        if (from == address(0)) {
            return _isCompliant(to);
        }

        // Burning (to = 0) - only check sender
        if (to == address(0)) {
            return _isCompliant(from);
        }

        // Transfer - check both parties
        return _isCompliant(from) && _isCompliant(to);
    }

    function _isCompliant(address account) internal view returns (bool) {
        WalletCompliance storage c = compliance[account];

        // Check blacklist
        if (c.isBlacklisted) return false;

        // Check KYC if required
        if (requireKYC) {
            if (c.kycStatus != KYCStatus.Approved) return false;
            if (c.kycExpiry > 0 && c.kycExpiry < block.timestamp) return false;
        }

        // Check accreditation if required
        if (requireAccreditation && !c.isAccredited) return false;

        // Check country restrictions
        if (enforceCountryRestrictions && c.countryCode != bytes2(0)) {
            if (restrictedCountries[c.countryCode]) return false;
        }

        return true;
    }

    function isWhitelisted(address account) external view override returns (bool) {
        return _isCompliant(account);
    }

    function isAccredited(address account) external view override returns (bool) {
        return compliance[account].isAccredited;
    }

    function getKYCStatus(address account) external view override returns (uint8) {
        return uint8(compliance[account].kycStatus);
    }

    function getFullCompliance(address account) external view returns (WalletCompliance memory) {
        return compliance[account];
    }

    function checkTransferLimit(address account, uint256 value) external view returns (bool) {
        uint256 limit = compliance[account].dailyTransferLimit;
        if (limit == 0) limit = globalDailyLimit;
        if (limit == 0) return true; // No limit

        uint64 today = uint64(block.timestamp / 1 days);
        uint256 transferred = compliance[account].lastTransferDay < today
            ? 0
            : compliance[account].dailyTransferred;

        return transferred + value <= limit;
    }

    // ==================== Pause ====================

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
}
```

---

# MODULE 22: ZK COMPLIANCE

## Architecture

```
+-------------------------------------------------------------+
|                    ZK COMPLIANCE SYSTEM                         |
+-------------------------------------------------------------+
|                                                                 |
|  KYC Provider                                                   |
|      |                                                          |
|      v                                                          |
|  +--------------+    +--------------+                          |
|  |  ZK Circuit  |--->| Proof Gen    |                          |
|  |  (Circom)    |    | (snarkjs)    |                          |
|  +--------------+    +--------------+                          |
|                             |                                   |
|                             v                                   |
|                      +--------------+                           |
|                      |  ZK Proof    |                           |
|                      |  - age > 18  |                           |
|                      |  - country   |                           |
|                      |  - accredit  |                           |
|                      +--------------+                           |
|                             |                                   |
|                             v                                   |
|                      +--------------+                           |
|                      |  Verifier    |                           |
|                      |  Contract    |                           |
|                      +--------------+                           |
|                             |                                   |
|                             v                                   |
|                      +--------------+                           |
|                      |  NFT Access  |                           |
|                      |  Granted     |                           |
|                      +--------------+                           |
|                                                                 |
+-------------------------------------------------------------+
```

## ZK Verifier Contract

File: `contracts/compliance/ZKComplianceVerifier.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ZKComplianceVerifier
 * @notice Verifies ZK proofs for privacy-preserving KYC compliance
 */
contract ZKComplianceVerifier is AccessControl {
    bytes32 public constant VERIFIER_ADMIN = keccak256("VERIFIER_ADMIN");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    // Verification keys for different proof types
    mapping(bytes32 => VerificationKey) public verificationKeys;

    // User compliance attestations (no personal data stored)
    mapping(address => mapping(bytes32 => Attestation)) public attestations;

    // Proof nullifiers to prevent replay
    mapping(bytes32 => bool) public usedNullifiers;

    struct VerificationKey {
        uint256[2] alpha;
        uint256[2][2] beta;
        uint256[2][2] gamma;
        uint256[2][2] delta;
        uint256[2][] ic;
        bool active;
    }

    struct Attestation {
        bytes32 proofType;
        uint256 issuedAt;
        uint256 expiresAt;
        bool valid;
    }

    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // Proof types
    bytes32 public constant PROOF_AGE_OVER_18 = keccak256("AGE_OVER_18");
    bytes32 public constant PROOF_AGE_OVER_21 = keccak256("AGE_OVER_21");
    bytes32 public constant PROOF_COUNTRY_ALLOWED = keccak256("COUNTRY_ALLOWED");
    bytes32 public constant PROOF_ACCREDITED = keccak256("ACCREDITED_INVESTOR");
    bytes32 public constant PROOF_NOT_SANCTIONED = keccak256("NOT_SANCTIONED");
    bytes32 public constant PROOF_KYC_COMPLETE = keccak256("KYC_COMPLETE");

    event VerificationKeySet(bytes32 indexed proofType);
    event AttestationIssued(address indexed user, bytes32 indexed proofType, uint256 expiresAt);
    event AttestationRevoked(address indexed user, bytes32 indexed proofType);
    event ProofVerified(address indexed user, bytes32 indexed proofType, bytes32 nullifier);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ADMIN, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
    }

    /**
     * @notice Verify ZK proof and issue attestation
     */
    function verifyAndAttest(
        bytes32 proofType,
        Proof calldata proof,
        uint256[] calldata publicInputs,
        bytes32 nullifier,
        uint256 validityPeriod
    ) external returns (bool) {
        require(verificationKeys[proofType].active, "Proof type not supported");
        require(!usedNullifiers[nullifier], "Proof already used");

        // Verify the ZK proof
        bool valid = _verifyProof(proofType, proof, publicInputs);
        require(valid, "Invalid proof");

        // Mark nullifier as used
        usedNullifiers[nullifier] = true;

        // Issue attestation
        uint256 expiresAt = block.timestamp + validityPeriod;
        attestations[msg.sender][proofType] = Attestation({
            proofType: proofType,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            valid: true
        });

        emit ProofVerified(msg.sender, proofType, nullifier);
        emit AttestationIssued(msg.sender, proofType, expiresAt);

        return true;
    }

    /**
     * @notice Check if user has valid attestation
     */
    function hasValidAttestation(address user, bytes32 proofType)
        external
        view
        returns (bool)
    {
        Attestation storage att = attestations[user][proofType];
        return att.valid && att.expiresAt > block.timestamp;
    }

    /**
     * @notice Check multiple attestations
     */
    function hasAllAttestations(address user, bytes32[] calldata proofTypes)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < proofTypes.length; i++) {
            Attestation storage att = attestations[user][proofTypes[i]];
            if (!att.valid || att.expiresAt <= block.timestamp) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Internal proof verification (Groth16)
     */
    function _verifyProof(
        bytes32 proofType,
        Proof calldata proof,
        uint256[] calldata publicInputs
    ) internal view returns (bool) {
        VerificationKey storage vk = verificationKeys[proofType];
        require(publicInputs.length + 1 == vk.ic.length, "Invalid inputs length");

        // Compute linear combination of inputs
        uint256[2] memory vk_x = vk.ic[0];
        for (uint256 i = 0; i < publicInputs.length; i++) {
            (uint256 x, uint256 y) = _scalarMul(vk.ic[i + 1], publicInputs[i]);
            (vk_x[0], vk_x[1]) = _pointAdd(vk_x[0], vk_x[1], x, y);
        }

        // Pairing check
        return _pairingCheck(
            proof.a,
            proof.b,
            vk.alpha,
            vk.beta,
            vk_x,
            vk.gamma,
            proof.c,
            vk.delta
        );
    }

    /**
     * @notice Elliptic curve scalar multiplication
     */
    function _scalarMul(uint256[2] memory p, uint256 s)
        internal
        view
        returns (uint256, uint256)
    {
        uint256[3] memory input;
        input[0] = p[0];
        input[1] = p[1];
        input[2] = s;

        uint256[2] memory result;
        assembly {
            if iszero(staticcall(sub(gas(), 2000), 7, input, 0x60, result, 0x40)) {
                revert(0, 0)
            }
        }
        return (result[0], result[1]);
    }

    /**
     * @notice Elliptic curve point addition
     */
    function _pointAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
        internal
        view
        returns (uint256, uint256)
    {
        uint256[4] memory input;
        input[0] = x1;
        input[1] = y1;
        input[2] = x2;
        input[3] = y2;

        uint256[2] memory result;
        assembly {
            if iszero(staticcall(sub(gas(), 2000), 6, input, 0x80, result, 0x40)) {
                revert(0, 0)
            }
        }
        return (result[0], result[1]);
    }

    /**
     * @notice Pairing check for Groth16 verification
     */
    function _pairingCheck(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory alpha,
        uint256[2][2] memory beta,
        uint256[2] memory vk_x,
        uint256[2][2] memory gamma,
        uint256[2] memory c,
        uint256[2][2] memory delta
    ) internal view returns (bool) {
        uint256[24] memory input;

        // -A
        input[0] = a[0];
        input[1] = 21888242871839275222246405745257275088696311157297823662689037894645226208583 - a[1];
        input[2] = b[0][0];
        input[3] = b[0][1];
        input[4] = b[1][0];
        input[5] = b[1][1];

        // alpha * beta
        input[6] = alpha[0];
        input[7] = alpha[1];
        input[8] = beta[0][0];
        input[9] = beta[0][1];
        input[10] = beta[1][0];
        input[11] = beta[1][1];

        // vk_x * gamma
        input[12] = vk_x[0];
        input[13] = vk_x[1];
        input[14] = gamma[0][0];
        input[15] = gamma[0][1];
        input[16] = gamma[1][0];
        input[17] = gamma[1][1];

        // C * delta
        input[18] = c[0];
        input[19] = c[1];
        input[20] = delta[0][0];
        input[21] = delta[0][1];
        input[22] = delta[1][0];
        input[23] = delta[1][1];

        uint256[1] memory result;
        assembly {
            if iszero(staticcall(sub(gas(), 2000), 8, input, 0x300, result, 0x20)) {
                revert(0, 0)
            }
        }
        return result[0] == 1;
    }

    // ==================== Admin Functions ====================

    function setVerificationKey(
        bytes32 proofType,
        uint256[2] calldata alpha,
        uint256[2][2] calldata beta,
        uint256[2][2] calldata gamma,
        uint256[2][2] calldata delta,
        uint256[2][] calldata ic
    ) external onlyRole(VERIFIER_ADMIN) {
        verificationKeys[proofType] = VerificationKey({
            alpha: alpha,
            beta: beta,
            gamma: gamma,
            delta: delta,
            ic: ic,
            active: true
        });
        emit VerificationKeySet(proofType);
    }

    function deactivateProofType(bytes32 proofType) external onlyRole(VERIFIER_ADMIN) {
        verificationKeys[proofType].active = false;
    }

    function revokeAttestation(address user, bytes32 proofType)
        external
        onlyRole(ISSUER_ROLE)
    {
        attestations[user][proofType].valid = false;
        emit AttestationRevoked(user, proofType);
    }

    function issueAttestation(
        address user,
        bytes32 proofType,
        uint256 validityPeriod
    ) external onlyRole(ISSUER_ROLE) {
        uint256 expiresAt = block.timestamp + validityPeriod;
        attestations[user][proofType] = Attestation({
            proofType: proofType,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            valid: true
        });
        emit AttestationIssued(user, proofType, expiresAt);
    }
}
```

---

# MODULE 15: LEGAL TEMPLATES & COMPLIANCE

## Legal Structure for RWA Tokenization

```
LEGAL STRUCTURE FOR RWA TOKENIZATION

                        +---------------------+
                        |   REAL WORLD ASSET  |
                        |  (Property/Art/etc) |
                        +----------+----------+
                                   |
                                   v
                        +---------------------+
                        |    LEGAL ENTITY     |
                        |   (SPV / LLC / Trust)|
                        |                     |
                        |  Holds legal title  |
                        |  to underlying asset|
                        +----------+----------+
                                   |
                    +--------------+--------------+
                    |              |              |
                    v              v              v
          +-------------+ +-------------+ +-------------+
          |  CUSTODIAN  | |  INSURANCE  | |   ORACLE    |
          |             | |             | |             |
          | Verifies    | | Protects    | | Reports     |
          | asset exists| | against loss| | asset status|
          +------+------+ +------+------+ +------+------+
                 |               |               |
                 +---------------+---------------+
                                 |
                                 v
                        +---------------------+
                        |   NFT SMART CONTRACT|
                        |                     |
                        |  - Represents claim |
                        |  - Enforces rules   |
                        |  - Tracks ownership |
                        +----------+----------+
                                   |
                                   v
                        +---------------------+
                        |   TOKEN HOLDERS     |
                        |                     |
                        |  - Beneficial owners|
                        |  - Voting rights    |
                        |  - Redemption rights|
                        +---------------------+
```

## SPV Operating Agreement Template

```markdown
# SPECIAL PURPOSE VEHICLE OPERATING AGREEMENT

## Article 1: Formation and Purpose

1.1 **Name**: [Asset Name] Holdings LLC

1.2 **Purpose**: The sole purpose of this LLC is to:
    (a) Hold legal title to the Asset (defined below)
    (b) Issue NFT tokens representing beneficial ownership interests
    (c) Manage the Asset for the benefit of token holders
    (d) Distribute proceeds from the Asset to token holders

1.3 **Registered Agent**: [Legal registered agent name and address]

## Article 2: Asset Description

2.1 **Asset**: [Detailed description of the underlying asset]
    - Type: [Real Estate / Art / Securities / Other]
    - Location: [Physical location if applicable]
    - Valuation: $[Amount] as of [Date]
    - Appraisal: [Appraiser name and credentials]

2.2 **Documentation**: All asset documentation is stored:
    - On-chain reference: [IPFS CID / Arweave TX]
    - Physical copies: [Custodian name and location]

## Article 3: Token Structure

3.1 **Total Tokens**: [Number] NFTs representing 100% beneficial interest

3.2 **Token Contract**: [Smart contract address on specified blockchain]

3.3 **Rights per Token**: Each token represents:
    - [Percentage]% beneficial ownership interest
    - Pro-rata distribution rights
    - Voting rights (if applicable)
    - Redemption rights (subject to conditions)

## Article 4: Governance

4.1 **Major Decisions**: Require [X]% token holder approval:
    - Sale of underlying asset
    - Material modifications to asset
    - Change of custodian
    - Dissolution of SPV

4.2 **Voting Mechanism**: On-chain governance via [Governor contract address]

4.3 **Quorum**: [X]% of tokens must participate for valid vote

## Article 5: Distributions

5.1 **Revenue Distribution**: Net proceeds distributed quarterly via:
    - Smart contract: [RoyaltyRouter address]
    - Pro-rata based on token holdings at snapshot date

5.2 **Expenses**: Deducted before distribution:
    - Insurance premiums
    - Maintenance costs
    - Management fees ([X]%)
    - Legal/compliance costs

## Article 6: Transfer Restrictions

6.1 **KYC/AML**: All token holders must complete KYC verification

6.2 **Accredited Investors**: [If applicable] Only accredited investors may hold tokens

6.3 **Restricted Jurisdictions**: Tokens may not be held by residents of:
    - [List of restricted jurisdictions]

6.4 **Compliance Contract**: [ComplianceRegistry address]

## Article 7: Redemption

7.1 **Redemption Events**:
    - Sale of underlying asset
    - Dissolution of SPV
    - Token holder buyout (if enabled)

7.2 **Process**:
    1. Token holder burns tokens via smart contract
    2. SPV processes claim within [X] days
    3. Proceeds distributed to wallet address

## Article 8: Dissolution

8.1 **Triggers**:
    - Sale of asset
    - [X]% token holder vote
    - Regulatory requirement

8.2 **Process**:
    1. Liquidate asset
    2. Pay outstanding obligations
    3. Distribute remaining proceeds to token holders
    4. Burn all tokens
    5. Dissolve legal entity

## Signatures

Manager: _________________________ Date: _________

Witness: _________________________ Date: _________
```

## Token Holder Agreement

```markdown
# NFT TOKEN HOLDER AGREEMENT

By acquiring, holding, or transferring the NFT tokens described herein,
the holder ("Token Holder") agrees to the following terms:

## 1. Nature of Token

1.1 The NFT token represents a beneficial ownership interest in the
    underlying asset held by [SPV Name] LLC (the "SPV").

1.2 The token does NOT represent:
    - Direct legal ownership of the asset
    - A security (unless specifically registered)
    - A guarantee of returns

## 2. Compliance Obligations

2.1 Token Holder represents and warrants:
    - Completed KYC/AML verification
    - Not a resident of restricted jurisdictions
    - [If applicable] Qualifies as accredited investor
    - Will maintain compliance throughout holding period

2.2 Token Holder acknowledges:
    - Transfers may be restricted by smart contract
    - Non-compliant wallets cannot receive tokens
    - False representations may result in token forfeiture

## 3. Rights and Obligations

3.1 Token Holder is entitled to:
    - Pro-rata share of distributions
    - Voting rights on major decisions
    - Access to asset documentation
    - Redemption upon qualifying events

3.2 Token Holder agrees to:
    - Maintain accurate contact information
    - Participate in governance in good faith
    - Not circumvent transfer restrictions
    - Report any compliance status changes

## 4. Risks

Token Holder acknowledges the following risks:
    - Asset value may decrease
    - Smart contract may have vulnerabilities
    - Regulatory environment may change
    - Liquidity may be limited
    - Redemption may be delayed

## 5. Limitation of Liability

The SPV, its managers, and service providers shall not be liable for:
    - Market value fluctuations
    - Smart contract failures (unless negligent)
    - Force majeure events
    - Third-party actions

## 6. Dispute Resolution

6.1 Governing Law: [Jurisdiction]

6.2 Disputes shall be resolved by:
    - First: Good faith negotiation
    - Second: Mediation
    - Third: Binding arbitration in [Location]

## 7. Acceptance

By interacting with the token smart contract, Token Holder confirms:
    - Reading and understanding this agreement
    - Meeting all eligibility requirements
    - Accepting all terms and conditions

Agreement Version: 1.0
Last Updated: [Date]
Contract Address: [NFT Contract Address]
```

## Regulatory Considerations

```
REGULATORY FRAMEWORK BY JURISDICTION

UNITED STATES
- Securities Law
    - Howey Test determines if token is a security
    - If security: Register with SEC or use exemption
    - Reg D (506b, 506c) - Accredited investors only
    - Reg A+ - Up to $75M, requires qualification
    - Reg S - Non-US persons only
- Money Transmission
    - Consider FinCEN registration
    - State-by-state analysis required
- Tax Treatment
    - IRS treats as property
    - Capital gains on sale

EUROPEAN UNION
- MiCA Regulation (2024+)
    - Asset-referenced tokens
    - E-money tokens
    - Other crypto-assets
- Securities Prospectus Regulation
    - If classified as security
- AML Directive (AMLD6)
    - KYC/AML requirements

UNITED KINGDOM
- FCA Regulatory Perimeter
    - Security tokens - regulated
    - E-money tokens - regulated
    - Unregulated tokens - minimal oversight
- Financial Promotion Rules

SINGAPORE
- MAS Guidelines
    - Digital Payment Tokens
    - Securities Tokens
- Payment Services Act

SWITZERLAND
- FINMA Guidelines
    - Payment tokens
    - Utility tokens
    - Asset tokens (securities)
- DLT Framework

RECOMMENDED APPROACH
1. Classify token correctly per jurisdiction
2. Implement robust KYC/AML
3. Use compliant transfer restrictions
4. Maintain proper documentation
5. Engage local legal counsel
6. Plan for regulatory changes
```

---
