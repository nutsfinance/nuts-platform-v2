pragma solidity 0.5.16;

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
    function getTokenBalance(address account, address token) public view returns (uint256);

    /**
     * @dev Get the list of tokens that are deposited in the escrow.
     * @param account The address to check the deposited token list.
     * @return The list of tokens deposited in the escrow.
     */
    function getTokenList(address account) public view returns (address[] memory tokens);

    /**
     * @dev Deposits ETH from Instrument Manager into an account.
     * @param account The account to deposit ETH.
     */
    function depositByAdmin(address account) public payable;

    /**
     * @dev Deposits ERC20 tokens from Instrument Manager into an account.
     * Note: The owner, i.e. Instrument Manager must set the allowance before hand.
     * @param account The account to deposit ERC20 tokens.
     * @param token The ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     */
    function depositTokenByAdmin(address account, address token, uint256 amount) public;

    /**
     * @dev Withdraw ETH from an account to Instrument Manager.
     * @param account The account to withdraw ETH.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawByAdmin(address account, uint256 amount) public;

    /**
     * @dev Withdraw ERC20 token from an account to Instrument Manager.
     * The transfer action is done inside this function.
     * @param account The account to withdraw ERC20 token.
     * @param token The ERC20 token to withdraw.
     * @param amount The amount of ERC20 tokens to withdraw.
     */
    function withdrawTokenByAdmin(address account, address token, uint256 amount) public;
}
