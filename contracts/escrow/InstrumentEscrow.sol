pragma solidity ^0.5.0;

import "./TokenBalance.sol";
import "./EscrowInterface.sol";
import "../lib/access/WhitelistAdminRole.sol";
import "../lib/math/SafeMath.sol";
import "../lib/token/IERC20.sol";
import "../lib/token/SafeERC20.sol";

/**
 * @title Escrow for both user and issuance.
 * Note: Unlike other infrastructure components of NUTS platform,
 * data of NutsEscrow is stored locally instead of in UnifiedStorage
 * as we don't expect NutsEscrow to upgrade.
 * Might review this decision later.
 */
contract NutsEscrow is EscrowInterface, WhitelistAdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Balances for Balances.Data;

    event EtherDeposited(address indexed payee, uint256 amount);
    event EtherWithdrawn(address indexed payee, uint256 amount);
    event TokenDeposited(address indexed payee, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed payee, address indexed token, uint256 amount);

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
        Balances.Data storage balances = _userBalances[msg.sender];
        for (uint i = 0; i < balances.entries.length; i++) {
            if (balances.entries[i].isEther) {
                return balances.entries[i].amount;
            }
        }
        return 0;
    }

    /**
     * @dev Deposits Ethers into the escrow
     */
    function deposit() public payable {
        uint256 amount = msg.value;
        Balance.Data storage userBalance = getUserEtherBalance(msg.sender);
        userBalance.amount = userBalance.amount.add(amount);

        emit EtherDeposited(msg.sender, amount);
    }

    /**
     * @dev Withdraw Ethers from the escrow
     * @param amount The amount of Ethers to withdraw
     */
    function withdraw(uint256 amount) public {
        Balance.Data storage userBalance = getUserEtherBalance(msg.sender);
        require(userBalance.amount >= amount, "Insufficial ether balance to withdraw");
        userBalance.amount = userBalance.amount.sub(amount);

        msg.sender.transfer(amount);

        emit EtherWithdrawn(msg.sender, amount);
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
        Balances.Data storage balances = _userBalances[msg.sender];
        for (uint i = 0; i < balances.entries.length; i++) {
            if (balances.entries[i].tokenAddress == address(token)) {
                return balances.entries[i].amount;
            }
        }
        return 0;
    }

    /**
     * @dev Deposit IERC20 token to the escrow
     * @param token The IERC20 token to deposit
     * @param amount The amount to deposit
     */
    function depositToken(IERC20 token, uint256 amount) public {
        Balance.Data storage userBalance = getUserTokenBalance(msg.sender, address(token));
        userBalance.amount = userBalance.amount.add(amount);
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit TokenDeposited(msg.sender, address(token), amount);
    }

    /**
     * @dev Withdraw IERC20 token from the escrow
     * @param token The IERC20 token to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawToken(IERC20 token, uint256 amount) public {
        Balance.Data storage userBalance = getUserTokenBalance(msg.sender, address(token));
        userBalance.amount = userBalance.amount.sub(amount);

        token.safeTransfer(msg.sender, amount);

        emit TokenWithdrawn(msg.sender, address(token), amount);
    }

    /**
     * @dev Get the balance information about all tokens of the user.
     * @param payee The user address
     * @return The balance of all tokens about this user.
     */
    function getUserBalances(address payee) public view onlyWhitelistAdmin returns (string memory) {
        return string(_userBalances[payee].encode());
    }

    /***********************************************
     *  API used by NUTS platform to hold tokens for issuance
     **********************************************/

    /**
     * @dev Get the Ether balance of an issuance in the escrow
     * @param issuanceId The id of the issuance
     * @return The Ether balance of the issuance in the escrow
     */
    function balanceOfIssuance(uint256 issuanceId) public view onlyWhitelistAdmin returns (uint256) {
        Balances.Data storage balances = _issuanceBalances[issuanceId];
        for (uint i = 0; i < balances.entries.length; i++) {
            if (balances.entries[i].isEther) {
                return balances.entries[i].amount;
            }
        }
        return 0;
    }

    /**
     * @dev Transfer Ethers from a seller/buyer to the issuance
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param amount The amount of Ether to transfer
     */
    function transferToIssuance(address payee, uint256 issuanceId, uint256 amount) public onlyWhitelistAdmin {
        // Subtract from the seller/buyer balance
        Balance.Data storage userBalance = getUserEtherBalance(payee);
        require(userBalance.amount >= amount, "Insufficient Ether balance");
        userBalance.amount = userBalance.amount.sub(amount);

        // Increase to the issuance balance
        Balance.Data storage issuanceBalance = getIssuanceEtherBalance(issuanceId);
        issuanceBalance.amount = issuanceBalance.amount.add(amount);
    }

    /**
     * @dev Transfer Ethers from an issuance to a seller/buyer
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param amount The amount of Ether to transfer
     */
    function transferFromIssuance(address payee, uint256 issuanceId, uint256 amount) public onlyWhitelistAdmin {
        // Subtract from the issuance balance
        Balance.Data storage issuanceBalance = getIssuanceEtherBalance(issuanceId);
        require(issuanceBalance.amount >= amount, "Insufficient Ether balance");
        issuanceBalance.amount = issuanceBalance.amount.sub(amount);

        // Increase to the seller/buyer balance
        Balance.Data storage userBalance = getUserEtherBalance(payee);
        userBalance.amount = userBalance.amount.add(amount);
    }

    /**
     * @dev Get the IERC20 token balance of an issuance in the escrow
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to check balance
     * @return The IERC20 token balance of the issuance in the escrow
     */
    function tokenBalanceOfIssuance(uint256 issuanceId, IERC20 token) public view onlyWhitelistAdmin returns (uint256) {
        Balances.Data storage balances = _issuanceBalances[issuanceId];
        for (uint i = 0; i < balances.entries.length; i++) {
            if (balances.entries[i].tokenAddress == address(token)) {
                return balances.entries[i].amount;
            }
        }
        return 0;
    }

    /**
     * @dev Transfer IERC20 token from a seller/buyer to the issuance
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to transfer
     * @param amount The amount of IERC20 token to transfer
     */
    function transferTokenToIssuance(address payee, uint256 issuanceId, IERC20 token, uint256 amount) public onlyWhitelistAdmin {
        // Subtract from the seller/buyer balance
        Balance.Data storage userBalance = getUserTokenBalance(payee, address(token));
        require(userBalance.amount >= amount, "Inssufficient token balance");
        userBalance.amount = userBalance.amount.sub(amount);

        // Increase to the issuance balance
        Balance.Data storage issuanceBalance = getIssuanceTokenBalance(issuanceId, address(token));
        issuanceBalance.amount = issuanceBalance.amount.add(amount);
    }

    /**
     * @dev Transfer IERC20 token from the issuance to a seller/buyer
     * @param payee The address of the seller/buyer
     * @param issuanceId The id of the issuance
     * @param token The IERC20 token to transfer
     * @param amount The amount of IERC20 token to transfer
     */
    function transferTokenFromIssuance(address payee, uint256 issuanceId, IERC20 token, uint256 amount) public onlyWhitelistAdmin {
        // Subtract from the issuance balance
        Balance.Data storage issuanceBalance = getIssuanceTokenBalance(issuanceId, address(token));
        require(issuanceBalance.amount >= amount, "Insufficient token balance");
        issuanceBalance.amount = issuanceBalance.amount.sub(amount);

        // Increase to the seller/buyer balance
        Balance.Data storage userBalance = getUserTokenBalance(payee, address(token));
        userBalance.amount = userBalance.amount.add(amount);
    }

    /**
     * @dev Get the balance information about all tokens of the issuance.
     * @param issuanceId The issuance id
     * @return The balance of all tokens about this issuance.
     */
    function getIssuanceBalances(uint256 issuanceId) public view onlyWhitelistAdmin returns (bytes memory) {
        return Balances.encode(_issuanceBalances[issuanceId]);
    }

    /**
     * @dev Migrate the balances of one issuance to another
     * Note: The balances should not have duplicate entries for the same token.
     * @param oldIssuanceId The id of the issuance from where the balance is migrated
     * @param newIssuanceId The id of the issuance to where the balance is migrated
     */
    function migrateIssuanceBalances(uint256 oldIssuanceId, uint256 newIssuanceId) public onlyWhitelistAdmin {
      Balances.Data storage oldBalances = _issuanceBalances[oldIssuanceId];
      Balances.Data storage newBalances = _issuanceBalances[newIssuanceId];

      // For each token in the old issuance
      for (uint i = 0; i < oldBalances.entries.length; i++) {
        bool found = false;
        // Check the token in the new balance
        for (uint j = 0; j < newBalances.entries.length; j++) {
          if ((oldBalances.entries[i].isEther && newBalances.entries[j].isEther)
            || (!oldBalances.entries[i].isEther && !newBalances.entries[j].isEther && oldBalances.entries[i].tokenAddress == newBalances.entries[j].tokenAddress)) {
              found = true;
              newBalances.entries[j].amount = newBalances.entries[j].amount.add(oldBalances.entries[i].amount);
              break;
            }
        }
        if (!found) {
          newBalances.entries.push(oldBalances.entries[i]);
        }
      }
    }

    function getUserEtherBalance(address payee) private returns (Balance.Data storage) {
      Balances.Data storage balances = _userBalances[payee];
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].isEther) {
          return balances.entries[i];
        }
      }
      Balance.Data memory newBalance = Balance.Data(true, address(0x0), 0);
      balances.entries.push(newBalance);
      return balances.entries[balances.entries.length - 1];
    }

    function getUserTokenBalance(address payee, address tokenAddress) private returns (Balance.Data storage balance) {
      Balances.Data storage balances = _userBalances[payee];
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].tokenAddress == tokenAddress) {
          balance = balances.entries[i];
          return balance;
        }
      }
      Balance.Data memory newBalance = Balance.Data(false, tokenAddress, 0);
      balances.entries.push(newBalance);
      return balances.entries[balances.entries.length - 1];
    }

    function getIssuanceEtherBalance(uint256 issuanceId) private returns (Balance.Data storage) {
      Balances.Data storage balances = _issuanceBalances[issuanceId];
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].isEther) {
          return balances.entries[i];
        }
      }
      Balance.Data memory newBalance = Balance.Data(true, address(0x0), 0);
      balances.entries.push(newBalance);
      return balances.entries[balances.entries.length - 1];
    }

    function getIssuanceTokenBalance(uint256 issuanceId, address tokenAddress) private returns (Balance.Data storage balance) {
      Balances.Data storage balances = _issuanceBalances[issuanceId];
      for (uint i = 0; i < balances.entries.length; i++) {
        if (balances.entries[i].tokenAddress == tokenAddress) {
          balance = balances.entries[i];
          return balance;
        }
      }
      Balance.Data memory newBalance = Balance.Data(false, tokenAddress, 0);
      balances.entries.push(newBalance);
      return balances.entries[balances.entries.length - 1];
    }
}
