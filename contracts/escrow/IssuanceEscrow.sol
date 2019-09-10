pragma solidity ^0.5.0;

import "../lib/token/IERC20.sol";
import "./EscrowBase.sol";

/**
 * @title Issuance Escrow that keeps assets that are locked by issuance.
 */
contract IssuanceEscrow is EscrowBase {

    /**
     * @dev Transfers the ownership of tokens in this escrow.
     * @param source The account where the tokens are from.
     * @param dest The account where the tokens are transferred to.
     * @param token The tokens to transfer.
     * @param amount The amount to trasfer.
     */
    function transferTokenOwnership(address source, address dest, address token, uint256 amount) public onlyOwner {
        require(source != address(0x0), "IssuanceEscrow: Source must be set.");
        require(dest != address(0x0), "IssuanceEscrow: Dest must be set.");
        require(token != address(0x0), "IssuanceEscrow: Token must be set.");
        require(amount > 0, "IssuanceEscrow: Amount must be set.");
        require(getTokenBalance(source, IERC20(token)) >= amount, "IssuanceEscrow: Insufficient balance.");

        _migrateBalance(source, dest, token, amount);
    }
}