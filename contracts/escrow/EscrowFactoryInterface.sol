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
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Deposit Escrow.
     */
    function createDepositEscrow(address proxyAdmin, address owner) external returns (DepositEscrowInterface);

    /**
     * @dev Create new Instrument Escrow instance.
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Instrument Escrow.
     */
    function createInstrumentEscrow(address proxyAdmin, address owner) external returns (InstrumentEscrowInterface);

    /**
     * @dev Creates new Issuance Escrow intance.
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Issuance Escrow.
     */
    function createIssuanceEscrow(address proxyAdmin, address owner) external returns (IssuanceEscrowInterface);
}