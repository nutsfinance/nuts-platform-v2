pragma solidity ^0.5.0;

import "../lib/token/IERC20.sol";

/**
 * @title Base interface for both instrument and issuance escrows.
 * Abstract contract is used instead of interface as interface does not support inheritance.
 */
contract EscrowBaseInterface {

    /**
     * @dev Get the current ETH balance of an account in the escrow.
     * @param account The account to check ETH balance.
     * @return Current ETH balance of the account.
     */
    function getBalance(address account) public view returns (uint256);

    /**
     * @dev Get the balance of the requested IERC20 token in the escrow.
     * @param account The address to check IERC20 balance.
     * @param token The IERC20 token to check balance.
     * @return The balance of the account.
     */
    function getTokenBalance(address account, IERC20 token) public view returns (uint256);

    /**
     * @dev Get the list of tokens that are deposited in the escrow.
     * @param account The address to check the deposited token list.
     * @return The list of tokens deposited in the escrow.
     */
    function getTokenList(address account) public view returns (address[] memory tokens);
}