pragma solidity ^0.5.0;

import "./StorageInterface.sol";

/**
 * @dev Interface of storage factory.
 */
interface StorageFactoryInterface {

    /**
     * @dev Create new storage instance.
     */
    function createStorageInstance() external returns (StorageInterface);
}