pragma solidity ^0.5.0;

/**
 * @title Interface for generic data storage contract.
 * Supported values include: String, address, int, uint, bool.
 * Complex types should look for serialization/deserialization frameworks.
 */
interface StorageInterface {

    function addWriter(address account) external;

    function removeWriter(address account) external;

    function getString(bytes32 key) external view returns (string memory);

    function setString(bytes32 key, string calldata value) external;

    function getAddress(bytes32 key) external view returns (address);

    function setAddress(bytes32 key, address value) external;

    function getUint(bytes32 key) external view returns (uint);

    function setUint(bytes32 key, uint value) external;

    function getInt(bytes32 key) external view returns (int);

    function setInt(bytes32 key, int value) external;

    function getBool(bytes32 key) external view returns (bool);

    function setBool(bytes32 key, bool value) external;
}
