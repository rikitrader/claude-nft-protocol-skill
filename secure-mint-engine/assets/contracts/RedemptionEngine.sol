// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RedemptionEngine
 * @author SecureMintEngine
 * @notice Dedicated burn-to-redeem mechanism that coordinates between
 *         BackedToken and TreasuryVault. Separates redemption logic from
 *         the vault for cleaner separation of concerns.
 *
 * @dev Redemption flow:
 *
 *      1. User approves this contract to spend their BackedTokens.
 *      2. User calls `redeem(tokenAmount, minCollateralOut)`.
 *      3. Engine validates amount bounds, cooldown, and slippage.
 *      4. Engine burns the user's BackedTokens via `burnFrom`.
 *      5. Engine transfers collateral from TreasuryVault to the user.
 *      6. Fee (if any) is routed to the configured fee recipient.
 *
 *      Fees are expressed in basis points (bps) and capped at 500 (5%).
 */
contract RedemptionEngine is AccessControl, Pausable, ReentrancyGuard {

    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Admins can configure fees, limits, cooldowns, and pause state.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------------------------------------------------------------------
    //  Constants
    // -------------------------------------------------------------------

    /// @notice Basis-point denominator (10 000 = 100%).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Maximum allowed redemption fee in basis points (500 = 5%).
    uint256 public constant MAX_FEE_BPS = 500;

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @notice Redemption amount is below the configured minimum.
    error BelowMinRedemption(uint256 amount, uint256 minRedemption);

    /// @notice Redemption amount exceeds the configured maximum.
    error AboveMaxRedemption(uint256 amount, uint256 maxRedemption);

    /// @notice The caller's cooldown period has not yet elapsed.
    error CooldownActive(address user, uint256 cooldownEndsAt);

    /// @notice The proposed fee exceeds the hard cap of 500 bps (5%).
    error FeeTooHigh(uint256 proposedFee, uint256 maxFee);

    /// @notice Collateral received after fees is below the caller's minimum.
    error SlippageExceeded(uint256 collateralOut, uint256 minCollateralOut);

    /// @notice A zero address was supplied where it is not allowed.
    error ZeroAddress();

    /// @notice A zero amount was supplied where it is not allowed.
    error ZeroAmount();

    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /// @notice Emitted when a redemption is successfully processed.
    event RedemptionProcessed(
        address indexed redeemer,
        uint256 tokensBurned,
        uint256 collateralOut,
        uint256 feeAmount
    );

    /// @notice Emitted when the redemption fee is updated.
    event FeeUpdated(uint256 previousFee, uint256 newFee);

    /// @notice Emitted when the per-user cooldown period is updated.
    event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);

    /// @notice Emitted when the minimum redemption amount is updated.
    event MinRedemptionUpdated(uint256 previousMin, uint256 newMin);

    /// @notice Emitted when the maximum redemption amount is updated.
    event MaxRedemptionUpdated(uint256 previousMax, uint256 newMax);

    /// @notice Emitted when the fee recipient is updated.
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    // -------------------------------------------------------------------
    //  State Variables
    // -------------------------------------------------------------------

    /// @notice The BackedToken that users burn to redeem collateral.
    IERC20 public immutable backedToken;

    /// @notice The TreasuryVault that holds the collateral reserves.
    address public immutable treasuryVault;

    /// @notice The collateral ERC-20 token held by the TreasuryVault.
    IERC20 public immutable collateralToken;

    /// @notice Redemption fee in basis points (default 0).
    uint256 public redemptionFee;

    /// @notice Address that receives collected redemption fees.
    address public feeRecipient;

    /// @notice Minimum number of BackedTokens required per redemption.
    uint256 public minRedemption;

    /// @notice Maximum number of BackedTokens allowed per redemption.
    uint256 public maxRedemption;

    /// @notice Cooldown period in seconds between redemptions per user.
    uint256 public cooldownPeriod;

    /// @notice Tracks the timestamp of each user's last redemption.
    mapping(address => uint256) public lastRedemption;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @notice Deploys the RedemptionEngine.
     * @param backedToken_     The BackedToken contract (ERC-20 + burnFrom).
     * @param treasuryVault_   The TreasuryVault that custodies collateral.
     * @param collateralToken_ The collateral ERC-20 token.
     * @param feeRecipient_    Initial fee recipient address.
     * @param admin            Initial admin address.
     */
    constructor(
        address backedToken_,
        address treasuryVault_,
        address collateralToken_,
        address feeRecipient_,
        address admin
    ) {
        if (backedToken_ == address(0)) revert ZeroAddress();
        if (treasuryVault_ == address(0)) revert ZeroAddress();
        if (collateralToken_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();

        backedToken = IERC20(backedToken_);
        treasuryVault = treasuryVault_;
        collateralToken = IERC20(collateralToken_);
        feeRecipient = feeRecipient_;

        // Sensible defaults: no minimum, unlimited maximum, no fee, no cooldown
        minRedemption = 0;
        maxRedemption = type(uint256).max;
        redemptionFee = 0;
        cooldownPeriod = 0;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    // -------------------------------------------------------------------
    //  External — Redemption
    // -------------------------------------------------------------------

    /// @notice User-facing redemption with fee, cooldown, slippage protection, and min/max bounds.
    /// @dev This is the user-facing redemption path. TreasuryVault.redeem() is the operator-only direct path.
    ///
    ///      Caller MUST first approve this contract to spend their BackedTokens:
    ///      `backedToken.approve(address(redemptionEngine), tokenAmount)`
    ///
    ///      Collateral calculation:
    ///        collateral = tokenAmount * collateralRatio / 1e18
    ///        netCollateral = collateral * (BPS - fee) / BPS
    ///
    /// @param tokenAmount      Number of BackedTokens to burn.
    /// @param minCollateralOut  Minimum collateral the caller expects to receive
    ///                          (slippage protection). Use 0 to skip.
    function redeem(
        uint256 tokenAmount,
        uint256 minCollateralOut
    ) external whenNotPaused nonReentrant {
        if (tokenAmount == 0) revert ZeroAmount();
        if (tokenAmount < minRedemption) revert BelowMinRedemption(tokenAmount, minRedemption);
        if (tokenAmount > maxRedemption) revert AboveMaxRedemption(tokenAmount, maxRedemption);

        // Enforce per-user cooldown
        uint256 cooldownEndsAt = lastRedemption[msg.sender] + cooldownPeriod;
        // slither-disable-next-line timestamp
        if (block.timestamp < cooldownEndsAt) {
            revert CooldownActive(msg.sender, cooldownEndsAt);
        }

        // Query current collateral ratio from TreasuryVault
        // collateralRatio returns (totalCollateral * 1e18) / totalSupply
        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory data) = treasuryVault.staticcall(
            abi.encodeWithSignature("collateralRatio()")
        );
        require(success, "RedemptionEngine: collateralRatio query failed");
        uint256 ratio = abi.decode(data, (uint256));

        // Calculate gross collateral owed
        uint256 grossCollateral = (tokenAmount * ratio) / 1e18;

        // Calculate fee from original values to avoid divide-before-multiply precision loss.
        // Overflow-safe: tokenAmount <= ~1e30, ratio <= ~1e18, redemptionFee <= 10000
        // => product <= ~1e52, well within uint256 max (~1.15e77).
        uint256 feeAmount = (tokenAmount * ratio * redemptionFee) / (1e18 * BPS_DENOMINATOR);
        uint256 netCollateral = grossCollateral - feeAmount;

        // Slippage check
        if (netCollateral < minCollateralOut) {
            revert SlippageExceeded(netCollateral, minCollateralOut);
        }

        // Record cooldown timestamp
        lastRedemption[msg.sender] = block.timestamp;

        // Burn backed tokens from the caller (requires prior approval)
        // solhint-disable-next-line avoid-low-level-calls
        // slither-disable-next-line low-level-calls
        (bool burnSuccess,) = address(backedToken).call(
            abi.encodeWithSignature("burnFrom(address,uint256)", msg.sender, tokenAmount)
        );
        require(burnSuccess, "RedemptionEngine: burn failed (ensure approve() was called)");

        // Call TreasuryVault.withdraw to transfer collateral to redeemer
        // slither-disable-next-line low-level-calls
        (bool wSuccess,) = address(treasuryVault).call(
            abi.encodeWithSignature("withdraw(uint8,uint256,address)", uint8(0), netCollateral, msg.sender)
        );
        require(wSuccess, "RedemptionEngine: vault withdrawal failed");

        // Transfer fee to fee recipient (if any)
        if (feeAmount > 0) {
            // slither-disable-next-line low-level-calls
            (bool fSuccess,) = address(treasuryVault).call(
                abi.encodeWithSignature("withdraw(uint8,uint256,address)", uint8(0), feeAmount, feeRecipient)
            );
            require(fSuccess, "RedemptionEngine: fee withdrawal failed");
        }

        // slither-disable-next-line reentrancy-events
        emit RedemptionProcessed(msg.sender, tokenAmount, netCollateral, feeAmount);
    }

    // -------------------------------------------------------------------
    //  External — Configuration (ADMIN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Sets the redemption fee in basis points.
     * @dev Hard-capped at 500 bps (5%) to protect users.
     * @param newFee The new fee in basis points.
     */
    function setRedemptionFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        if (newFee > MAX_FEE_BPS) revert FeeTooHigh(newFee, MAX_FEE_BPS);

        uint256 previousFee = redemptionFee;
        redemptionFee = newFee;

        emit FeeUpdated(previousFee, newFee);
    }

    /**
     * @notice Sets the minimum number of BackedTokens required per redemption.
     * @param newMin The new minimum redemption amount.
     */
    function setMinRedemption(uint256 newMin) external onlyRole(ADMIN_ROLE) {
        uint256 previousMin = minRedemption;
        minRedemption = newMin;

        emit MinRedemptionUpdated(previousMin, newMin);
    }

    /**
     * @notice Sets the maximum number of BackedTokens allowed per redemption.
     * @param newMax The new maximum redemption amount.
     */
    function setMaxRedemption(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        uint256 previousMax = maxRedemption;
        maxRedemption = newMax;

        emit MaxRedemptionUpdated(previousMax, newMax);
    }

    /**
     * @notice Sets the fee recipient address.
     * @param newRecipient The new fee recipient.
     */
    function setFeeRecipient(address newRecipient) external onlyRole(ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();

        address previousRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(previousRecipient, newRecipient);
    }

    /**
     * @notice Sets the per-user cooldown period between redemptions.
     * @param newCooldown The new cooldown period in seconds.
     */
    function setCooldown(uint256 newCooldown) external onlyRole(ADMIN_ROLE) {
        uint256 previousCooldown = cooldownPeriod;
        cooldownPeriod = newCooldown;

        emit CooldownUpdated(previousCooldown, newCooldown);
    }

    // -------------------------------------------------------------------
    //  External — Pause Management (ADMIN_ROLE)
    // -------------------------------------------------------------------

    /**
     * @notice Pauses all redemptions.
     * @dev Callable only by ADMIN_ROLE.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses redemptions.
     * @dev Callable only by ADMIN_ROLE.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
