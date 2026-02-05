// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BackedToken.sol";

/**
 * @title BackedTokenTest
 * @notice Unit tests for the BackedToken ERC-20 ledger contract.
 */
contract BackedTokenTest is Test {
    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    BackedToken public token;

    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public pauser = makeAddr("pauser");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // -------------------------------------------------------------------
    //  Setup
    // -------------------------------------------------------------------

    function setUp() public {
        token = new BackedToken("USD Backed Token", "USDX", 18, admin);

        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(PAUSER_ROLE, pauser);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------
    //  Deployment Tests
    // -------------------------------------------------------------------

    function test_DeployWithCorrectParams() public view {
        assertEq(token.name(), "USD Backed Token");
        assertEq(token.symbol(), "USDX");
        assertEq(token.decimals(), 18);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_DeployRevertsWithZeroAdmin() public {
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        new BackedToken("USD Backed Token", "USDX", 18, address(0));
    }

    // -------------------------------------------------------------------
    //  Minting Tests
    // -------------------------------------------------------------------

    function test_MintOnlyByMinterRole() public {
        vm.prank(minter);
        token.mint(user, 1000e18);
        assertEq(token.balanceOf(user), 1000e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    function test_MintRevertsWithoutMinterRole() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 1000e18);
    }

    function test_RevertMintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(BackedToken.ZeroAddress.selector);
        token.mint(address(0), 1000e18);
    }

    function test_MintMultipleTimes() public {
        vm.startPrank(minter);
        token.mint(user, 500e18);
        token.mint(user, 300e18);
        token.mint(recipient, 200e18);
        vm.stopPrank();

        assertEq(token.balanceOf(user), 800e18);
        assertEq(token.balanceOf(recipient), 200e18);
        assertEq(token.totalSupply(), 1000e18);
    }

    // -------------------------------------------------------------------
    //  Burning Tests
    // -------------------------------------------------------------------

    function test_BurnByHolder() public {
        vm.prank(minter);
        token.mint(user, 1000e18);

        vm.prank(user);
        token.burn(400e18);

        assertEq(token.balanceOf(user), 600e18);
        assertEq(token.totalSupply(), 600e18);
    }

    function test_BurnRevertsWhenExceedsBalance() public {
        vm.prank(minter);
        token.mint(user, 100e18);

        vm.prank(user);
        vm.expectRevert();
        token.burn(200e18);
    }

    // -------------------------------------------------------------------
    //  Pause / Unpause Tests
    // -------------------------------------------------------------------

    function test_PauseUnpause() public {
        // Mint tokens first
        vm.prank(minter);
        token.mint(user, 1000e18);

        // Pause blocks transfers
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        vm.prank(user);
        vm.expectRevert();
        token.transfer(recipient, 100e18);

        // Unpause allows transfers
        vm.prank(pauser);
        token.unpause();
        assertFalse(token.paused());

        vm.prank(user);
        token.transfer(recipient, 100e18);
        assertEq(token.balanceOf(recipient), 100e18);
    }

    function test_PauseBlocksMinting() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(user, 1000e18);
    }

    function test_PauseBlocksBurning() public {
        vm.prank(minter);
        token.mint(user, 1000e18);

        vm.prank(pauser);
        token.pause();

        vm.prank(user);
        vm.expectRevert();
        token.burn(500e18);
    }

    function test_PauseRevertsWithoutPauserRole() public {
        vm.prank(user);
        vm.expectRevert();
        token.pause();
    }

    function test_TransferWhilePaused_Reverts() public {
        vm.prank(minter);
        token.mint(user, 1000e18);

        vm.prank(pauser);
        token.pause();

        vm.prank(user);
        vm.expectRevert();
        token.transfer(recipient, 500e18);
    }

    // -------------------------------------------------------------------
    //  onPauseLevelChanged Tests
    // -------------------------------------------------------------------

    function test_OnPauseLevelChanged_Level0Unpauses() public {
        // Pause first
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        // Level 0 should unpause
        vm.prank(pauser);
        token.onPauseLevelChanged(0);
        assertFalse(token.paused());
    }

    function test_OnPauseLevelChanged_Level1Unpauses() public {
        // Pause first
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        // Level 1 should unpause (only transfers, mint paused at policy level)
        vm.prank(pauser);
        token.onPauseLevelChanged(1);
        assertFalse(token.paused());
    }

    function test_OnPauseLevelChanged_Level2Pauses() public {
        assertFalse(token.paused());

        vm.prank(pauser);
        token.onPauseLevelChanged(2);
        assertTrue(token.paused());
    }

    function test_OnPauseLevelChanged_Level3Pauses() public {
        assertFalse(token.paused());

        vm.prank(pauser);
        token.onPauseLevelChanged(3);
        assertTrue(token.paused());
    }

    function test_OnPauseLevelChanged_IdempotentPause() public {
        // Already unpaused, level 0 does not revert
        vm.prank(pauser);
        token.onPauseLevelChanged(0);
        assertFalse(token.paused());

        // Already paused at level 2, level 3 stays paused without revert
        vm.prank(pauser);
        token.onPauseLevelChanged(2);
        assertTrue(token.paused());

        vm.prank(pauser);
        token.onPauseLevelChanged(3);
        assertTrue(token.paused());
    }

    function test_OnPauseLevelChanged_RevertsWithoutPauserRole() public {
        vm.prank(user);
        vm.expectRevert();
        token.onPauseLevelChanged(2);
    }

    // -------------------------------------------------------------------
    //  Access Control Tests
    // -------------------------------------------------------------------

    function test_AdminCanGrantRoles() public {
        address newMinter = makeAddr("newMinter");

        vm.prank(admin);
        token.grantRole(MINTER_ROLE, newMinter);
        assertTrue(token.hasRole(MINTER_ROLE, newMinter));

        vm.prank(newMinter);
        token.mint(user, 100e18);
        assertEq(token.balanceOf(user), 100e18);
    }

    function test_AdminCanRevokeRoles() public {
        vm.prank(admin);
        token.revokeRole(MINTER_ROLE, minter);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(user, 100e18);
    }
}
