pragma solidity ^0.5.0;

import "./EscrowInterface.sol";
import "../lib/protobuf/TokenBalance.sol";
import "../lib/protobuf/TokenTransfer.sol";
import "../lib/access/Ownable.sol";
import "../lib/math/SafeMath.sol";
import "../lib/token/IERC20.sol";
import "../lib/token/SafeERC20.sol";
import "../lib/util/Constants.sol";

/**
 * @title Escrow for both user and issuance.
 */
contract InstrumentEscrow is EscrowInterface, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => Balances.Data) private _userBalances;                // Balance of user
    mapping(uint256 => Balances.Data) private _issuanceBalances;            // Balance of issuance

    /**********************************************
     * API for users to deposit and withdraw Ether
     ***********************************************/

    /**
     * @dev Get the current balance in the escrow
     * @return Current balance of the invoker
     */
    function balanceOf() public view returns (uint256) {
        Balances.Data storage userBalances = _userBalances[msg.sender];
        return getBalanceAmount(userBalances, Constants.getEthAddress());
    }

    /**
     * @dev Deposits Ethers into the escrow
     */
    function deposit() public payable {
        uint256 amount = msg.value;
        Balances.Data storage userBalances = _userBalances[msg.sender];
        Balance.Data storage userBalance = getBalanceAndAddIfMissing(userBalances, Constants.getEthAddress());
        userBalance.amount = userBalance.amount.add(amount);

        emit TokenDepositedToEscrow(msg.sender, Constants.getEthAddress(), amount);
    }

    /**
     * @dev Withdraw Ethers from the escrow
     * @param amount The amount of Ethers to withdraw
     */
    function withdraw(uint256 amount) public {
        Balances.Data storage userBalances = _userBalances[msg.sender];
        Balance.Data storage userBalance = getBalanceAndAddIfMissing(userBalances, Constants.getEthAddress());
        require(userBalance.amount >= amount, "Insufficial ether balance to withdraw");
        userBalance.amount = userBalance.amount.sub(amount);

        msg.sender.transfer(amount);

        emit TokenWithdrawnFromEscrow(msg.sender, Constants.getEthAddress(), amount);
    }

    /***********************************************
     *  API for users to deposit and withdraw IERC20 token
     **********************************************/

    /**
     * @dev Get the balance of the requested IERC20 token in the escrow
     * @param token The IERC20 token to check balance
     * @return The balance
     */
    function tokenBalanceOf(IERC20 token) public view returns (uint256) {
        Balances.Data storage userBalances = _userBalances[msg.sender];
        return getBalanceAmount(userBalances, address(token));
    }

    /**
     * @dev Deposit IERC20 token to the escrow
     * @param token The IERC20 token to deposit
     * @param amount The amount to deposit
     */
    function depositToken(IERC20 token, uint256 amount) public {
      Balances.Data storage userBalances = _userBalances[msg.sender];
      Balance.Data storage userBalance = getBalanceAndAddIfMissing(userBalances, address(token));
      userBalance.amount = userBalance.amount.add(amount);

      emit TokenDepositedToEscrow(msg.sender, address(token), amount);
    }

    /**
     * @dev Withdraw IERC20 token from the escrow
     * @param token The IERC20 token to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawToken(IERC20 token, uint256 amount) public {
      Balances.Data storage userBalances = _userBalances[msg.sender];
      Balance.Data storage userBalance = getBalanceAndAddIfMissing(userBalances, address(token));
      userBalance.amount = userBalance.amount.sub(amount);

      token.safeTransfer(msg.sender, amount);

      emit TokenWithdrawnFromEscrow(msg.sender, address(token), amount);
    }

    /***********************************************
     *  API to get balance information.
     **********************************************/

    /**
     * @dev Get the balance information about all tokens of the user.
     * @param userAddress The user address to check balance
     * @return The balance of all tokens about this user.
     */
    function getUserBalances(address userAddress) public view returns (bytes memory) {
      return Balances.encode(_userBalances[userAddress]);
    }

    /**
     * @dev Get the balance information about all tokens of the issuance.
     * @param issuanceId The id of issuance to check balance
     * @return The balance of all tokens about this issuance.
     */
    function getIssuanceBalances(uint256 issuanceId) public view returns (bytes memory) {
      return Balances.encode(_issuanceBalances[issuanceId]);
    }

    /**
     * @dev Get the ETH balance of an issuance
     * @param issuanceId The id of the issuance to check ETH balance.
     * @return The issuance ETH balance.
     */
    function issuanceBalanceOf(uint256 issuanceId) public view returns (uint256) {
      Balances.Data storage issuanceBalances = _issuanceBalances[issuanceId];
      return getBalanceAmount(issuanceBalances, Constants.getEthAddress());
    }

    /**
     * @dev Get the ERC20 token balance of an issuance
     * @param issuanceId The id of the issuance to check ERC20 token balance.
     * @param token Which token is checked.
     * @return The issuance ETH balance.
     */
    function issuanceTokenBalanceOf(uint256 issuanceId, IERC20 token) public view returns (uint256) {
      Balances.Data storage issuanceBalances = _issuanceBalances[issuanceId];
      return getBalanceAmount(issuanceBalances, address(token));
    }

    /***********************************************
     *  API used by Instrument Manager to manager tokens for issuance
     **********************************************/

    /**
     * @dev Process transfer actions between users and issuance.
     * @param transfersData The serialized transfer actions
     */
    function processTransfers(bytes memory transfersData) public onlyOwner {
      Transfers.Data memory transfers = Transfers.decode(transfersData);
      for (uint i = 0; i < transfers.actions.length; i++) {
        // Check whether it's from user or to user
        Transfer.Data memory transfer = transfers.actions[i];
        Balances.Data storage userBalances = _userBalances[transfer.userAddress];
        Balance.Data storage userBalance = getBalanceAndAddIfMissing(userBalances, transfer.tokenAddress);
        Balances.Data storage issuanceBalances = _issuanceBalances[transfer.issuanceId];
        Balance.Data storage issuanceBalance = getBalanceAndAddIfMissing(issuanceBalances, transfer.tokenAddress);
        if (transfer.fromUser) {
          userBalance.amount = userBalance.amount.sub(transfer.amount);
          issuanceBalance.amount = issuanceBalance.amount.add(transfer.amount);
        } else {
          userBalance.amount = userBalance.amount.add(transfer.amount);
          issuanceBalance.amount = issuanceBalance.amount.sub(transfer.amount);
        }
      }
    }

    /**
     * @dev Migrate the balances of one issuance to another
     * Note: The balances should not have duplicate entries for the same token.
     * @param oldIssuanceId The id of the issuance from where the balance is migrated
     * @param newIssuanceId The id of the issuance to where the balance is migrated
     */
    function migrateIssuanceBalances(uint256 oldIssuanceId, uint256 newIssuanceId) public onlyOwner {
      Balances.Data storage oldBalances = _issuanceBalances[oldIssuanceId];
      Balances.Data storage newBalances = _issuanceBalances[newIssuanceId];

      // For each token in the old issuance
      for (uint i = 0; i < oldBalances.entries.length; i++) {
        Balance.Data storage newBalance = getBalanceAndAddIfMissing(newBalances, oldBalances.entries[i].tokenAddress);
        newBalance.amount = newBalance.amount.add(oldBalances.entries[i].amount);
      }
    }

    /**
     * @dev Get the balance amount of a token in the balances.
     * @param balances The balances to check.
     * @param tokenAddress The address of the token to check balance.
     * @return The amount of this token in the balances. Return 0 if this token is not in the balances.
     */
    function getBalanceAmount(Balances.Data storage balances, address tokenAddress) private view returns (uint256) {
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].tokenAddress == tokenAddress) {
          return balances.entries[i].amount;
        }
      }
      return 0;
    }

    /**
     * @dev Get the balance entry of a token in the balances. Create and return a new balance entry
     * if this token is not in the balances.
     * @param balances The balances to check.
     * @param tokenAddress The address of the token to check balance.
     * @return The balance entry of this token in the balances.
     */
    function getBalanceAndAddIfMissing(Balances.Data storage balances, address tokenAddress) private returns (Balance.Data storage) {
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].tokenAddress == tokenAddress) {
          return balances.entries[i];
        }
      }
      Balance.Data memory newBalance = Balance.Data(tokenAddress, 0);
      balances.entries.push(newBalance);
      return balances.entries[balances.entries.length - 1];
    }
}
