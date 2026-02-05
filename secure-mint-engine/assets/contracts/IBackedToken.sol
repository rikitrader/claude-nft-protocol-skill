// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBackedToken
 * @author SecureMintEngine
 * @notice Interface for the BackedToken contract — a minimal ERC-20 "dumb
 *         ledger" whose minting is fully delegated to SecureMintPolicy.
 * @dev The token itself holds NO minting logic. All mint calls are gated by
 *      MINTER_ROLE (assigned to SecureMintPolicy) and all pause operations
 *      are gated by PAUSER_ROLE (assigned to EmergencyPause).
 *
 *      Burning is permissionless — any holder can burn their own tokens via
 *      the inherited ERC20Burnable functionality.
 */
interface IBackedToken {
    // -------------------------------------------------------------------
    //  Events
    // -------------------------------------------------------------------

    /**
     * @notice Emitted when tokens are transferred (including mint and burn).
     * @param from   The sender address (address(0) for mints).
     * @param to     The recipient address (address(0) for burns).
     * @param value  The amount transferred.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @notice Emitted when a spender allowance is set.
     * @param owner   The token owner.
     * @param spender The approved spender.
     * @param value   The approved amount.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Emitted when the contract is paused.
     * @param account The address that triggered the pause.
     */
    event Paused(address indexed account);

    /**
     * @notice Emitted when the contract is unpaused.
     * @param account The address that triggered the unpause.
     */
    event Unpaused(address indexed account);

    // -------------------------------------------------------------------
    //  Constants (Roles)
    // -------------------------------------------------------------------

    /**
     * @notice Role identifier for addresses permitted to mint new tokens.
     * @return The keccak256 hash of "MINTER_ROLE".
     */
    // slither-disable-next-line naming-convention
    function MINTER_ROLE() external view returns (bytes32);

    /**
     * @notice Role identifier for addresses permitted to pause/unpause transfers.
     * @return The keccak256 hash of "PAUSER_ROLE".
     */
    // slither-disable-next-line naming-convention
    function PAUSER_ROLE() external view returns (bytes32);

    // -------------------------------------------------------------------
    //  External — Minting (MINTER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Mints `amount` tokens to `to`.
     * @dev Callable only by MINTER_ROLE (the SecureMintPolicy contract).
     *      The policy enforces all mint conditions before calling this.
     * @param to     Recipient of the minted tokens.
     * @param amount Number of tokens to mint (in base units).
     */
    function mint(address to, uint256 amount) external;

    // -------------------------------------------------------------------
    //  External — Pause Management (PAUSER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Pauses all token transfers (including mint and burn).
     * @dev Callable only by PAUSER_ROLE (typically the EmergencyPause contract).
     */
    function pause() external;

    /**
     * @notice Unpauses token transfers.
     * @dev Callable only by PAUSER_ROLE.
     */
    function unpause() external;

    // -------------------------------------------------------------------
    //  External — EmergencyPause Integration Hook
    // -------------------------------------------------------------------

    /**
     * @notice Called by EmergencyPause when pause level changes.
     * @dev Level 0-1: unpause transfers. Level 2-3: pause transfers.
     *      Only callable by PAUSER_ROLE (EmergencyPause contract).
     * @param level The new pause level (0=Normal, 1=MintPaused, 2=Restricted, 3=FullFreeze).
     */
    function onPauseLevelChanged(uint8 level) external;

    // -------------------------------------------------------------------
    //  View Functions
    // -------------------------------------------------------------------

    /**
     * @notice Returns the number of decimals for this token.
     * @return The decimal count set at deployment.
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Returns the total supply of tokens in circulation.
     * @return The total token supply in base units.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the token balance of `account`.
     * @param account The address to query.
     * @return The token balance in base units.
     */
    function balanceOf(address account) external view returns (uint256);
}
