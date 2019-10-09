pragma solidity ^0.5.0;

/**
 * @title Interface for proxy factory.
 */
interface ProxyFactoryInterface {

    /**
     * @dev Create a new Admin Upgradeability Proxy.
     * @param proxyAdminAddress The address of the proxy admin.
     * @param implementationAddress The address of the implementation.
     */
    function createAdminUpgradeabilityProxy(address proxyAdminAddress, address implementationAddress)
        external returns (address);

    /**
     * @dev Create a new Admin Upgradeability Proxy.
     * @param proxyAdminAddress The address of the proxy admin.
     * @param implementationAddress The address of the implementation.
     */
    function createAdminOnlyUpgradeabilityProxy(address proxyAdminAddress, address implementationAddress)
        external returns (address);
}