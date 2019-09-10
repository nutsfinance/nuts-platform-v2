pragma solidity ^0.5.0;

import "../lib/math/SafeMath.sol";
import "../lib/token/IERC20.sol";
import "../lib/token/SafeERC20.sol";
import "../lib/access/Ownable.sol";
import "../lib/util/Constants.sol";
import "./EscrowBaseInterface.sol";

/**
 * @title Base contract for both instrument and issuance escrow.
 */
contract EscrowBase is EscrowBaseInterface, Ownable {
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
    function getTokenBalance(address account, IERC20 token) public view returns (uint256) {
        return _accountBalances[account].tokenBalances[address(token)];
    }

    /**
     * @dev Get the list of tokens that are deposited in the escrow.
     * @param account The address to check the deposited token list.
     * @return The list of tokens deposited in the escrow.
     */
    function getDepositTokens(address account) public view returns (address[] memory tokens) {
        address[] storage tokenList = _accountBalances[account].tokenList;
        address ethAddress = Constants.getEthAddress();
        bool ethFound = false;

        // Don't return ETH as it's treated with a special address internally.
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == ethAddress) {
                ethFound = true;
                break;
            }
        }
        tokens = new address[](ethFound ? tokenList.length - 1 : tokenList.length);
        uint256 j = 0;
        for (uint i = 0; i < tokenList.length; i++) {
            if (tokenList[i] != ethAddress) {
                tokens[j] = tokenList[i];
                j++;
            }
        }
    }

    /****************************************************************
     * Public methods for Instrument Manager.
     ***************************************************************/

    /**
     * @dev Deposits ETH from Instrument Manager into an account.
     * The tranfer action is done outside this function.
     * @param account The account to deposit ETH.
     */
    function depositByAdmin(address account) public payable onlyOwner {
        uint256 amount = msg.value;
        _addToBalance(account, Constants.getEthAddress(), amount);
    }

    /**
     * @dev Deposits ERC20 tokens from Instrument Manager into an account.
     * The transfer action is done outside this function.
     * Note: There is NO WAY to verify that ERC20 token is indeed transferred.
     * We trust the caller, i.e. Instrument Manager handles it propertly.
     * @param account The account to deposit ERC20 tokens.
     * @param token The ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     */
    function depositTokenByAdmin(address account, address token, uint256 amount) public onlyOwner {
        _addToBalance(account, token, amount);
    }

    /**
     * @dev Withdraw ETH from an account to Instrument Manager.
     * The transfer action is done inside this function.
     * @param account The account to withdraw ETH.
     * @param amount The amount of ETH to withdraw.
     */
    function withdrawByAdmin(address account, uint256 amount) public onlyOwner {
        require(account != address(0x0), "EscrowBase: Account must be set.");
        require(amount > 0, "EscrowBase: Amount must be set.");
        require(getBalance(account) >= amount, "EscrowBase: Insufficient ETH Balance.");

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
        require(account != address(0x0), "EscrowBase: Account must be set.");
        require(token != address(0x0), "EscrowBase: Token must be set.");
        require(amount > 0, "EscrowBase: Amount must be set.");
        require(getTokenBalance(account, IERC20(token)) >= amount, "EscrowBase: Insufficient Token Balance.");

        _reduceFromBalance(account, token, amount);

        IERC20(token).transfer(owner(), amount);
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

        // If the balance is zero, remove from token list.
        if (accountBalance.tokenBalances[token] == 0) {
            // If there are more than 1 token in the list
            if (accountBalance.tokenList.length > 1) {
                // Move the last token to replace the current token
                address lastTokenAddress = accountBalance.tokenList[accountBalance.tokenList.length - 1];
                accountBalance.tokenList[accountBalance.tokenIndeces[token]] = lastTokenAddress;
            }

            accountBalance.tokenList.length = accountBalance.tokenList.length - 1;
            delete accountBalance.tokenBalances[token];
            delete accountBalance.tokenIndeces[token];
        }
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
