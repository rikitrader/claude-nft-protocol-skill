// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBackingOracle.sol";

/**
 * @title TreasuryVault
 * @author SecureMintEngine
 * @notice Reserve custody contract implementing a 4-tier collateral management
 *         system with automated rebalancing, redemption processing, and oracle
 *         integration.
 *
 * @dev Reserve tier structure:
 *
 *      | Tier | Name | Target Allocation | Purpose                      |
 *      |------|------|-------------------|------------------------------|
 *      | T0   | Hot  |  5 - 10%          | Instant redemptions          |
 *      | T1   | Warm | 15 - 25%          | Same-day redemptions         |
 *      | T2   | Cold | 50 - 60%          | Long-term secure storage     |
 *      | T3   | RWA  | 10 - 20%          | Real-world asset backing     |
 */
contract TreasuryVault is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Enums
    // -------------------------------------------------------------------

    enum Tier {
        T0_HOT,
        T1_WARM,
        T2_COLD,
        T3_RWA
    }

    // -------------------------------------------------------------------
    //  Structs
    // -------------------------------------------------------------------

    struct TierConfig {
        uint256 minAllocationBps;
        uint256 maxAllocationBps;
        uint256 withdrawalLimit;
        uint256 cooldownPeriod;
        uint256 lastWithdrawal;
        uint256 balance;
    }

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error WithdrawalLimitExceeded(Tier tier, uint256 requested, uint256 limit);
    error CooldownNotElapsed(Tier tier, uint256 cooldownEndsAt);
    error BelowMinimumAllocation(Tier tier, uint256 resultingBps, uint256 minBps);
    error AboveMaximumAllocation(Tier tier, uint256 resultingBps, uint256 maxBps);
    error InsufficientBalance(uint256 available, uint256 requested);
    error RedemptionInsufficientLiquidity(uint256 available, uint256 requested);

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    event Deposited(address indexed depositor, Tier indexed tier, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed recipient, Tier indexed tier, uint256 amount, uint256 newBalance);
    event Rebalanced(Tier indexed fromTier, Tier indexed toTier, uint256 amount, address indexed operator);
    event RedemptionProcessed(address indexed redeemer, uint256 tokensBurned, uint256 collateralOut);

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    IERC20 public immutable collateralToken;
    IERC20 public immutable backedToken;
    IBackingOracle public immutable oracle; // Reserved: will be used for on-chain collateral ratio computation
    mapping(Tier => TierConfig) public tiers;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    constructor(
        address collateralToken_,
        address backedToken_,
        address oracle_,
        address admin
    ) {
        if (collateralToken_ == address(0)) revert ZeroAddress();
        if (backedToken_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();

        collateralToken = IERC20(collateralToken_);
        backedToken = IERC20(backedToken_);
        oracle = IBackingOracle(oracle_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        tiers[Tier.T0_HOT] = TierConfig(500, 1_000, type(uint256).max, 0, 0, 0);
        tiers[Tier.T1_WARM] = TierConfig(1_500, 2_500, type(uint256).max, 1 hours, 0, 0);
        tiers[Tier.T2_COLD] = TierConfig(5_000, 6_000, type(uint256).max, 24 hours, 0, 0);
        tiers[Tier.T3_RWA] = TierConfig(1_000, 2_000, type(uint256).max, 72 hours, 0, 0);
    }

    // -------------------------------------------------------------------
    //  External — Deposits
    // -------------------------------------------------------------------

    function deposit(Tier tier, uint256 amount) external onlyRole(TREASURER_ROLE) whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 totalAfter = totalBalance() + amount;
        uint256 tierAfter = tiers[tier].balance + amount;
        uint256 resultingBps = (tierAfter * BPS_DENOMINATOR) / totalAfter;

        // slither-disable-next-line timestamp
        if (resultingBps > tiers[tier].maxAllocationBps) {
            revert AboveMaximumAllocation(tier, resultingBps, tiers[tier].maxAllocationBps);
        }

        tiers[tier].balance += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, tier, amount, tiers[tier].balance);
    }

    function depositAutoRoute(uint256 amount) external onlyRole(TREASURER_ROLE) whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        Tier bestTier = _tierWithLargestDeficit();
        tiers[bestTier].balance += amount;
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, bestTier, amount, tiers[bestTier].balance);
    }

    // -------------------------------------------------------------------
    //  External — Withdrawals
    // -------------------------------------------------------------------

    function withdraw(Tier tier, uint256 amount, address recipient) external onlyRole(TREASURER_ROLE) whenNotPaused nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        TierConfig storage tc = tiers[tier];

        if (amount > tc.withdrawalLimit) revert WithdrawalLimitExceeded(tier, amount, tc.withdrawalLimit);
        // slither-disable-next-line timestamp
        if (tc.cooldownPeriod > 0 && block.timestamp < tc.lastWithdrawal + tc.cooldownPeriod) {
            revert CooldownNotElapsed(tier, tc.lastWithdrawal + tc.cooldownPeriod);
        }
        if (amount > tc.balance) revert InsufficientBalance(tc.balance, amount);

        uint256 totalAfter = totalBalance() - amount;
        if (totalAfter > 0) {
            uint256 tierAfter = tc.balance - amount;
            uint256 resultingBps = (tierAfter * BPS_DENOMINATOR) / totalAfter;
            if (resultingBps < tc.minAllocationBps) {
                revert BelowMinimumAllocation(tier, resultingBps, tc.minAllocationBps);
            }
        }

        tc.balance -= amount;
        tc.lastWithdrawal = block.timestamp;
        collateralToken.safeTransfer(recipient, amount);

        emit Withdrawn(recipient, tier, amount, tc.balance);
    }

    // -------------------------------------------------------------------
    //  External — Rebalancing
    // -------------------------------------------------------------------

    function rebalance(Tier fromTier, Tier toTier, uint256 amount) external onlyRole(OPERATOR_ROLE) whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > tiers[fromTier].balance) revert InsufficientBalance(tiers[fromTier].balance, amount);

        uint256 total = totalBalance();
        uint256 sourceAfter = tiers[fromTier].balance - amount;
        uint256 sourceBps = total > 0 ? (sourceAfter * BPS_DENOMINATOR) / total : 0;
        // slither-disable-next-line timestamp
        if (sourceBps < tiers[fromTier].minAllocationBps) {
            revert BelowMinimumAllocation(fromTier, sourceBps, tiers[fromTier].minAllocationBps);
        }

        uint256 destAfter = tiers[toTier].balance + amount;
        uint256 destBps = total > 0 ? (destAfter * BPS_DENOMINATOR) / total : 0;
        // slither-disable-next-line timestamp
        if (destBps > tiers[toTier].maxAllocationBps) {
            revert AboveMaximumAllocation(toTier, destBps, tiers[toTier].maxAllocationBps);
        }

        tiers[fromTier].balance -= amount;
        tiers[toTier].balance += amount;

        emit Rebalanced(fromTier, toTier, amount, msg.sender);
    }

    // -------------------------------------------------------------------
    //  External — Redemption
    // -------------------------------------------------------------------

    /**
     * @notice Redeem backed tokens for underlying collateral.
     * @dev Caller MUST first approve this contract to spend their BackedTokens:
     *      `backedToken.approve(address(treasuryVault), tokenAmount)`
     * @param tokenAmount Number of backed tokens to redeem.
     * @param minCollateralOut Minimum collateral to receive (slippage protection). Use 0 to skip.
     */
    function redeem(uint256 tokenAmount, uint256 minCollateralOut) external whenNotPaused nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();

        uint256 totalSupply = backedToken.totalSupply();
        uint256 totalCollateral = totalBalance();
        uint256 collateralOut = (tokenAmount * totalCollateral) / totalSupply;

        // slither-disable-next-line timestamp
        if (collateralOut > totalCollateral) {
            revert RedemptionInsufficientLiquidity(totalCollateral, collateralOut);
        }

        // slither-disable-next-line timestamp
        require(collateralOut >= minCollateralOut, "TreasuryVault: slippage exceeded");

        emit RedemptionProcessed(msg.sender, tokenAmount, collateralOut);

        // NOTE: Caller MUST have approved this contract via backedToken.approve()
        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line low-level-calls,reentrancy-no-eth,reentrancy-events
        (bool success,) = address(backedToken).call(
            abi.encodeWithSignature("burnFrom(address,uint256)", msg.sender, tokenAmount)
        );
        require(success, "TreasuryVault: burn failed (ensure approve() was called)");

        uint256 remaining = collateralOut;
        remaining = _drawFromTier(Tier.T0_HOT, remaining);
        remaining = _drawFromTier(Tier.T1_WARM, remaining);
        remaining = _drawFromTier(Tier.T2_COLD, remaining);
        remaining = _drawFromTier(Tier.T3_RWA, remaining);
        // slither-disable-next-line incorrect-equality
        require(remaining == 0, "TreasuryVault: insufficient tier balances");

        collateralToken.safeTransfer(msg.sender, collateralOut);
    }

    // -------------------------------------------------------------------
    //  External — Configuration
    // -------------------------------------------------------------------

    function configureTier(Tier tier, uint256 minBps, uint256 maxBps, uint256 limit, uint256 cooldown) external onlyRole(ADMIN_ROLE) {
        require(minBps <= maxBps, "TreasuryVault: min > max");
        require(maxBps <= BPS_DENOMINATOR, "TreasuryVault: max > 100%");

        TierConfig storage tc = tiers[tier];
        tc.minAllocationBps = minBps;
        tc.maxAllocationBps = maxBps;
        tc.withdrawalLimit = limit;
        tc.cooldownPeriod = cooldown;
    }

    function pause() external onlyRole(ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(ADMIN_ROLE) { _unpause(); }

    // -------------------------------------------------------------------
    //  External — View Functions
    // -------------------------------------------------------------------

    function totalBalance() public view returns (uint256) {
        return tiers[Tier.T0_HOT].balance + tiers[Tier.T1_WARM].balance
             + tiers[Tier.T2_COLD].balance + tiers[Tier.T3_RWA].balance;
    }

    function collateralRatio() external view returns (uint256) {
        uint256 supply = backedToken.totalSupply();
        if (supply == 0) return type(uint256).max;
        return (totalBalance() * 1e18) / supply;
    }

    /**
     * @notice Health factor as a percentage (100 = fully backed, <100 = undercollateralized).
     * @return Health factor scaled to basis points (10000 = 100%).
     */
    function healthFactor() external view returns (uint256) {
        uint256 supply = backedToken.totalSupply();
        if (supply == 0) return type(uint256).max;
        return (totalBalance() * BPS_DENOMINATOR) / supply;
    }

    function tierAllocationBps(Tier tier) external view returns (uint256) {
        uint256 total = totalBalance();
        // slither-disable-next-line incorrect-equality,timestamp
        if (total == 0) return 0;
        return (tiers[tier].balance * BPS_DENOMINATOR) / total;
    }

    function tierBalance(Tier tier) external view returns (uint256) {
        return tiers[tier].balance;
    }

    // -------------------------------------------------------------------
    //  Internal
    // -------------------------------------------------------------------

    // NOTE: Redemptions may temporarily bring tier balances below minAllocationBps.
    // This is by design — redemptions take priority over allocation constraints.
    // Rebalancing should be done post-redemption to restore allocation targets.
    function _drawFromTier(Tier tier, uint256 amount) internal returns (uint256) {
        // slither-disable-next-line incorrect-equality,timestamp
        if (amount == 0) return 0;
        uint256 available = tiers[tier].balance;
        // slither-disable-next-line timestamp
        uint256 drawn = amount > available ? available : amount;
        tiers[tier].balance -= drawn;
        return amount - drawn;
    }

    function _tierWithLargestDeficit() internal view returns (Tier) {
        uint256 total = totalBalance();
        Tier bestTier = Tier.T0_HOT;
        int256 largestDeficit = type(int256).min;

        for (uint8 i = 0; i < 4; i++) {
            Tier t = Tier(i);
            TierConfig storage tc = tiers[t];
            // slither-disable-next-line divide-before-multiply,timestamp
            uint256 targetAmount = total > 0
                ? (total * (tc.minAllocationBps + tc.maxAllocationBps)) / (2 * BPS_DENOMINATOR)
                : 0;
            int256 deficit = int256(targetAmount) - int256(tc.balance);
            // slither-disable-next-line timestamp
            if (deficit > largestDeficit) {
                largestDeficit = deficit;
                bestTier = t;
            }
        }

        return bestTier;
    }
}
