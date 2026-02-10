// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BackedToken.sol";
import "../mocks/MockBackingOracle.sol";

/**
 * @title BackedToken Unit Tests
 * @notice Comprehensive tests for the BackedToken ERC-20 dumb ledger contract
 * @dev Tests constructor validation, mint authorization, burn, pause/unpause,
 *      guardian management, and transfer restrictions when paused.
 */
contract BackedTokenTest is Test {
    BackedToken public token;
    MockBackingOracle public oracle;

    address public secureMintPolicy = address(0xBEEF);
    address public guardian = address(1);
    address public user = address(2);
    address public recipient = address(3);
    address public attacker = address(4);

    string public constant TOKEN_NAME = "BackedUSD";
    string public constant TOKEN_SYMBOL = "bUSD";

    uint256 public constant MINT_AMOUNT = 1_000_000 * 1e18;

    // Events (must redeclare for vm.expectEmit)
    event SecureMint(address indexed to, uint256 amount, uint256 newTotalSupply);
    event GuardianChanged(address indexed previousGuardian, address indexed newGuardian);

    function setUp() public {
        oracle = new MockBackingOracle();
        oracle.setVerifiedBacking(100_000_000 * 1e6);

        token = new BackedToken(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            secureMintPolicy,
            guardian
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_constructor_setsNameAndSymbol() public view {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_constructor_setsSecureMintPolicyImmutably() public view {
        assertEq(token.secureMintPolicy(), secureMintPolicy);
    }

    function test_constructor_setsGuardian() public view {
        assertEq(token.guardian(), guardian);
    }

    function test_constructor_initialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_constructor_revertsOnZeroSecureMintPolicy() public {
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        new BackedToken(TOKEN_NAME, TOKEN_SYMBOL, address(0), guardian);
    }

    function test_constructor_revertsOnZeroGuardian() public {
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        new BackedToken(TOKEN_NAME, TOKEN_SYMBOL, secureMintPolicy, address(0));
    }

    function test_constructor_revertsOnBothZeroAddresses() public {
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        new BackedToken(TOKEN_NAME, TOKEN_SYMBOL, address(0), address(0));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MINT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_mint_bySecureMintPolicy() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        assertEq(token.balanceOf(user), MINT_AMOUNT);
        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    function test_mint_emitsSecureMintEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SecureMint(user, MINT_AMOUNT, MINT_AMOUNT);

        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);
    }

    function test_mint_multipleMints_accumulateBalances() public {
        vm.startPrank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);
        token.mint(user, MINT_AMOUNT);
        token.mint(recipient, MINT_AMOUNT);
        vm.stopPrank();

        assertEq(token.balanceOf(user), MINT_AMOUNT * 2);
        assertEq(token.balanceOf(recipient), MINT_AMOUNT);
        assertEq(token.totalSupply(), MINT_AMOUNT * 3);
    }

    function test_mint_revertsWhenCalledByGuardian() public {
        vm.prank(guardian);
        vm.expectRevert(BackedToken.OnlySecureMint.selector);
        token.mint(user, MINT_AMOUNT);
    }

    function test_mint_revertsWhenCalledByArbitraryAddress() public {
        vm.prank(attacker);
        vm.expectRevert(BackedToken.OnlySecureMint.selector);
        token.mint(user, MINT_AMOUNT);
    }

    function test_mint_revertsWhenCalledByTokenHolder() public {
        // Give user some tokens first
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        // User cannot mint more
        vm.prank(user);
        vm.expectRevert(BackedToken.OnlySecureMint.selector);
        token.mint(user, MINT_AMOUNT);
    }

    function test_mint_revertsWhenPaused() public {
        vm.prank(guardian);
        token.pause();

        vm.prank(secureMintPolicy);
        vm.expectRevert("Pausable: paused");
        token.mint(user, MINT_AMOUNT);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BURN TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_burn_byTokenHolder() public {
        // Mint tokens to user
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        // User burns their tokens
        vm.prank(user);
        token.burn(MINT_AMOUNT / 2);

        assertEq(token.balanceOf(user), MINT_AMOUNT / 2);
        assertEq(token.totalSupply(), MINT_AMOUNT / 2);
    }

    function test_burn_entireBalance() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(user);
        token.burn(MINT_AMOUNT);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_burn_revertsOnInsufficientBalance() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(user);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burn(MINT_AMOUNT + 1);
    }

    function test_burnFrom_withApproval() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        // User approves recipient to burn
        vm.prank(user);
        token.approve(recipient, MINT_AMOUNT / 2);

        // Recipient burns from user
        vm.prank(recipient);
        token.burnFrom(user, MINT_AMOUNT / 2);

        assertEq(token.balanceOf(user), MINT_AMOUNT / 2);
    }

    function test_burnFrom_revertsWithoutApproval() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(recipient);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(user, MINT_AMOUNT / 2);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PAUSE / UNPAUSE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_pause_byGuardian() public {
        vm.prank(guardian);
        token.pause();

        assertTrue(token.paused());
    }

    function test_unpause_byGuardian() public {
        vm.prank(guardian);
        token.pause();

        vm.prank(guardian);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_pause_revertsWhenCalledByNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.pause();
    }

    function test_unpause_revertsWhenCalledByNonGuardian() public {
        vm.prank(guardian);
        token.pause();

        vm.prank(attacker);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.unpause();
    }

    function test_pause_revertsWhenCalledBySecureMintPolicy() public {
        vm.prank(secureMintPolicy);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.pause();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER TESTS (PAUSED)
    // ═══════════════════════════════════════════════════════════════════════════

    function test_transfer_succeeds_whenNotPaused() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(user);
        token.transfer(recipient, MINT_AMOUNT / 2);

        assertEq(token.balanceOf(user), MINT_AMOUNT / 2);
        assertEq(token.balanceOf(recipient), MINT_AMOUNT / 2);
    }

    function test_transfer_blockedWhenPaused() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(guardian);
        token.pause();

        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        token.transfer(recipient, MINT_AMOUNT / 2);
    }

    function test_transferFrom_blockedWhenPaused() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(user);
        token.approve(recipient, MINT_AMOUNT);

        vm.prank(guardian);
        token.pause();

        vm.prank(recipient);
        vm.expectRevert("Pausable: paused");
        token.transferFrom(user, recipient, MINT_AMOUNT / 2);
    }

    function test_transfer_resumesAfterUnpause() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        // Pause
        vm.prank(guardian);
        token.pause();

        // Unpause
        vm.prank(guardian);
        token.unpause();

        // Transfer should work again
        vm.prank(user);
        token.transfer(recipient, MINT_AMOUNT / 2);

        assertEq(token.balanceOf(recipient), MINT_AMOUNT / 2);
    }

    function test_burn_blockedWhenPaused() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(guardian);
        token.pause();

        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        token.burn(MINT_AMOUNT / 2);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GUARDIAN MANAGEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_setGuardian_byCurrentGuardian() public {
        address newGuardian = address(0xCAFE);

        vm.prank(guardian);
        token.setGuardian(newGuardian);

        assertEq(token.guardian(), newGuardian);
    }

    function test_setGuardian_emitsEvent() public {
        address newGuardian = address(0xCAFE);

        vm.expectEmit(true, true, false, false);
        emit GuardianChanged(guardian, newGuardian);

        vm.prank(guardian);
        token.setGuardian(newGuardian);
    }

    function test_setGuardian_oldGuardianLosesAccess() public {
        address newGuardian = address(0xCAFE);

        vm.prank(guardian);
        token.setGuardian(newGuardian);

        // Old guardian cannot pause anymore
        vm.prank(guardian);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.pause();

        // New guardian can pause
        vm.prank(newGuardian);
        token.pause();
        assertTrue(token.paused());
    }

    function test_setGuardian_revertsOnZeroAddress() public {
        vm.prank(guardian);
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        token.setGuardian(address(0));
    }

    function test_setGuardian_revertsWhenCalledByNonGuardian() public {
        vm.prank(attacker);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.setGuardian(address(0xCAFE));
    }

    function test_setGuardian_revertsWhenCalledBySecureMintPolicy() public {
        vm.prank(secureMintPolicy);
        vm.expectRevert(BackedToken.OnlyGuardian.selector);
        token.setGuardian(address(0xCAFE));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // IMMUTABILITY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_secureMintPolicy_isImmutable() public view {
        // secureMintPolicy is declared immutable in the contract.
        // Verify it remains the same after various operations.
        assertEq(token.secureMintPolicy(), secureMintPolicy);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERC-20 STANDARD TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_decimals_defaultsTo18() public view {
        assertEq(token.decimals(), 18);
    }

    function test_approve_and_allowance() public {
        vm.prank(secureMintPolicy);
        token.mint(user, MINT_AMOUNT);

        vm.prank(user);
        token.approve(recipient, MINT_AMOUNT / 4);

        assertEq(token.allowance(user, recipient), MINT_AMOUNT / 4);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function testFuzz_mint_arbitraryAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        vm.prank(secureMintPolicy);
        token.mint(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_burn_partialBalance(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        burnAmount = bound(burnAmount, 1, mintAmount);

        vm.prank(secureMintPolicy);
        token.mint(user, mintAmount);

        vm.prank(user);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testFuzz_onlySecureMintCanMint(address caller) public {
        vm.assume(caller != secureMintPolicy);
        vm.assume(caller != address(0));

        vm.prank(caller);
        vm.expectRevert(BackedToken.OnlySecureMint.selector);
        token.mint(user, MINT_AMOUNT);
    }
}
