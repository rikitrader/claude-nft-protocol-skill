// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBackedToken
 * @notice Interface for the BackedToken ERC-20 dumb ledger
 * @dev The token contract holds no business logic. Mint is restricted to the policy contract.
 */
interface IBackedToken {
    /// @notice Mint tokens to an address (only callable by MINTER_ROLE)
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from caller's balance
    function burn(uint256 amount) external;

    /// @notice Get total supply of tokens
    function totalSupply() external view returns (uint256);

    /// @notice Get balance of an address
    function balanceOf(address account) external view returns (uint256);

    /// @notice Get the token name
    function name() external view returns (string memory);

    /// @notice Get the token symbol
    function symbol() external view returns (string memory);

    /// @notice Get decimals (default 18)
    function decimals() external view returns (uint8);
}
