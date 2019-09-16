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
    // Address of proxy admin
    // Note: Updateable after initialization.
    address public proxyAdminAddress;
    // Address of Timer Oracle
    // Note: Non-updatable after initialization.
    address public timerOracleAddress;

    constructor(uint256 newInstrumentDeposit, uint256 newIssuanceDeposit, address newDepositEscrowAddress,
        address newDepositTokenAddress, address newProxyAdminAddress, address newTimerOracleAddress) internal {
        instrumentDeposit = newInstrumentDeposit;
        issuanceDeposit = newIssuanceDeposit;
        depositEscrowAddress = newDepositEscrowAddress;
        depositTokenAddress = newDepositTokenAddress;
        proxyAdminAddress = newProxyAdminAddress;
        timerOracleAddress = newTimerOracleAddress;
    }

    function _setInstrumentDeposit(uint256 newInstrumentDeposit) internal {
        instrumentDeposit = newInstrumentDeposit;
    }

    function _setIssuanceDeposit(uint256 newIssuanceDeposit) internal {
        issuanceDeposit = newIssuanceDeposit;
    }

    function _setProxyAdminAddress(address newProxyAdminAddress) internal {
        proxyAdminAddress = newProxyAdminAddress;
    }
}