pragma solidity ^0.5.0;

/**
 * @title Base contract to hold instrument-related config.
 */
contract InstrumentConfig {
    // Amount of NUTS token deposited to activate new financial instrument
    // Note: Updateable after initialization.
    uint256 public instrumentDeposit;
    // Amount of NUTS token deposited to create new issuance
    // Note: Updateable after initialization.
    uint256 public issuanceDeposit;
    // Address of Deposit Escrow
    // Note: Non-updateable after initialization.
    address public depositEscrowAddress;
    // Address of deposited token(NUTS token)
    // Note: Non-updateable after initialization.
    address public depositTokenAddress;
    // Address of Price Oracle
    // Note: Non-updatable after initialization.
    address public priceOracleAddress;
    // Address of Escrow Factory
    // Note: Updatable after initialization.
    address public escrowFactoryAddress;
    // Address of Proxy Factory
    // Note: Updatable after initialization.
    address public proxyFactoryAddress;

}