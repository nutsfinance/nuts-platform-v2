pragma solidity ^0.5.0;

import "./StorageInterface.sol";
import "./UnifiedStorage.sol";
import "./StorageFactoryInterface.sol";

contract StorageFactory is StorageFactoryInterface {
    function createStorageInstance() public returns (StorageInterface) {
        return new UnifiedStorage();
    }
}