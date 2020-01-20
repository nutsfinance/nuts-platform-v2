pragma solidity ^0.5.0;

import "./EscrowBaseInterface.sol";

/**
 * @dev Interface for Issuance Escrow.
 * Defines additional methods used by Instrument Manager.
 */
contract IssuanceEscrowInterface is EscrowBaseInterface {

    /**
     * @dev Transfers the ownership of ETH in this escrow.
     * @param source The account where the tokens are from.
     * @param dest The account where the tokens are transferred to.
     * @param amount The amount to trasfer.
     */
    function transfer(address source, address dest, uint256 amount) public;

    /**
     * @dev Transfers the ownership of ERC20 tokens in this escrow.
     * @param source The account where the ERC20 tokens are from.
     * @param dest The account where the ERC20 tokens are transferred to.
     * @param token The ERC20 tokens to transfer.
     * @param amount The amount to trasfer.
     */
    function transferToken(address source, address dest, address token, uint256 amount) public;
}
