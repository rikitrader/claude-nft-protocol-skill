// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IBackingOracle.sol";
import "./BackedToken.sol";

/**
 * @title SecureMintPolicy
 * @author SecureMintEngine
 * @notice Oracle-gated mint policy that enforces ALL 6 conditions before
 *         any token can be minted. This is the core contract of the
 *         SecureMintEngine protocol.
 *
 * @dev Mint Conditions (ALL must hold for mint() to succeed):
 *
 *      1. Verified backing >= post-mint totalSupply
 *      2. Oracle reports healthy (isHealthy() == true)
 *      3. Oracle data is not stale (age < maxStaleness)
 *      4. Oracle deviation is within bounds (< maxDeviation)
 *      5. Mint amount <= per-epoch rate limit
 *      6. totalSupply + amount <= global supply cap
 *      7. Contract is NOT paused
 *      8. Caller has OPERATOR_ROLE
 *
 *      If ANY condition fails, mint() MUST revert.
 *
 *      Configuration changes (caps, oracle address) are timelocked.
 */
contract SecureMintPolicy is AccessControl, Pausable, ReentrancyGuard {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Operators can execute mints (after all conditions are verified).
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Admins can propose configuration changes (timelocked).
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Guardians can trigger emergency pause.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error BackingInsufficient(uint256 backing, uint256 postMintSupply);
    error OracleUnhealthy();
    error OracleStale(uint256 lastUpdate, uint256 maxAge);
    error OracleDeviationExceeded(uint256 deviation, uint256 maxDeviation);
    error EpochCapExceeded(uint256 requested, uint256 remaining);
    error GlobalSupplyCapExceeded(uint256 postMintSupply, uint256 globalCap);
    error TimelockNotElapsed(uint256 availableAt);
    error NoPendingChange();
    error UnauthorizedCaller();
    error EmergencyPauseAlreadySet();

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    event Minted(
        address indexed to,
        uint256 amount,
        uint256 newTotalSupply,
        uint256 oracleBacking,
        uint256 timestamp
    );

    event EpochReset(
        uint256 indexed epochNumber,
        uint256 timestamp
    );

    event ConfigChangeProposed(
        bytes32 indexed changeId,
        string description,
        uint256 availableAt
    );

    event ConfigChangeExecuted(bytes32 indexed changeId);
    event ConfigChangeCancelled(bytes32 indexed changeId);

    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct PendingChange {
        bytes32 changeId;
        uint256 availableAt;
        bytes data;
        bool exists;
    }

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice The BackedToken contract this policy controls minting for.
    BackedToken public immutable backedToken;

    /// @notice The backing oracle consulted before every mint.
    IBackingOracle public oracle;

    /// @notice Global maximum supply cap (base units). 0 = unlimited.
    uint256 public globalSupplyCap;

    /// @notice Maximum tokens that can be minted per epoch (base units).
    uint256 public epochMintCap;

    /// @notice Duration of a single epoch in seconds (default: 24 hours).
    uint256 public epochDuration;

    /// @notice Maximum staleness for oracle data (seconds).
    uint256 public maxStaleness;

    /// @notice Maximum acceptable oracle deviation (basis points).
    uint256 public maxDeviation;

    /// @notice Timelock delay for configuration changes (seconds).
    uint256 public immutable timelockDelay;

    // --- Epoch tracking ---

    /// @notice Start timestamp of the current epoch.
    uint256 public epochStart;

    /// @notice Amount minted so far in the current epoch.
    uint256 public epochMinted;

    /// @notice Monotonically increasing epoch counter.
    uint256 public epochNumber;

    // --- Timelock ---

    /// @notice Pending timelocked configuration changes.
    mapping(bytes32 => PendingChange) public pendingChanges;

    /// @notice Address of the EmergencyPause contract (for integration hook verification).
    address public emergencyPause;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @param backedToken_   Address of the BackedToken contract.
     * @param oracle_        Address of the IBackingOracle implementation.
     * @param globalCap_     Initial global supply cap (0 = unlimited).
     * @param epochCap_      Initial per-epoch mint cap.
     * @param epochDuration_ Epoch duration in seconds.
     * @param maxStaleness_  Oracle staleness threshold in seconds.
     * @param maxDeviation_  Oracle deviation threshold in basis points.
     * @param timelockDelay_ Timelock delay for config changes in seconds.
     * @param admin          Initial admin address.
     */
    constructor(
        address backedToken_,
        address oracle_,
        uint256 globalCap_,
        uint256 epochCap_,
        uint256 epochDuration_,
        uint256 maxStaleness_,
        uint256 maxDeviation_,
        uint256 timelockDelay_,
        address admin
    ) {
        if (backedToken_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();

        backedToken = BackedToken(backedToken_);
        oracle = IBackingOracle(oracle_);
        globalSupplyCap = globalCap_;
        epochMintCap = epochCap_;
        epochDuration = epochDuration_;
        maxStaleness = maxStaleness_;
        maxDeviation = maxDeviation_;
        timelockDelay = timelockDelay_;

        epochStart = block.timestamp;
        epochNumber = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // -------------------------------------------------------------------
    //  External — Mint (OPERATOR_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Mints `amount` tokens to `to` after verifying ALL conditions.
     * @dev Reverts if any of the 6 mint conditions fail.
     * @param to     Recipient address.
     * @param amount Number of tokens to mint (base units).
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // --- Epoch management ---
        _advanceEpochIfNeeded();

        // --- Condition 1: Backing >= post-mint supply ---
        uint256 postMintSupply = backedToken.totalSupply() + amount;
        uint256 backing = oracle.getBackingAmount();
        if (backing < postMintSupply) {
            revert BackingInsufficient(backing, postMintSupply);
        }

        // --- Condition 2: Oracle is healthy ---
        if (!oracle.isHealthy()) {
            revert OracleUnhealthy();
        }

        // --- Condition 3: Oracle data is not stale ---
        uint256 lastUpdate = oracle.lastUpdate();
        // slither-disable-next-line timestamp
        if (block.timestamp - lastUpdate > maxStaleness) {
            revert OracleStale(lastUpdate, maxStaleness);
        }

        // --- Condition 4: Oracle deviation within bounds ---
        uint256 dev = oracle.deviation();
        if (dev > maxDeviation) {
            revert OracleDeviationExceeded(dev, maxDeviation);
        }

        // --- Condition 5: Epoch rate limit ---
        uint256 remaining = epochMintCap > epochMinted ? epochMintCap - epochMinted : 0;
        if (amount > remaining) {
            revert EpochCapExceeded(amount, remaining);
        }

        // --- Condition 6: Global supply cap ---
        if (globalSupplyCap > 0 && postMintSupply > globalSupplyCap) {
            revert GlobalSupplyCapExceeded(postMintSupply, globalSupplyCap);
        }

        // --- All conditions passed — execute mint ---
        epochMinted += amount;
        backedToken.mint(to, amount);

        emit Minted(to, amount, backedToken.totalSupply(), backing, block.timestamp);
    }

    // -------------------------------------------------------------------
    //  External — Pause (GUARDIAN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Emergency pause — immediately halts all minting.
     */
    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause minting operations.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Called by EmergencyPause when pause level changes.
     * @dev Level 0: unpause minting. Level 1+: pause minting.
     *      Only callable by the registered EmergencyPause contract.
     * @param level The new pause level (0=Normal, 1=MintPaused, 2=Restricted, 3=FullFreeze).
     */
    function onPauseLevelChanged(uint8 level) external {
        if (msg.sender != emergencyPause) revert UnauthorizedCaller();
        if (level >= 1) {
            if (!paused()) _pause();
        } else {
            if (paused()) _unpause();
        }
    }

    /**
     * @notice One-time initializer for the EmergencyPause contract address.
     * @dev After initial setup, use proposeEmergencyPauseChange/executeEmergencyPauseChange.
     * @param emergencyPause_ Address of the EmergencyPause contract.
     */
    function setEmergencyPause(address emergencyPause_) external onlyRole(ADMIN_ROLE) {
        if (emergencyPause != address(0)) revert EmergencyPauseAlreadySet();
        if (emergencyPause_ == address(0)) revert ZeroAddress();
        emergencyPause = emergencyPause_;
    }

    /**
     * @notice Proposes a timelocked change to the EmergencyPause contract address.
     * @param newPause The new EmergencyPause contract address.
     */
    function proposeEmergencyPauseChange(address newPause) external onlyRole(ADMIN_ROLE) {
        if (newPause == address(0)) revert ZeroAddress();
        bytes32 changeId = keccak256(abi.encode("emergencyPause", newPause, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newPause),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "emergencyPause", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed EmergencyPause address change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEmergencyPauseChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        emergencyPause = abi.decode(change.data, (address));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    // -------------------------------------------------------------------
    //  External — Timelocked Configuration
    // -------------------------------------------------------------------

    /**
     * @notice Proposes a change to the global supply cap (timelocked).
     * @param newCap The new global supply cap.
     */
    function proposeGlobalCapChange(
        uint256 newCap
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 changeId = keccak256(abi.encode("globalSupplyCap", newCap, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newCap),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "globalSupplyCap", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed global cap change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeGlobalCapChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        globalSupplyCap = abi.decode(change.data, (uint256));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Proposes a change to the epoch mint cap (timelocked).
     * @param newCap The new epoch mint cap.
     */
    function proposeEpochCapChange(
        uint256 newCap
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 changeId = keccak256(abi.encode("epochMintCap", newCap, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newCap),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "epochMintCap", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed epoch cap change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEpochCapChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        epochMintCap = abi.decode(change.data, (uint256));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Proposes a change to the oracle address (timelocked).
     * @param newOracle The new oracle address.
     */
    function proposeOracleChange(
        address newOracle
    ) external onlyRole(ADMIN_ROLE) {
        if (newOracle == address(0)) revert ZeroAddress();
        bytes32 changeId = keccak256(abi.encode("oracle", newOracle, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newOracle),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "oracle", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed oracle change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeOracleChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        oracle = IBackingOracle(abi.decode(change.data, (address)));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Proposes a change to the maxStaleness threshold (timelocked).
     * @param newMaxStaleness The new maxStaleness value in seconds.
     */
    function proposeMaxStalenessChange(
        uint256 newMaxStaleness
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 changeId = keccak256(abi.encode("maxStaleness", newMaxStaleness, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newMaxStaleness),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "maxStaleness", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed maxStaleness change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeMaxStalenessChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        maxStaleness = abi.decode(change.data, (uint256));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Proposes a change to the maxDeviation threshold (timelocked).
     * @param newMaxDeviation The new maxDeviation value in basis points.
     */
    function proposeMaxDeviationChange(
        uint256 newMaxDeviation
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 changeId = keccak256(abi.encode("maxDeviation", newMaxDeviation, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newMaxDeviation),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "maxDeviation", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed maxDeviation change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeMaxDeviationChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        maxDeviation = abi.decode(change.data, (uint256));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Proposes a change to the epochDuration (timelocked).
     * @param newEpochDuration The new epoch duration in seconds.
     */
    function proposeEpochDurationChange(
        uint256 newEpochDuration
    ) external onlyRole(ADMIN_ROLE) {
        bytes32 changeId = keccak256(abi.encode("epochDuration", newEpochDuration, block.timestamp));
        pendingChanges[changeId] = PendingChange({
            changeId: changeId,
            availableAt: block.timestamp + timelockDelay,
            data: abi.encode(newEpochDuration),
            exists: true
        });
        emit ConfigChangeProposed(changeId, "epochDuration", block.timestamp + timelockDelay);
    }

    /**
     * @notice Executes a previously proposed epochDuration change.
     * @param changeId The change identifier from the proposal event.
     */
    function executeEpochDurationChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        PendingChange storage change = pendingChanges[changeId];
        if (!change.exists) revert NoPendingChange();
        // slither-disable-next-line timestamp
        if (block.timestamp < change.availableAt) revert TimelockNotElapsed(change.availableAt);

        epochDuration = abi.decode(change.data, (uint256));
        delete pendingChanges[changeId];
        emit ConfigChangeExecuted(changeId);
    }

    /**
     * @notice Cancels a pending timelocked change.
     * @param changeId The change identifier to cancel.
     */
    function cancelChange(bytes32 changeId) external onlyRole(ADMIN_ROLE) {
        if (!pendingChanges[changeId].exists) revert NoPendingChange();
        delete pendingChanges[changeId];
        emit ConfigChangeCancelled(changeId);
    }

    // -------------------------------------------------------------------
    //  External — View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the remaining mintable amount in the current epoch.
     */
    function epochRemaining() external view returns (uint256) {
        return epochMintCap > epochMinted ? epochMintCap - epochMinted : 0;
    }

    /**
     * @notice Returns the remaining amount under the global supply cap.
     */
    function globalRemaining() external view returns (uint256) {
        if (globalSupplyCap == 0) return type(uint256).max;
        uint256 supply = backedToken.totalSupply();
        return globalSupplyCap > supply ? globalSupplyCap - supply : 0;
    }

    // -------------------------------------------------------------------
    //  Internal
    // -------------------------------------------------------------------

    /**
     * @dev Advances to the next epoch if the current one has expired.
     *      Uses time-window based advancement (epochStart += epochDuration)
     *      instead of resetting to block.timestamp to prevent epoch boundary
     *      race conditions where two mints in the same block could both
     *      get fresh epoch allocation.
     */
    function _advanceEpochIfNeeded() internal {
        // slither-disable-next-line timestamp
        while (block.timestamp >= epochStart + epochDuration) {
            epochStart += epochDuration;
            epochMinted = 0;
            epochNumber += 1;
            emit EpochReset(epochNumber, block.timestamp);
        }
    }
}
