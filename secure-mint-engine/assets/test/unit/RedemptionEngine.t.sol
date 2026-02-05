// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/RedemptionEngine.sol";
import "../mocks/MockERC20.sol";

// ---------------------------------------------------------------------------
//  MockBackedToken — ERC20 with public mint and burnFrom support
// ---------------------------------------------------------------------------

/**
 * @notice Simulates a BackedToken that supports burnFrom via approval.
 */
contract MockBackedToken is MockERC20 {
    constructor() MockERC20("Backed USD", "bUSD", 18) {}

    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }
}

// ---------------------------------------------------------------------------
//  MockTreasuryVault — exposes collateralRatio() and holds collateral
// ---------------------------------------------------------------------------

/**
 * @notice Simulates a TreasuryVault that reports a collateral ratio and
 *         holds collateral tokens. The RedemptionEngine transfers collateral
 *         from this vault using safeTransferFrom (requires approval).
 */
contract MockTreasuryVault {
    uint256 private _ratio;

    constructor(uint256 ratio) {
        _ratio = ratio;
    }

    function collateralRatio() external view returns (uint256) {
        return _ratio;
    }

    function setCollateralRatio(uint256 newRatio) external {
        _ratio = newRatio;
    }
}

// ---------------------------------------------------------------------------
//  Test Suite
// ---------------------------------------------------------------------------

/**
 * @title RedemptionEngineTest
 * @notice Unit tests for the RedemptionEngine contract.
 */
contract RedemptionEngineTest is Test {
    // -------------------------------------------------------------------
    //  Events (declared locally for Solidity 0.8.20 compat)
    // -------------------------------------------------------------------

    event RedemptionProcessed(
        address indexed redeemer,
        uint256 tokensBurned,
        uint256 collateralOut,
        uint256 feeAmount
    );
    event FeeUpdated(uint256 previousFee, uint256 newFee);
    event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);
    event MinRedemptionUpdated(uint256 previousMin, uint256 newMin);
    event MaxRedemptionUpdated(uint256 previousMax, uint256 newMax);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    RedemptionEngine public engine;
    MockBackedToken public backedToken;
    MockERC20 public collateral;
    MockTreasuryVault public vault;

    address public admin = makeAddr("admin");
    address public nonAdmin = makeAddr("nonAdmin");
    address public user = makeAddr("user");
    address public feeRecipient = makeAddr("feeRecipient");

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // 1:1 collateral ratio (1e18 = 100%)
    uint256 public constant ONE_TO_ONE_RATIO = 1e18;

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        vm.warp(1_700_000_000);

        backedToken = new MockBackedToken();
        collateral = new MockERC20("USD Coin", "USDC", 18);
        vault = new MockTreasuryVault(ONE_TO_ONE_RATIO);

        engine = new RedemptionEngine(
            address(backedToken),
            address(vault),
            address(collateral),
            feeRecipient,
            admin
        );

        // Fund vault with collateral and approve the engine to transfer
        collateral.mint(address(vault), 10_000_000e18);
        vm.prank(address(vault));
        collateral.approve(address(engine), type(uint256).max);

        // Give user some backed tokens
        backedToken.mint(user, 10_000e18);
    }

    // ===================================================================
    //  Constructor Tests
    // ===================================================================

    function test_Constructor_SetsImmutables() public view {
        assertEq(address(engine.backedToken()), address(backedToken));
        assertEq(engine.treasuryVault(), address(vault));
        assertEq(address(engine.collateralToken()), address(collateral));
        assertEq(engine.feeRecipient(), feeRecipient);
    }

    function test_Constructor_SetsDefaults() public view {
        assertEq(engine.minRedemption(), 0);
        assertEq(engine.maxRedemption(), type(uint256).max);
        assertEq(engine.redemptionFee(), 0);
        assertEq(engine.cooldownPeriod(), 0);
    }

    function test_Constructor_GrantsRoles() public view {
        assertTrue(engine.hasRole(engine.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(engine.hasRole(ADMIN_ROLE, admin));
    }

    function test_Constructor_RevertsOnZeroBackedToken() public {
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        new RedemptionEngine(
            address(0), address(vault), address(collateral), feeRecipient, admin
        );
    }

    function test_Constructor_RevertsOnZeroVault() public {
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        new RedemptionEngine(
            address(backedToken), address(0), address(collateral), feeRecipient, admin
        );
    }

    function test_Constructor_RevertsOnZeroCollateral() public {
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        new RedemptionEngine(
            address(backedToken), address(vault), address(0), feeRecipient, admin
        );
    }

    function test_Constructor_RevertsOnZeroFeeRecipient() public {
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        new RedemptionEngine(
            address(backedToken), address(vault), address(collateral), address(0), admin
        );
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        new RedemptionEngine(
            address(backedToken), address(vault), address(collateral), feeRecipient, address(0)
        );
    }

    // ===================================================================
    //  redeem — Happy Path
    // ===================================================================

    function test_Redeem_HappyPath_NoFee() public {
        uint256 redeemAmount = 1000e18;

        // User approves the engine to burn their backed tokens
        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);

        engine.redeem(redeemAmount, 0);
        vm.stopPrank();

        // User's backed tokens burned
        assertEq(backedToken.balanceOf(user), 10_000e18 - redeemAmount);
        // User received collateral (1:1 ratio, no fee)
        assertEq(collateral.balanceOf(user), redeemAmount);
    }

    function test_Redeem_HappyPath_WithFee() public {
        // Set 2% fee (200 bps)
        vm.prank(admin);
        engine.setRedemptionFee(200);

        uint256 redeemAmount = 1000e18;
        // gross = 1000e18 * 1e18 / 1e18 = 1000e18
        // fee = 1000e18 * 200 / 10000 = 20e18
        // net = 1000e18 - 20e18 = 980e18
        uint256 expectedNet = 980e18;
        uint256 expectedFee = 20e18;

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);
        engine.redeem(redeemAmount, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), expectedNet);
        assertEq(collateral.balanceOf(feeRecipient), expectedFee);
    }

    function test_Redeem_EmitsRedemptionProcessed() public {
        uint256 redeemAmount = 500e18;

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);

        vm.expectEmit(true, false, false, true);
        emit RedemptionProcessed(user, redeemAmount, redeemAmount, 0);

        engine.redeem(redeemAmount, 0);
        vm.stopPrank();
    }

    // ===================================================================
    //  redeem — Cooldown Enforcement
    // ===================================================================

    function test_Redeem_CooldownEnforced() public {
        // Set 1-hour cooldown
        vm.prank(admin);
        engine.setCooldown(3600);

        uint256 redeemAmount = 100e18;

        // First redemption succeeds
        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount * 2);
        engine.redeem(redeemAmount, 0);

        // Second redemption immediately fails
        uint256 cooldownEndsAt = block.timestamp + 3600;
        vm.expectRevert(
            abi.encodeWithSelector(
                RedemptionEngine.CooldownActive.selector,
                user,
                cooldownEndsAt
            )
        );
        engine.redeem(redeemAmount, 0);
        vm.stopPrank();
    }

    function test_Redeem_CooldownExpiresAllowsNewRedemption() public {
        vm.prank(admin);
        engine.setCooldown(3600);

        uint256 redeemAmount = 100e18;

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount * 2);

        // First redemption
        engine.redeem(redeemAmount, 0);

        // Warp past cooldown
        vm.warp(block.timestamp + 3601);

        // Second redemption succeeds
        engine.redeem(redeemAmount, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), redeemAmount * 2);
    }

    // ===================================================================
    //  redeem — Min/Max Bounds
    // ===================================================================

    function test_Redeem_RevertsBelowMinRedemption() public {
        vm.prank(admin);
        engine.setMinRedemption(100e18);

        vm.startPrank(user);
        backedToken.approve(address(engine), 50e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                RedemptionEngine.BelowMinRedemption.selector,
                50e18,
                100e18
            )
        );
        engine.redeem(50e18, 0);
        vm.stopPrank();
    }

    function test_Redeem_RevertsAboveMaxRedemption() public {
        vm.prank(admin);
        engine.setMaxRedemption(500e18);

        vm.startPrank(user);
        backedToken.approve(address(engine), 600e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                RedemptionEngine.AboveMaxRedemption.selector,
                600e18,
                500e18
            )
        );
        engine.redeem(600e18, 0);
        vm.stopPrank();
    }

    function test_Redeem_SucceedsAtExactMinBoundary() public {
        vm.prank(admin);
        engine.setMinRedemption(100e18);

        vm.startPrank(user);
        backedToken.approve(address(engine), 100e18);
        engine.redeem(100e18, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 100e18);
    }

    function test_Redeem_SucceedsAtExactMaxBoundary() public {
        vm.prank(admin);
        engine.setMaxRedemption(500e18);

        vm.startPrank(user);
        backedToken.approve(address(engine), 500e18);
        engine.redeem(500e18, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 500e18);
    }

    // ===================================================================
    //  redeem — Slippage Protection
    // ===================================================================

    function test_Redeem_RevertsOnSlippageExceeded() public {
        // Set a 5% fee
        vm.prank(admin);
        engine.setRedemptionFee(500);

        uint256 redeemAmount = 1000e18;
        // net = 1000e18 - 50e18 = 950e18
        // User expects at least 960e18 — should revert
        uint256 minOut = 960e18;

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                RedemptionEngine.SlippageExceeded.selector,
                950e18,
                minOut
            )
        );
        engine.redeem(redeemAmount, minOut);
        vm.stopPrank();
    }

    function test_Redeem_SlippagePassesWhenNetMeetsMin() public {
        vm.prank(admin);
        engine.setRedemptionFee(500);

        uint256 redeemAmount = 1000e18;
        uint256 minOut = 950e18; // exactly what they get

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);
        engine.redeem(redeemAmount, minOut);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 950e18);
    }

    // ===================================================================
    //  redeem — Error Paths
    // ===================================================================

    function test_Redeem_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(RedemptionEngine.ZeroAmount.selector);
        engine.redeem(0, 0);
    }

    function test_Redeem_RevertsWhenPaused() public {
        vm.prank(admin);
        engine.pause();

        vm.startPrank(user);
        backedToken.approve(address(engine), 100e18);
        vm.expectRevert();
        engine.redeem(100e18, 0);
        vm.stopPrank();
    }

    // ===================================================================
    //  setRedemptionFee Tests
    // ===================================================================

    function test_SetRedemptionFee_Success() public {
        vm.prank(admin);
        engine.setRedemptionFee(300);

        assertEq(engine.redemptionFee(), 300);
    }

    function test_SetRedemptionFee_EmitsFeeUpdated() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit FeeUpdated(0, 300);

        engine.setRedemptionFee(300);
    }

    function test_SetRedemptionFee_RevertsAboveMaxFee() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                RedemptionEngine.FeeTooHigh.selector,
                501,
                500
            )
        );
        engine.setRedemptionFee(501);
    }

    function test_SetRedemptionFee_SucceedsAtMaxFee() public {
        vm.prank(admin);
        engine.setRedemptionFee(500);
        assertEq(engine.redemptionFee(), 500);
    }

    function test_SetRedemptionFee_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.setRedemptionFee(100);
    }

    // ===================================================================
    //  setMinRedemption Tests
    // ===================================================================

    function test_SetMinRedemption_Success() public {
        vm.prank(admin);
        engine.setMinRedemption(50e18);

        assertEq(engine.minRedemption(), 50e18);
    }

    function test_SetMinRedemption_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit MinRedemptionUpdated(0, 50e18);

        engine.setMinRedemption(50e18);
    }

    function test_SetMinRedemption_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.setMinRedemption(50e18);
    }

    // ===================================================================
    //  setMaxRedemption Tests
    // ===================================================================

    function test_SetMaxRedemption_Success() public {
        vm.prank(admin);
        engine.setMaxRedemption(5000e18);

        assertEq(engine.maxRedemption(), 5000e18);
    }

    function test_SetMaxRedemption_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit MaxRedemptionUpdated(type(uint256).max, 5000e18);

        engine.setMaxRedemption(5000e18);
    }

    function test_SetMaxRedemption_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.setMaxRedemption(5000e18);
    }

    // ===================================================================
    //  setFeeRecipient Tests
    // ===================================================================

    function test_SetFeeRecipient_Success() public {
        address newRecipient = makeAddr("newFeeRecipient");

        vm.prank(admin);
        engine.setFeeRecipient(newRecipient);

        assertEq(engine.feeRecipient(), newRecipient);
    }

    function test_SetFeeRecipient_EmitsEvent() public {
        address newRecipient = makeAddr("newFeeRecipient");

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit FeeRecipientUpdated(feeRecipient, newRecipient);

        engine.setFeeRecipient(newRecipient);
    }

    function test_SetFeeRecipient_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(RedemptionEngine.ZeroAddress.selector);
        engine.setFeeRecipient(address(0));
    }

    function test_SetFeeRecipient_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.setFeeRecipient(makeAddr("newFeeRecipient"));
    }

    // ===================================================================
    //  setCooldown Tests
    // ===================================================================

    function test_SetCooldown_Success() public {
        vm.prank(admin);
        engine.setCooldown(7200);

        assertEq(engine.cooldownPeriod(), 7200);
    }

    function test_SetCooldown_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit CooldownUpdated(0, 7200);

        engine.setCooldown(7200);
    }

    function test_SetCooldown_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.setCooldown(7200);
    }

    // ===================================================================
    //  pause / unpause Tests
    // ===================================================================

    function test_Pause_AdminCanPause() public {
        vm.prank(admin);
        engine.pause();

        assertTrue(engine.paused());
    }

    function test_Unpause_AdminCanUnpause() public {
        vm.startPrank(admin);
        engine.pause();
        engine.unpause();
        vm.stopPrank();

        assertFalse(engine.paused());
    }

    function test_Pause_RevertsWithoutAdminRole() public {
        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.pause();
    }

    function test_Unpause_RevertsWithoutAdminRole() public {
        vm.prank(admin);
        engine.pause();

        vm.prank(nonAdmin);
        vm.expectRevert();
        engine.unpause();
    }

    function test_Pause_BlocksRedemptions() public {
        vm.prank(admin);
        engine.pause();

        vm.startPrank(user);
        backedToken.approve(address(engine), 100e18);
        vm.expectRevert();
        engine.redeem(100e18, 0);
        vm.stopPrank();
    }

    function test_Unpause_AllowsRedemptionsAgain() public {
        vm.startPrank(admin);
        engine.pause();
        engine.unpause();
        vm.stopPrank();

        vm.startPrank(user);
        backedToken.approve(address(engine), 100e18);
        engine.redeem(100e18, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 100e18);
    }

    // ===================================================================
    //  Constants Tests
    // ===================================================================

    function test_BpsDenominator() public view {
        assertEq(engine.BPS_DENOMINATOR(), 10_000);
    }

    function test_MaxFeeBps() public view {
        assertEq(engine.MAX_FEE_BPS(), 500);
    }

    // ===================================================================
    //  Collateral Ratio Variation
    // ===================================================================

    function test_Redeem_WithNonOneToOneRatio() public {
        // Set ratio to 0.5e18 — each backed token redeems 0.5 collateral
        vault.setCollateralRatio(0.5e18);

        uint256 redeemAmount = 1000e18;
        uint256 expectedCollateral = (redeemAmount * 0.5e18) / 1e18; // = 500e18

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);
        engine.redeem(redeemAmount, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), expectedCollateral);
    }

    function test_Redeem_WithFeeAndNonOneToOneRatio() public {
        vault.setCollateralRatio(2e18); // 2:1 ratio
        vm.prank(admin);
        engine.setRedemptionFee(100); // 1% fee

        uint256 redeemAmount = 100e18;
        // gross = 100e18 * 2e18 / 1e18 = 200e18
        // fee = 200e18 * 100 / 10000 = 2e18
        // net = 200e18 - 2e18 = 198e18

        vm.startPrank(user);
        backedToken.approve(address(engine), redeemAmount);
        engine.redeem(redeemAmount, 0);
        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 198e18);
        assertEq(collateral.balanceOf(feeRecipient), 2e18);
    }

    // ===================================================================
    //  lastRedemption Tracking
    // ===================================================================

    function test_Redeem_UpdatesLastRedemption() public {
        vm.startPrank(user);
        backedToken.approve(address(engine), 100e18);
        engine.redeem(100e18, 0);
        vm.stopPrank();

        assertEq(engine.lastRedemption(user), block.timestamp);
    }
}
