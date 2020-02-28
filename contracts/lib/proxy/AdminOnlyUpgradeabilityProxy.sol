pragma solidity 0.5.16;

import "./BaseAdminUpgradeabilityProxy.sol";

/**
 * @title AdminOnlyUpgradeabilityProxy
 * @dev Extends from BaseAdminUpgradeabilityProxy with a constructor for
 * initializing the implementation, admin, and init data.
 *
 * The difference between AdminUpgradeabilityProxy and AdminOnlyUpgradeabilityProxy:
 * AdminUpgradeabilityProxy: Only fallback when the sender is not proxy admin.
 * AdminOnlyUpgradeabilityProxy: Only fallback when the sender is proxy admin.
 */
contract AdminOnlyUpgradeabilityProxy is
    BaseAdminUpgradeabilityProxy,
    UpgradeabilityProxy
{
    /**
    * Contract constructor.
    * @param _logic address of the initial implementation.
    * @param _admin Address of the proxy administrator.
    * It should include the signature and the parameters of the function to be called, as described in
    * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
    * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
    */
    constructor(address _logic, address _admin)
        public
        payable
        UpgradeabilityProxy(_logic)
    {
        assert(
            ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        );
        _setAdmin(_admin);
    }

    /**
    * @dev Only fall back when the sender is the admin.
    */
    function _willFallback() internal {
        require(msg.sender == _admin(), "Only admin can fallback");
        super._willFallback();
    }
}
