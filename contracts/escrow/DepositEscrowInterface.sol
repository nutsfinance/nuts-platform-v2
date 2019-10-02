pragma solidity ^0.5.0;

import "./InstrumentEscrowInterface.sol";

/**
 * @title Escrow to hold the deposited NUTS token.
 * Deposit Escrow is similar to Instrument Escrow except that:
 * 1. Deposit Escrow is owned by Instrument Registry instead of Instrument Manager;
 * 2. Deposit Escrow is used to hold NUTS token.
 */
contract DepositEscrowInterface is InstrumentEscrowInterface {
}