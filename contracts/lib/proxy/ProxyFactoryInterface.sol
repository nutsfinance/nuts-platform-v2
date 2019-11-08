pragma solidity ^0.5.0;

contract ProxyFactoryInterface {

    /**
     * @dev Create new admin upgradeability proxy.
     */
    function createAdminUpgradeabilityProxy(address proxyAdminAdress, address implementationAddress)
        external returns (address);

    /**
     * @dev Create new admin only upgradeability proxy.
     */
    function createAdminOnlyUpgradeabilityProxy(address proxyAdminAdress, address implementationAddress)
        external returns (address);
}