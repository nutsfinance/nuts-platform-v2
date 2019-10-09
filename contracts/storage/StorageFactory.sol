pragma solidity ^0.5.0;

import "./StorageInterface.sol";
import "./UnifiedStorage.sol";
import "./StorageFactoryInterface.sol";

/**
 * @title Factory for storage instances.
 */
contract StorageFactory is StorageFactoryInterface {

    /**
     * @dev Create new storage instance.
     */
    function createStorageInstance() public returns (StorageInterface) {
        return new UnifiedStorage();
    }
}