pragma solidity ^0.5.0;

import "../lib/proxy/AdminUpgradeabilityProxy.sol";
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

    // All Instrument Escrows and Issuance Escrows share the same implementation.
    InstrumentEscrow private _instrumentEscrow;
    IssuanceEscrow private _issuanceEscrow;

    constructor() public {
        _instrumentEscrow = new InstrumentEscrow();
        _issuanceEscrow = new IssuanceEscrow();
    }

    /**
     * @dev Create new Deposit Escrow instance.
     * Deposit Escrow has the same implementation as Instrument Escrow, but uses a
     * different contract name to better distinguish their difference.
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Deposit Escrow.
     */
    function createDepositEscrow(address proxyAdmin, address owner) external returns (DepositEscrowInterface) {
        // Deposit Escrow uses Instrument Escrow's implementation.
        AdminUpgradeabilityProxy depositEscrowProxy = new AdminUpgradeabilityProxy(address(_instrumentEscrow),
            proxyAdmin, new bytes(0));
        // The owner of Instrument Escrow is Instrument Manager
        DepositEscrowInterface depositEscrow = DepositEscrowInterface(address(depositEscrowProxy));
        depositEscrow.initialize(owner);

        return depositEscrow;
    }

    /**
     * @dev Create new Instrument Escrow instance.
     * Note that all Instrument Escrows share the same implementation with data stored in proxy contract.
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Instrument Escrow.
     */
    function createInstrumentEscrow(address proxyAdmin, address owner) public returns (InstrumentEscrowInterface) {
        AdminUpgradeabilityProxy instrumentEscrowProxy = new AdminUpgradeabilityProxy(address(_instrumentEscrow),
            proxyAdmin, new bytes(0));
        // The owner of Instrument Escrow is Instrument Manager
        InstrumentEscrowInterface instrumentEscrow = InstrumentEscrow(address(instrumentEscrowProxy));
        instrumentEscrow.initialize(owner);

        return instrumentEscrow;
    }

    /**
     * @dev Creates new Issuance Escrow intance.
     * Note that all Issuance Escrows share the same implementation with data stored in proxy contract.
     * @param proxyAdmin Admin of the proxy contract. Only proxy admin can change implementation.
     * @param owner Owner of the Issuance Escrow.
     */
    function createIssuanceEscrow(address proxyAdmin, address owner) public returns (IssuanceEscrowInterface) {
        AdminUpgradeabilityProxy issuanceEscrowProxy = new AdminUpgradeabilityProxy(address(_issuanceEscrow),
            proxyAdmin, new bytes(0));
        // The owner of Instrument Escrow is Instrument Manager
        IssuanceEscrowInterface issuanceEscrow = IssuanceEscrowInterface(address(issuanceEscrowProxy));
        issuanceEscrow.initialize(owner);

        return issuanceEscrow;
    }
}