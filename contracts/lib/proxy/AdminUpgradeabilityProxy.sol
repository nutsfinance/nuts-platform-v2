pragma solidity ^0.5.0;

import './BaseAdminUpgradeabilityProxy.sol';

/**
 * @title AdminUpgradeabilityProxy
 * @dev Extends from BaseAdminUpgradeabilityProxy with a constructor for
 * initializing the implementation, admin, and init data.
 *
 * Credit: https://github.com/OpenZeppelin/openzeppelin-sdk/blob/master/packages/lib/contracts/upgradeability/AdminUpgradeabilityProxy.sol
 */
contract AdminUpgradeabilityProxy is BaseAdminUpgradeabilityProxy, UpgradeabilityProxy {
    /**
    * Contract constructor.
    * @param _logic address of the initial implementation.
    * @param _admin Address of the proxy administrator.
    * It should include the signature and the parameters of the function to be called, as described in
    * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
    * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
    */
    constructor(address _logic, address _admin) UpgradeabilityProxy(_logic) public payable {
      assert(ADMIN_SLOT == bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1));
      _setAdmin(_admin);
    }

    /**
    * @dev Only fall back when the sender is not the admin.
    */
    function _willFallback() internal {
      require(msg.sender != _admin(), "Admin cannot fallback");
      super._willFallback();
    }
}
