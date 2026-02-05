// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITreasuryVault
 * @author SecureMintEngine
 * @notice Interface for the TreasuryVault contract — a reserve custody system
 *         implementing a 4-tier collateral management model with automated
 *         rebalancing, redemption processing, and oracle integration.
 * @dev Reserve tier structure:
 *
 *      | Tier | Name | Target Allocation | Purpose                      |
 *      |------|------|-------------------|------------------------------|
 *      | T0   | Hot  |  5 - 10%          | Instant redemptions          |
 *      | T1   | Warm | 15 - 25%          | Same-day redemptions         |
 *      | T2   | Cold | 50 - 60%          | Long-term secure storage     |
 *      | T3   | RWA  | 10 - 20%          | Real-world asset backing     |
 */
interface ITreasuryVault {
    // -------------------------------------------------------------------
    //  Enums
    // -------------------------------------------------------------------

    /**
     * @notice The four collateral tiers managed by the vault.
     */
    enum Tier {
        T0_HOT,
        T1_WARM,
        T2_COLD,
        T3_RWA
    }

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /**
     * @notice Emitted when collateral is deposited into a tier.
     * @param depositor  The address that deposited collateral.
     * @param tier       The tier that received the deposit.
     * @param amount     The amount deposited.
     * @param newBalance The tier balance after the deposit.
     */
    event Deposited(
        address indexed depositor,
        Tier indexed tier,
        uint256 amount,
        uint256 newBalance
    );

    /**
     * @notice Emitted when collateral is withdrawn from a tier.
     * @param recipient  The address that received the withdrawal.
     * @param tier       The tier from which collateral was withdrawn.
     * @param amount     The amount withdrawn.
     * @param newBalance The tier balance after the withdrawal.
     */
    event Withdrawn(
        address indexed recipient,
        Tier indexed tier,
        uint256 amount,
        uint256 newBalance
    );

    /**
     * @notice Emitted when collateral is moved between tiers.
     * @param fromTier The source tier.
     * @param toTier   The destination tier.
     * @param amount   The amount rebalanced.
     * @param operator The address that performed the rebalance.
     */
    event Rebalanced(
        Tier indexed fromTier,
        Tier indexed toTier,
        uint256 amount,
        address indexed operator
    );

    /**
     * @notice Emitted when a holder redeems backed tokens for collateral.
     * @param redeemer      The address that redeemed tokens.
     * @param tokensBurned  The number of backed tokens burned.
     * @param collateralOut The amount of collateral returned.
     */
    event RedemptionProcessed(
        address indexed redeemer,
        uint256 tokensBurned,
        uint256 collateralOut
    );

    // -------------------------------------------------------------------
    //  External — Deposits (TREASURER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Deposits `amount` collateral into the specified `tier`.
     * @dev Caller must have approved this contract to spend the collateral
     *      token. Reverts if the deposit would exceed the tier's maximum
     *      allocation.
     * @param tier   The target tier for the deposit.
     * @param amount The amount of collateral to deposit.
     */
    function deposit(Tier tier, uint256 amount) external;

    /**
     * @notice Deposits `amount` collateral, automatically routing it to the
     *         tier with the largest deficit relative to its target allocation.
     * @dev Caller must have approved this contract to spend the collateral token.
     * @param amount The amount of collateral to deposit.
     */
    function depositAutoRoute(uint256 amount) external;

    // -------------------------------------------------------------------
    //  External — Withdrawals (TREASURER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Withdraws `amount` collateral from `tier` to `recipient`.
     * @dev Enforces withdrawal limits, cooldown periods, and minimum
     *      allocation constraints.
     * @param tier      The tier to withdraw from.
     * @param amount    The amount of collateral to withdraw.
     * @param recipient The address to receive the collateral.
     */
    function withdraw(Tier tier, uint256 amount, address recipient) external;

    // -------------------------------------------------------------------
    //  External — Rebalancing (OPERATOR_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Moves `amount` collateral from `fromTier` to `toTier`.
     * @dev Enforces minimum/maximum allocation constraints for both tiers.
     * @param fromTier The source tier.
     * @param toTier   The destination tier.
     * @param amount   The amount to move.
     */
    function rebalance(Tier fromTier, Tier toTier, uint256 amount) external;

    // -------------------------------------------------------------------
    //  External — Redemption
    // -------------------------------------------------------------------

    /**
     * @notice Redeems backed tokens for underlying collateral.
     * @dev Caller MUST first approve this contract to spend their BackedTokens.
     *      Collateral is drawn from tiers in order: T0 -> T1 -> T2 -> T3.
     * @param tokenAmount      Number of backed tokens to redeem.
     * @param minCollateralOut  Minimum collateral to receive (slippage protection).
     *                          Use 0 to skip the slippage check.
     */
    function redeem(uint256 tokenAmount, uint256 minCollateralOut) external;

    // -------------------------------------------------------------------
    //  External — Configuration (ADMIN_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Configures the allocation and withdrawal parameters for a tier.
     * @param tier     The tier to configure.
     * @param minBps   Minimum allocation in basis points.
     * @param maxBps   Maximum allocation in basis points.
     * @param limit    Maximum single-withdrawal amount.
     * @param cooldown Cooldown period between withdrawals (seconds).
     */
    function configureTier(
        Tier tier,
        uint256 minBps,
        uint256 maxBps,
        uint256 limit,
        uint256 cooldown
    ) external;

    // -------------------------------------------------------------------
    //  View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the total collateral balance across all tiers.
     * @return The aggregate balance in base units.
     */
    function totalBalance() external view returns (uint256);

    /**
     * @notice Returns the collateral ratio scaled by 1e18.
     * @dev Returns type(uint256).max if total supply is 0.
     * @return The ratio of total collateral to total token supply.
     */
    function collateralRatio() external view returns (uint256);

    /**
     * @notice Returns the health factor as basis points (10000 = 100% backed).
     * @dev Returns type(uint256).max if total supply is 0.
     * @return The health factor in basis points.
     */
    function healthFactor() external view returns (uint256);

    /**
     * @notice Returns the current allocation of `tier` in basis points.
     * @param tier The tier to query.
     * @return The tier's share of total collateral in basis points.
     */
    function tierAllocationBps(Tier tier) external view returns (uint256);

    /**
     * @notice Returns the current collateral balance of `tier`.
     * @param tier The tier to query.
     * @return The tier balance in base units.
     */
    function tierBalance(Tier tier) external view returns (uint256);
}
