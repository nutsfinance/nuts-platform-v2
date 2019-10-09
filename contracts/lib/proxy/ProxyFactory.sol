pragma solidity ^0.5.0;

import "./ProxyFactoryInterface.sol";
import "./AdminUpgradeabilityProxy.sol";
import "./AdminOnlyUpgradeabilityProxy.sol";

/**
 * @title Factory of proxies.
 */
contract ProxyFactory is ProxyFactoryInterface {
    /**
     * @dev Create a new Admin Upgradeability Proxy.
     * @param proxyAdminAddress The address of the proxy admin.
     * @param implementationAddress The address of the implementation.
     */
    function createAdminUpgradeabilityProxy(address proxyAdminAddress, address implementationAddress)
        public returns (address) {
        return address(new AdminUpgradeabilityProxy(implementationAddress, proxyAdminAddress, new bytes(0)));
    }

    /**
     * @dev Create a new Admin Upgradeability Proxy.
     * @param proxyAdminAddress The address of the proxy admin.
     * @param implementationAddress The address of the implementation.
     */
    function createAdminOnlyUpgradeabilityProxy(address proxyAdminAddress, address implementationAddress)
        public returns (address) {
        
        return address(new AdminOnlyUpgradeabilityProxy(implementationAddress, proxyAdminAddress, new bytes(0)));
    }
}