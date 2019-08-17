pragma solidity ^0.5.0;

import "../lib/access/WhitelistAdminRole.sol";
import "./StorageFactoryInterface.sol";
import "./StorageInterface.sol";
import "./UnifiedStorage.sol";

/**
 * @title Factory for storage contracts.
 */
contract StorageFactory is WhitelistAdminRole {
    function createNewStorage() external onlyWhitelistAdmin returns (StorageInterface) {
        return new UnifiedStorage();
    }
}