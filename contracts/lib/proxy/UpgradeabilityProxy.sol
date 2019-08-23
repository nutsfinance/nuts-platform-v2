pragma solidity ^0.5.0;

import "./OwnedUpgradeabilityStorage.sol";

/**
 * @title UpgradeabilityProxy
 * @dev Gives the possibility to delegate any call to a foreign implementation.
 */
contract UpgradeabilityProxy is OwnedUpgradeabilityStorage {

  /**
  * @dev Fallback function allowing to perform a delegatecall to the given implementation.
  * This function will return whatever the implementation call returns
  */
  function () external payable {
    address _impl = implementation();
    require(_impl != address(0), "UpgradeabilityProxy: Implementation not set.");

    assembly {
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize)
      let result := delegatecall(gas, _impl, ptr, calldatasize, 0, 0)
      let size := returndatasize
      returndatacopy(ptr, 0, size)

      switch result
      case 0 { revert(ptr, size) }
      default { return(ptr, size) }
    }
  }
}
