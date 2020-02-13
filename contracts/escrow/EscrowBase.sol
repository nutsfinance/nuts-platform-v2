pragma solidity 0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../lib/util/Constants.sol";
import "./EscrowBaseInterface.sol";

/**
 * @title Base contract for both instrument and issuance escrow.
 */
contract EscrowBase is EscrowBaseInterface, Ownable {
    /**
     * Balance is increased.
     */
    event BalanceIncreased(address account, address token, uint256 amount);

    /**
     * Balance is decreased.
     */
    event BalanceDecreased(address account, address token, uint256 amount);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to store the balances of one account.
     */
    struct AccountBalance {
        // Mapping: ERC20 token address => ERC20 token amount.
        // ETH is treated specially with adress Constants.getEthAddress()
        mapping(address => uint256) tokenBalances;
        // Mapping: ERC20 token address => ERC20 token address index in the token list.
        // Note: The index starts with 1.
        mapping(address => uint256) tokenIndeces;
        // Token address list. Should not have any duplicate.
        address[] tokenList;
    }

    /**
     * Mapping: Account address => Account balances
     */
    mapping(address => AccountBalance) _accountBalances;

    /*******************************************************
     * Implements methods defined in EscrowBaseInterface.
     *******************************************************/

    /**
     * @dev Get the current ETH balance of an account in the escrow.
     * @param account The account to check ETH balance.
     * @return Current ETH balance of the account.
     */
    function getBalance(address account) public view returns (uint256) {
        return _accountBalances[account].tokenBalances[Constants.getEthAddress()];
    }

    /**
     * @dev Get the balance of the requested IERC20 token in the escrow.
     * @param account The address to check IERC20 balance.
     * @param token The IERC20 token to check balance.
     * @return The balance of the account.
     */
    function getTokenBalance(address account, address token) public view returns (uint256) {
        return _accountBalances[account].tokenBalances[address(token)];
    }

    /**
     * @dev Get the list of tokens that are deposited in the escrow.
     * @param account The address to check the deposited token list.
     * @return The list of tokens deposited in the escrow.
     */
    function getTokenList(address account) public view returns (address[] memory) {
        return _accountBalances[account].tokenList;
    }

    /****************************************************************
     * Public methods for Instrument Manager.
     ***************************************************************/

    /**
     * @dev Deposits ETH from Instrument Manager into an account.
     * @param account The account to deposit ETH.
     */
    function depositByAdmin(address account) public payable onlyOwner {
        uint256 amount = msg.value;
        require(account != address(0x0), "EscrowBase: Account not set");
        require(amount > 0, "EscrowBase: Amount not set");

        _addToBalance(account, Constants.getEthAddress(), amount);
    }

    /**
     * @dev Deposits ERC20 tokens from Instrument Manager into an account.
     * Note: The owner, i.e. Instrument Manager must set the allowance before hand.
     * @param account The account to deposit ERC20 tokens.
     * @param token The ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     */
    function depositTokenByAdmin(address account, address token, uint256 amount) public onlyOwner {
        require(account != address(0x0), "EscrowBase: Account not set");
        require(token != address(0x0), "EscrowBase: Token not set");
        require(amount > 0, "EscrowBase: Amount not set");

        _addToBalance(account, token, amount);

        IERC20(token).safeTransferFrom(owner(), address(this), amount);
    }

    /**
     * @dev Withdraw ETH from an account to Instrument Manager.
     * @param account The account to withdraw ETH.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawByAdmin(address account, uint256 amount) public onlyOwner {
        require(account != address(0x0), "EscrowBase: Account not set");
        require(amount > 0, "EscrowBase: Amount not set");
        require(getBalance(account) >= amount, "EscrowBase: Insufficient ETH Balance");

        _reduceFromBalance(account, Constants.getEthAddress(), amount);

        msg.sender.transfer(amount);
    }

    /**
     * @dev Withdraw ERC20 token from an account to Instrument Manager.
     * The transfer action is done inside this function.
     * @param account The account to withdraw ERC20 token.
     * @param token The ERC20 token to withdraw.
     * @param amount The amount of ERC20 tokens to withdraw.
     */
    function withdrawTokenByAdmin(address account, address token, uint256 amount) public onlyOwner {
        require(account != address(0x0), "EscrowBase: Account not set");
        require(token != address(0x0), "EscrowBase: Token not set");
        require(amount > 0, "EscrowBase: Amount not set");
        require(getTokenBalance(account, token) >= amount, "EscrowBase: Insufficient Token Balance");

        _reduceFromBalance(account, token, amount);

        IERC20(token).safeTransfer(owner(), amount);
    }

    /****************************************************************
     * Internal methods shared by Instrument and Issuance Escrows.
     ***************************************************************/

    /**
     * @dev Add more tokens to the account's balance.
     * @param account The account to add balance.
     * @param token The token to add to the balance.
     * @param amount The amount to add to the balance.
     */
    function _addToBalance(address account, address token, uint256 amount) internal {
        AccountBalance storage accountBalance = _accountBalances[account];
        accountBalance.tokenBalances[token] = accountBalance.tokenBalances[token].add(amount);

        // If the token is not in the token list, add it
        if (accountBalance.tokenIndeces[token] == 0) {
            accountBalance.tokenList.push(token);
            accountBalance.tokenIndeces[token] = accountBalance.tokenList.length;
        }

        emit BalanceIncreased(account, token, amount);
    }

    /**
     * @dev Reduce tokens from the account's balance.
     * @param account The account to reduce balance.
     * @param token The token to reduce from the balance.
     * @param amount The amount to reduce from the balance.
     */
    function _reduceFromBalance(address account, address token, uint256 amount) internal {
        AccountBalance storage accountBalance = _accountBalances[account];
        accountBalance.tokenBalances[token] = accountBalance.tokenBalances[token].sub(amount);

        emit BalanceDecreased(account, token, amount);
    }

    /**
     * @dev Transfer the ownership of tokens in the escrow.
     * @param source The current account that owns the tokens.
     * @param dest The target account that will own the tokens.
     * @param token The token to transfer.
     * @param amount The amount to transfer.
     */
    function _migrateBalance(address source, address dest, address token, uint256 amount) internal {
        _reduceFromBalance(source, token, amount);
        _addToBalance(dest, token, amount);
    }
}
