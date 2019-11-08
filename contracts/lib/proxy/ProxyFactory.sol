pragma solidity ^0.5.0;

import "./ProxyFactoryInterface.sol";
import "./AdminOnlyUpgradeabilityProxy.sol";
import "./AdminUpgradeabilityProxy.sol";

contract ProxyFactory is ProxyFactoryInterface {

    /**
     * @dev Create new admin upgradeability proxy.
     */
    function createAdminUpgradeabilityProxy(address implementationAddress, address proxyAdminAddress)
        public returns (address) {
        
        AdminUpgradeabilityProxy proxy = new AdminUpgradeabilityProxy(implementationAddress, proxyAdminAddress);
        return address(proxy);
    }

    /**
     * @dev Create new admin only upgradeability proxy.
     */
    function createAdminOnlyUpgradeabilityProxy(address implementationAddress, address proxyAdminAddress)
        public returns (address) {

        AdminOnlyUpgradeabilityProxy proxy = new AdminOnlyUpgradeabilityProxy(implementationAddress, proxyAdminAddress);
        return address(proxy);
    }
}