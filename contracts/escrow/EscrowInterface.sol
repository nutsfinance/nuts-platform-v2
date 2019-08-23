pragma solidity ^0.5.0;

import "../lib/token/IERC20.sol";

/**
 * @title Interface for user and issuance escrow.
 * Consists of APIs for both users and instrument managers.
 */
interface EscrowInterface  {
    /**
     * Token is deposited into escrow by user.
     * @param depositer The address of the user who deposits token.
     * @param token The deposit token address.
     * @param amount The deposit token amount.
     */
    event TokenDepositedToEscrow(address indexed depositer, address indexed token, uint256 amount);

    /**
     * Token is withdrawn from escrow by user.
     * @param withdrawer The address of the user who withdraws token.
     * @param token The withdrawal token address.
     * @param amount The withdrawal token amount.
     */
    event TokenWithdrawnFromEscrow(address indexed withdrawer, address indexed token, uint256 amount);

    /**
     * Token in the escrow is tranferred from user to issuance.
     * @param issuanceId The id of the issuance to which the token is transferred.
     * @param user The address of the user from which the token is transferred.
     * @param token The transfer token address.
     * @param amount The transfer token amount.
     */
    event TokenTransferredToIssuance(uint256 indexed issuanceId, address indexed user, address indexed token, uint256 amount);

    /**
     * Token in the escrow is tranferred from issuance to user.
     * @param issuanceId The id of the issuance from which the token is transferred.
     * @param user The address of the user to which the token is transferred.
     * @param token The transfer token address.
     * @param amount The transfer token amount.
     */
    event TokenTransferredFromIssuance(uint256 indexed issuanceId, address indexed user, address indexed token, uint256 amount);

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

    /***********************************************
     *  API to get balance information.
     **********************************************/

    /**
     * @dev Get the balance information about all tokens of the user.
     * @param userAddress The user address to check balance
     * @return The balance of all tokens about this user.
     */
    function getUserBalances(address userAddress) external view returns (bytes memory);

    /**
     * @dev Get the balance information about all tokens of the issuance.
     * @param issuanceId The id of issuance to check balance
     * @return The balance of all tokens about this issuance.
     */
    function getIssuanceBalances(uint256 issuanceId) external view returns (bytes memory);

    /**
     * @dev Get the ETH balance of an issuance
     * @param issuanceId The id of the issuance to check ETH balance.
     * @return The issuance ETH balance.
     */
    function issuanceBalanceOf(uint256 issuanceId) external view returns (uint256);

    /**
     * @dev Get the ERC20 token balance of an issuance
     * @param issuanceId The id of the issuance to check ERC20 token balance.
     * @param token Which token is checked.
     * @return The issuance ETH balance.
     */
    function issuanceTokenBalanceOf(uint256 issuanceId, IERC20 token) external view returns (uint256);

    /***********************************************
     *  API used by Instrument Manager to manager tokens for issuance
     **********************************************/

    /**
     * @dev Process transfer actions between users and issuance.
     * @param transfersData The serialized transfer actions
     */
    function processTransfers(bytes calldata transfersData) external;

    /**
     * @dev Migrate the balances of one issuance to another
     * Note: The balances should not have duplicate entries for the same token.
     * @param oldIssuanceId The id of the issuance from where the balance is migrated
     * @param newIssuanceId The id of the issuance to where the balance is migrated
     */
    function migrateIssuanceBalances(uint256 oldIssuanceId, uint256 newIssuanceId) external;

}
