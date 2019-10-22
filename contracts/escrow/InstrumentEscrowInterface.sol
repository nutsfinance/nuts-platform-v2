pragma solidity ^0.5.0;

import "./EscrowBaseInterface.sol";

/**
 * @title Interface for instrument escrow. This is the interface with
 * which external users interact with Instrument Escrow.
 * Abstract contract is used instead of interface as interface does not support inheritance.
 */
contract InstrumentEscrowInterface is EscrowBaseInterface {

    /**********************************************
     * APIs to deposit and withdraw Ether
     ***********************************************/

    /**
     * @dev Deposits ETHs into the instrument escrow
     */
    function deposit() public payable;

    /**
     * @dev Withdraw Ethers from the instrument escrow
     * @param amount The amount of Ethers to withdraw
     */
    function withdraw(uint256 amount) public;

    /***********************************************
     *  APIs to deposit and withdraw IERC20 token
     **********************************************/

    /**
     * @dev Deposit IERC20 token to the instrument escrow.
     * @param token The IERC20 token to deposit.
     * @param amount The amount to deposit.
     */
    function depositToken(address token, uint256 amount) public;

    /**
     * @dev Withdraw IERC20 token from the instrument escrow.
     * @param token The IERC20 token to withdraw.
     * @param amount The amount to withdraw.
     */
    function withdrawToken(address token, uint256 amount) public;

}
