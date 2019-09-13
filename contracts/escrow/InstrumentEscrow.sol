pragma solidity ^0.5.0;

import "../lib/token/IERC20.sol";
import "../lib/token/SafeERC20.sol";
import "../lib/util/Constants.sol";
import "./EscrowBase.sol";
import "./InstrumentEscrowInterface.sol";

/**
 * @title Instrument Escrow that keeps assets that are not yet locked by issuances.
 */
contract InstrumentEscrow is EscrowBase, InstrumentEscrowInterface {
    /**
     * ETH is deposited into instrument escrow.
     * @param depositer The address who deposits ETH.
     * @param amount The deposit token amount.
     */
    event Deposited(address indexed depositer, uint256 amount);

    /**
     * ETH is withdrawn from instrument escrow.
     * @param withdrawer The address who withdraws ETH.
     * @param amount The withdrawal token amount.
     */
    event Withdrawn(address indexed withdrawer, uint256 amount);

    /**
     * Token is deposited into instrument escrow.
     * @param depositer The address who deposits token.
     * @param token The deposit token address.
     * @param amount The deposit token amount.
     */
    event TokenDeposited(address indexed depositer, address indexed token, uint256 amount);

    /**
     * Token is withdrawn from instrument escrow.
     * @param withdrawer The address who withdraws token.
     * @param token The withdrawal token address.
     * @param amount The withdrawal token amount.
     */
    event TokenWithdrawn(address indexed withdrawer, address indexed token, uint256 amount);

    /**********************************************
     * APIs to deposit and withdraw Ether
     ***********************************************/

    /**
     * @dev Deposits ETHs into the instrument escrow
     */
    function deposit() public payable {
        address account = msg.sender;
        uint256 amount = msg.value;
        _addToBalance(account, Constants.getEthAddress(), amount);

        emit Deposited(account, amount);
    }

    /**
     * @dev Withdraw Ethers from the instrument escrow
     * @param amount The amount of Ethers to withdraw
     */
    function withdraw(uint256 amount) public {
        address payable account = msg.sender;
        require(getBalance(account) >= amount, "InstrumentEscrow: Insufficient balance.");
        _reduceFromBalance(account, Constants.getEthAddress(), amount);

        account.transfer(amount);

        emit Withdrawn(account, amount);
    }

    /***********************************************
     *  APIs to deposit and withdraw IERC20 token
     **********************************************/

    /**
     * @dev Deposit IERC20 token to the instrument escrow.
     * @param token The IERC20 token to deposit.
     * @param amount The amount to deposit.
     */
    function depositToken(IERC20 token, uint256 amount) public {
        address account = msg.sender;
        _addToBalance(account, address(token), amount);

        token.safeTransferFrom(account, address(this), amount);

        emit TokenDeposited(account, address(token), amount);
    }

    /**
     * @dev Withdraw IERC20 token from the instrument escrow.
     * @param token The IERC20 token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdrawToken(IERC20 token, uint256 amount) public {
        address account = msg.sender;
        require(getTokenBalance(account, token) >= amount, "InstrumentEscrow: Insufficient balance.");
        _reduceFromBalance(account, address(token), amount);

        token.safeTransfer(account, amount);

        emit TokenWithdrawn(account, address(token), amount);
    }
}
