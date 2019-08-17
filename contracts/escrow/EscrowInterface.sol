pragma solidity ^0.5.0;

import "../lib/token/IERC20.sol";

/**
 * @title Interface for user and issuance escrow.
 */
interface EscrowInterface  {

    event EtherDeposited(address indexed payee, uint256 amount);
    event EtherWithdrawn(address indexed payee, uint256 amount);
    event TokenDeposited(address indexed payee, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed payee, address indexed token, uint256 amount);

    /**********************************************
     * API for users to deposit and withdraw Ether
     ***********************************************/

    /**
     * @dev Get the current balance in the escrow
     * @return Current balance of the invoker
     */
    function balanceOf() external view returns (uint256);

    /**
     * @dev Deposits Ethers into the escrow
     */
    function deposit() external payable;

    /**
     * @dev Withdraw Ethers from the escrow
     * @param amount The amount of Ethers to withdraw
     */
    function withdraw(uint256 amount) external;

    /***********************************************
     *  API for users to deposit and withdraw IERC20 token
     **********************************************/

    /**
     * @dev Get the balance of the requested IERC20 token in the escrow
     * @param token The IERC20 token to check balance
     * @return The balance
     */
    function tokenBalanceOf(IERC20 token) external view returns (uint256);

    /**
     * @dev Deposit IERC20 token to the escrow
     * @param token The IERC20 token to deposit
     * @param amount The amount to deposit
     */
    function depositToken(IERC20 token, uint256 amount) external;

    /**
     * @dev Withdraw IERC20 token from the escrow
     * @param token The IERC20 token to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawToken(IERC20 token, uint256 amount) external;

    /**
     * @dev Get the balance information about all tokens of the user.
     * @param payee The user address
     * @return The balance of all tokens about this user.
     */
    function getUserBalances(address payee) external view returns (string memory);

    /***********************************************
     *  API used by NUTS platform to hold tokens for issuance
     **********************************************/

    /**
     * @dev Get the Ether balance of an issuance in the escrow
     * @param issuanceId The id of the issuance
     * @return The Ether balance of the issuance in the escrow
     */
    function balanceOfIssuance(uint256 issuanceId) external view returns (uint256);

    /**
     * @dev Transfer Ethers from a seller/buyer to the issuance
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param amount The amount of Ether to transfer
     */
    function transferToIssuance(address payee, uint256 issuanceId, uint256 amount) external;

    /**
     * @dev Transfer Ethers from an issuance to a seller/buyer
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param amount The amount of Ether to transfer
     */
    function transferFromIssuance(address payee, uint256 issuanceId, uint256 amount) external;

    /**
     * @dev Get the IERC20 token balance of an issuance in the escrow
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to check balance
     * @return The IERC20 token balance of the issuance in the escrow
     */
    function tokenBalanceOfIssuance(uint256 issuanceId, IERC20 token) external view returns (uint256);

    /**
     * @dev Transfer IERC20 token from a seller/buyer to the issuance
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to transfer
     * @param amount The amount of IERC20 token to transfer
     */
    function transferTokenToIssuance(address payee, uint256 issuanceId, IERC20 token, uint256 amount) external;

    /**
     * @dev Transfer IERC20 token from the issuance to a seller/buyer
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to transfer
     * @param amount The amount of IERC20 token to transfer
     */
    function transferTokenFromIssuance(address payee, uint256 issuanceId, IERC20 token, uint256 amount) external;

    /**
     * @dev Get the balance information about all tokens of the issuance.
     * @param issuanceId The issuance id
     * @return The balance of all tokens about this issuance.
     */
    function getIssuanceBalances(uint256 issuanceId) external view returns (bytes memory);

    /**
     * @dev Migrate the balances of one issuance to another
     * Note: The balances should not have duplicate entries for the same token.
     * @param oldIssuanceId The id of the issuance from where the balance is migrated
     * @param newIssuanceId The id of the issuance to where the balance is migrated
     */
    function migrateIssuanceBalances(uint256 oldIssuanceId, uint256 newIssuanceId) external;

}
