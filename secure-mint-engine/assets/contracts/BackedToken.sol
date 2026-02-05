// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title BackedToken
 * @author SecureMintEngine
 * @notice Minimal ERC-20 "dumb ledger" for a backed token. This contract
 *         holds NO minting logic — all minting is delegated to the
 *         SecureMintPolicy contract via the MINTER_ROLE.
 *
 * @dev Design principles:
 *      - The token itself is a thin ledger: balances and transfers only.
 *      - Minting is gated by MINTER_ROLE (assigned to SecureMintPolicy).
 *      - Burning is permissionless (any holder can burn their own tokens).
 *      - Transfers can be paused by PAUSER_ROLE (assigned to EmergencyPause).
 *      - Name, symbol, and decimals are immutable after deployment.
 */
contract BackedToken is ERC20, ERC20Burnable, AccessControl, Pausable {
    // -------------------------------------------------------------------
    //  Roles
    // -------------------------------------------------------------------

    /// @notice Only addresses with MINTER_ROLE can mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Only addresses with PAUSER_ROLE can pause/unpause transfers.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // -------------------------------------------------------------------
    //  Custom Errors
    // -------------------------------------------------------------------

    /// @notice A zero address was supplied where it is not allowed.
    error ZeroAddress();

    // -------------------------------------------------------------------
    //  State
    // -------------------------------------------------------------------

    /// @notice Token decimals (immutable after deployment).
    uint8 private immutable _decimals;

    // -------------------------------------------------------------------
    //  Constructor
    // -------------------------------------------------------------------

    /**
     * @notice Deploys the BackedToken with a fixed name, symbol, and decimals.
     * @param name_     The full token name (e.g., "USD Backed Token").
     * @param symbol_   The token symbol (e.g., "USDX").
     * @param decimals_ The number of decimal places (typically 6 or 18).
     * @param admin     The initial DEFAULT_ADMIN_ROLE holder. This address
     *                  can later grant MINTER_ROLE and PAUSER_ROLE.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin
    ) ERC20(name_, symbol_) {
        if (admin == address(0)) revert ZeroAddress();

        _decimals = decimals_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // -------------------------------------------------------------------
    //  External — Minting (MINTER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Mints `amount` tokens to `to`.
     * @dev Callable only by MINTER_ROLE (the SecureMintPolicy contract).
     *      The policy enforces all 6 mint conditions before calling this.
     * @param to     Recipient of the minted tokens.
     * @param amount Number of tokens to mint (in base units).
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, amount);
    }

    // -------------------------------------------------------------------
    //  External — Pause Management (PAUSER_ROLE only)
    // -------------------------------------------------------------------

    /**
     * @notice Pauses all token transfers (including mint and burn).
     * @dev Callable only by PAUSER_ROLE (typically the EmergencyPause contract).
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses token transfers.
     * @dev Callable only by PAUSER_ROLE.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // -------------------------------------------------------------------
    //  External — EmergencyPause Integration Hook
    // -------------------------------------------------------------------

    /**
     * @notice Called by EmergencyPause when pause level changes.
     * @dev Level 0-1: unpause transfers. Level 2-3: pause transfers.
     *      Only callable by PAUSER_ROLE (EmergencyPause contract).
     * @param level The new pause level (0=Normal, 1=MintPaused, 2=Restricted, 3=FullFreeze).
     */
    function onPauseLevelChanged(uint8 level) external onlyRole(PAUSER_ROLE) {
        if (level >= 2) {
            if (!paused()) _pause();
        } else {
            if (paused()) _unpause();
        }
    }

    // -------------------------------------------------------------------
    //  Public — Overrides
    // -------------------------------------------------------------------

    /**
     * @notice Returns the number of decimals for this token.
     * @return The decimal count set at deployment.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // -------------------------------------------------------------------
    //  Internal — Transfer Hook (pause enforcement)
    // -------------------------------------------------------------------

    /**
     * @dev Overrides the ERC-20 `_update` hook to enforce pause state.
     *      When paused, ALL transfers (including mint and burn) revert.
     * @param from   Source address (address(0) for mints).
     * @param to     Destination address (address(0) for burns).
     * @param value  Amount being transferred.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
