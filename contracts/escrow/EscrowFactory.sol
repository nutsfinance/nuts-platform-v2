pragma solidity 0.5.16;

import "./EscrowFactoryInterface.sol";
import "./IssuanceEscrow.sol";
import "./IssuanceEscrowInterface.sol";
import "./InstrumentEscrow.sol";
import "./InstrumentEscrowInterface.sol";

/**
 * @title Escrow Factory. This should be a singleton in NUTS Platform.
 */
contract EscrowFactory is EscrowFactoryInterface {

    /**
     * @dev Create new Instrument Escrow instance.
     */
    function createInstrumentEscrow() public returns (InstrumentEscrowInterface) {
        InstrumentEscrow instrumentEscrow = new InstrumentEscrow();
        instrumentEscrow.transferOwnership(msg.sender);

        return instrumentEscrow;
    }

    /**
     * @dev Creates new Issuance Escrow intance.
     */
    function createIssuanceEscrow() public returns (IssuanceEscrowInterface) {
        IssuanceEscrow issuanceEscrow = new IssuanceEscrow();
        issuanceEscrow.transferOwnership(msg.sender);

        return issuanceEscrow;
    }
}
