pragma solidity ^0.5.0;

import "./DepositEscrowInterface.sol";
import "./InstrumentEscrowInterface.sol";
import "./IssuanceEscrowInterface.sol";

/**
 * @title Interface for Escrow Factory.
 * This is used to hide the implementation of Issuance Escrow and Instrument Escrow.
 */
interface EscrowFactoryInterface {

    /**
     * @dev Create new Deposit Escrow instance.
     */
    function createDepositEscrow() external returns (DepositEscrowInterface);

    /**
     * @dev Create new Instrument Escrow instance.
     */
    function createInstrumentEscrow() external returns (InstrumentEscrowInterface);

    /**
     * @dev Creates new Issuance Escrow intance.
     */
    function createIssuanceEscrow() external returns (IssuanceEscrowInterface);
}