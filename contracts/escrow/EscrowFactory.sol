pragma solidity ^0.5.0;

import "./EscrowFactoryInterface.sol";
import "./IssuanceEscrow.sol";
import "./IssuanceEscrowInterface.sol";
import "./InstrumentEscrow.sol";
import "./InstrumentEscrowInterface.sol";
import "./DepositEscrowInterface.sol";

/**
 * @title Escrow Factory. This should be a singleton in NUTS Platform.
 */
contract EscrowFactory is EscrowFactoryInterface {

    /**
     * @dev Create new Deposit Escrow instance.
     * Deposit Escrow has the same implementation as Instrument Escrow, but uses a
     * different contract name to better distinguish their difference.
     */
    function createDepositEscrow() external returns (DepositEscrowInterface) {
        return new InstrumentEscrow();
    }

    /**
     * @dev Create new Instrument Escrow instance.
     */
    function createInstrumentEscrow() public returns (InstrumentEscrowInterface) {
        return new InstrumentEscrow();
    }

    /**
     * @dev Creates new Issuance Escrow intance.
     */
    function createIssuanceEscrow() public returns (IssuanceEscrowInterface) {
        return new IssuanceEscrow();
    }
}