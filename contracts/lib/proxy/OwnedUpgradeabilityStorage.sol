pragma solidity ^0.5.0;

import "./OwnedStorage.sol";

/**
 * @title OwnedUpgradeabilityStorage
 * @dev This contract defines the storage to achieve both upgradeability and ownership.
 */
contract OwnedUpgradeabilityStorage is OwnedStorage {

  /**
   * @dev This event will be emitted every time the implementation gets upgraded
   * @param implementation representing the address of the upgraded implementation
   */
  event ImplementationUpgraded(address indexed implementation);

  // Storage position of the address of the current implementation
  bytes32 private constant implementationPosition = keccak256("finance.nuts.proxy.implementation");

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferProxyOwnership(address newOwner) public onlyProxyOwner {
    require(newOwner != address(0), "OwnedUpgradeabilityStorage: Not proxy owner");
    emit ProxyOwnershipTransferred(proxyOwner(), newOwner);
    setUpgradeabilityOwner(newOwner);
  }

  /**
   * @dev Tells the address of the current implementation
   * @return address of the current implementation
   */
  function implementation() public view returns (address impl) {
    bytes32 position = implementationPosition;
    assembly {
      impl := sload(position)
    }
  }

  /**
   * @dev Sets the address of the current implementation
   * @param newImplementation address representing the new implementation to be set
   */
  function setImplementation(address newImplementation) internal {
    bytes32 position = implementationPosition;
    assembly {
      sstore(position, newImplementation)
    }
  }

  /**
   * @dev Upgrades the implementation address
   * @param newImplementation representing the address of the new implementation to be set
   */
  function _upgradeTo(address newImplementation) internal {
    address currentImplementation = implementation();
    require(currentImplementation != newImplementation, "OwnedUpgradeabilityStorage: New implementation should be different.");
    setImplementation(newImplementation);
    emit ImplementationUpgraded(newImplementation);
  }

  /**
   * @dev Allows the proxy owner to upgrade the current version of the proxy.
   * @param newImplementation representing the address of the new implementation to be set.
   */
  function upgradeTo(address newImplementation) public onlyProxyOwner {
    _upgradeTo(newImplementation);
  }
}