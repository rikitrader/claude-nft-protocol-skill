# Cross-Chain Mirror Strategy (ETH/Base)

## Canonical Supply Model

```
┌─────────────────────────────────────────────────────────────┐
│                 CROSS-CHAIN ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SOLANA = CANONICAL SUPPLY (Source of Truth)                 │
│  ETH/BASE = WRAPPED MIRRORS ONLY                             │
│                                                              │
│  ┌─────────────────┐       ┌─────────────────┐              │
│  │    SOLANA       │       │   ETH / BASE    │              │
│  │                 │       │                 │              │
│  │  1B Total Supply│       │  0 Native Mint  │              │
│  │  (Immutable)    │       │  (Mirror Only)  │              │
│  └────────┬────────┘       └────────┬────────┘              │
│           │                         │                        │
│           │    BRIDGE PROTOCOL      │                        │
│           └────────────┬────────────┘                        │
│                        │                                     │
│              ┌─────────┴─────────┐                          │
│              │ Lock on Solana    │                          │
│              │ Mint on ETH/Base  │                          │
│              │                   │                          │
│              │ Burn on ETH/Base  │                          │
│              │ Unlock on Solana  │                          │
│              └───────────────────┘                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Core Rules

1. **No Independent Minting**
   - ETH/Base contracts CANNOT mint without Solana lock proof
   - Supply parity enforced at all times

2. **Solana Canonical**
   - Total supply defined on Solana
   - All governance on Solana
   - ETH/Base are liquidity extensions only

3. **Reversible Bridges**
   - Lock → Mint (Solana → EVM)
   - Burn → Unlock (EVM → Solana)

## Bridge Flow

### Solana → ETH/Base (Lock & Mint)

```
User wants ETH tokens:
1. User locks tokens in Solana Bridge Vault
2. Bridge oracle verifies lock transaction
3. EVM MirrorBridgeGate mints equivalent wrapped tokens
4. User receives wrapped tokens on ETH/Base
```

### ETH/Base → Solana (Burn & Unlock)

```
User wants to return to Solana:
1. User calls burn on EVM WrappedMeme
2. MirrorBridgeGate logs burn event
3. Bridge oracle verifies burn
4. Solana Bridge Vault unlocks equivalent tokens
5. User receives native tokens on Solana
```

## EVM Contract Requirements

### WrappedMeme.sol (ERC-20)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedMeme is ERC20, Ownable {
    address public bridgeGate;
    address public pendingBridgeGate;

    event BridgeMint(address indexed to, uint256 amount, bytes32 indexed solanaTxHash);
    event BridgeBurn(address indexed from, uint256 amount, bytes32 indexed solanaRecipient);
    event BridgeGateProposed(address indexed proposed);
    event BridgeGateUpdated(address indexed oldGate, address indexed newGate);

    modifier onlyBridge() {
        require(msg.sender == bridgeGate, "Only bridge can mint/burn");
        _;
    }

    constructor() ERC20("Wrapped Meme", "wMEME") Ownable(msg.sender) {}

    /// @notice Propose a new bridge gate (two-step transfer to prevent bricking)
    function proposeBridgeGate(address _gate) external onlyOwner {
        require(_gate != address(0), "Invalid gate address");
        pendingBridgeGate = _gate;
        emit BridgeGateProposed(_gate);
    }

    /// @notice Accept bridge gate role (must be called by the pending gate)
    function acceptBridgeGate() external {
        require(msg.sender == pendingBridgeGate, "Not pending gate");
        address oldGate = bridgeGate;
        bridgeGate = pendingBridgeGate;
        pendingBridgeGate = address(0);
        emit BridgeGateUpdated(oldGate, bridgeGate);
    }

    function bridgeMint(
        address to,
        uint256 amount,
        bytes32 solanaTxHash
    ) external onlyBridge {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        _mint(to, amount);
        emit BridgeMint(to, amount, solanaTxHash);
    }

    function bridgeBurn(
        uint256 amount,
        bytes32 solanaRecipient
    ) external {
        require(amount > 0, "Amount must be > 0");
        require(solanaRecipient != bytes32(0), "Invalid Solana recipient");
        _burn(msg.sender, amount);
        emit BridgeBurn(msg.sender, amount, solanaRecipient);
    }

    // NO PUBLIC MINT FUNCTION
    // NO OWNER MINT FUNCTION
}
```

### MirrorBridgeGate.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol"; // OZ v5 path

interface IWrappedMeme {
    function bridgeMint(address to, uint256 amount, bytes32 solanaTxHash) external;
}

interface IVerifier {
    function verifySolanaLock(
        bytes32 txHash,
        address recipient,
        uint256 amount
    ) external view returns (bool);
}

contract MirrorBridgeGate is Ownable, Pausable {
    IWrappedMeme public wrappedToken;
    IVerifier public verifier;

    uint256 public dailyMintLimit;
    uint256 public dailyMinted;
    uint256 public lastResetTimestamp;

    mapping(bytes32 => bool) public processedLocks;
    mapping(address => bool) public authorizedRelayers;

    event LockProcessed(bytes32 indexed solanaTxHash, address indexed recipient, uint256 amount);
    event VerifierUpdated(address indexed newVerifier);
    event RelayerUpdated(address indexed relayer, bool authorized);
    event DailyLimitUpdated(uint256 newLimit);

    error NotAuthorizedRelayer();
    error AlreadyProcessed();
    error InvalidLockProof();
    error DailyLimitExceeded();
    error InvalidAddress();
    error InvalidAmount();

    modifier onlyRelayer() {
        if (!authorizedRelayers[msg.sender]) revert NotAuthorizedRelayer();
        _;
    }

    constructor(
        address _wrappedToken,
        address _verifier,
        uint256 _dailyLimit
    ) Ownable(msg.sender) {
        require(_wrappedToken != address(0), "Invalid wrapped token");
        require(_verifier != address(0), "Invalid verifier");
        require(_dailyLimit > 0, "Invalid daily limit");
        wrappedToken = IWrappedMeme(_wrappedToken);
        verifier = IVerifier(_verifier);
        dailyMintLimit = _dailyLimit;
        lastResetTimestamp = block.timestamp;
    }

    /// @notice Process a verified Solana lock — restricted to authorized relayers
    function processLock(
        bytes32 solanaTxHash,
        address recipient,
        uint256 amount
    ) external whenNotPaused onlyRelayer {
        if (processedLocks[solanaTxHash]) revert AlreadyProcessed();
        if (recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (!verifier.verifySolanaLock(solanaTxHash, recipient, amount))
            revert InvalidLockProof();

        // Reset daily limit using calendar-day normalization (prevents boundary manipulation)
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lastResetDay = lastResetTimestamp / 1 days;
        if (currentDay > lastResetDay) {
            dailyMinted = 0;
            lastResetTimestamp = block.timestamp;
        }

        if (dailyMinted + amount > dailyMintLimit) revert DailyLimitExceeded();

        // CEI: state changes before external call
        processedLocks[solanaTxHash] = true;
        dailyMinted += amount;

        wrappedToken.bridgeMint(recipient, amount, solanaTxHash);

        emit LockProcessed(solanaTxHash, recipient, amount);
    }

    function setRelayer(address _relayer, bool _authorized) external onlyOwner {
        if (_relayer == address(0)) revert InvalidAddress();
        authorizedRelayers[_relayer] = _authorized;
        emit RelayerUpdated(_relayer, _authorized);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setVerifier(address _verifier) external onlyOwner {
        if (_verifier == address(0)) revert InvalidAddress();
        verifier = IVerifier(_verifier);
        emit VerifierUpdated(_verifier);
    }

    function setDailyLimit(uint256 _limit) external onlyOwner {
        require(_limit > 0, "Invalid daily limit");
        dailyMintLimit = _limit;
        emit DailyLimitUpdated(_limit);
    }
}
```

## Supply Parity Enforcement

### Monitoring Requirements

| Metric | Check Frequency | Alert Threshold |
|--------|-----------------|-----------------|
| Solana locked balance | Every block | Mismatch > 0.1% |
| EVM total supply | Every block | != Solana locked |
| Bridge tx queue | 5 minutes | Queue > 100 |
| Daily mint volume | Hourly | > 80% of limit |

### Parity Formula

```
Solana_Circulating = Total_Supply - Locked_In_Bridge
EVM_Total_Supply = Locked_In_Bridge

INVARIANT: Solana_Circulating + EVM_Total_Supply = Total_Supply
```

## Security Considerations

### Bridge Attack Vectors

1. **Fake Lock Proofs**
   - Mitigation: Cryptographic verification of Solana transactions
   - Multiple oracle confirmation

2. **Double Minting**
   - Mitigation: processedLocks mapping
   - Unique tx hash requirement

3. **Bridge Pause Attack**
   - Mitigation: Time-limited pauses
   - Multi-sig unpause

4. **Oracle Manipulation**
   - Mitigation: Decentralized oracle network
   - Threshold signatures

### Operational Security

- [ ] Bridge contracts audited
- [ ] Verifier logic audited
- [ ] Rate limits configured
- [ ] Authorized relayers configured (processLock restricted)
- [ ] Two-step bridgeGate transfer completed
- [ ] Multi-sig on admin functions (owner)
- [ ] Zero-address validation tested
- [ ] Monitoring active
- [ ] Incident response documented

## Deployment Sequence

1. **Deploy EVM Contracts**
   ```bash
   # Deploy WrappedMeme
   forge create WrappedMeme --rpc-url $RPC

   # Deploy MirrorBridgeGate
   forge create MirrorBridgeGate \
     --constructor-args $WRAPPED $VERIFIER $LIMIT \
     --rpc-url $RPC
   ```

2. **Configure Bridge**
   ```bash
   # Propose bridge gate on wrapped token (two-step transfer)
   cast send $WRAPPED "proposeBridgeGate(address)" $GATE --rpc-url $RPC

   # Accept from the gate contract (or via owner if gate has acceptor logic)
   cast send $WRAPPED "acceptBridgeGate()" --from $GATE --rpc-url $RPC

   # Authorize relayer(s) on the bridge gate
   cast send $GATE "setRelayer(address,bool)" $RELAYER true --rpc-url $RPC
   ```

3. **Deploy Solana Bridge Vault**
   - PDA-controlled vault
   - Only bridge can lock/unlock
   - Integrated with token program

4. **Deploy Verifier**
   - Oracle integration
   - Signature verification
   - Rate limiting

## Why This Model Works

1. **Regulatory Clarity**
   - Single canonical supply
   - Clear chain of custody
   - Auditable cross-chain flow

2. **Security**
   - No independent minting
   - Cryptographic proofs
   - Rate limiting

3. **Liquidity**
   - Access ETH/Base liquidity
   - Maintain Solana virality
   - Best of both worlds

4. **Upgradability**
   - Verifier can be upgraded
   - Rate limits adjustable
   - Pause for emergencies
