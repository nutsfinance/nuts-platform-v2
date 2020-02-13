pragma solidity 0.5.16;

import "../lib/util/Constants.sol";
import "./EscrowBase.sol";
import "./IssuanceEscrowInterface.sol";

/**
 * @title Issuance Escrow that keeps assets that are locked by issuance.
 */
contract IssuanceEscrow is EscrowBase, IssuanceEscrowInterface {

    /**
     * @dev Transfers the ownership of ETH in this escrow.
     * @param source The account where the tokens are from.
     * @param dest The account where the tokens are transferred to.
     * @param amount The amount to trasfer.
     */
    function transfer(address source, address dest, uint256 amount) public onlyOwner {
        transferToken(source, dest, Constants.getEthAddress(), amount);
    }

    /**
     * @dev Transfers the ownership of ERC20 tokens in this escrow.
     * @param source The account where the ERC20 tokens are from.
     * @param dest The account where the ERC20 tokens are transferred to.
     * @param token The ERC20 tokens to transfer.
     * @param amount The amount to trasfer.
     */
    function transferToken(address source, address dest, address token, uint256 amount) public onlyOwner {
        require(source != address(0x0), "IssuanceEscrow: Source must be set.");
        require(dest != address(0x0), "IssuanceEscrow: Dest must be set.");
        require(token != address(0x0), "IssuanceEscrow: Token must be set.");
        require(amount > 0, "IssuanceEscrow: Amount must be set.");
        require(getTokenBalance(source, token) >= amount, "IssuanceEscrow: Insufficient balance.");

        _migrateBalance(source, dest, token, amount);
    }
}
