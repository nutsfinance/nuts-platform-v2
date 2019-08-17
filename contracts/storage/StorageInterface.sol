pragma solidity ^0.5.0;

/**
 * @title Interface for generic data storage contract.
 * Supported values include: String, address, int, uint, bool.
 * Complex types should look for serialization/deserialization frameworks.
 */
interface StorageInterface {
    function addWriter(address account) external;

    function removeWriter(address account) external;

    function getString(string calldata key) external view returns (string memory);

    function setString(string calldata key, string calldata value) external;

    function getBytes(string calldata key) external view returns (bytes memory);

    function setBytes(string calldata key, bytes calldata value) external;

    function getAddress(string calldata key) external view returns (address);

    function setAddress(string calldata key, address value) external;

    function getUint(string calldata key) external view returns (uint);

    function setUint(string calldata key, uint value) external;

    function getInt(string calldata key) external view returns (int);

    function setInt(string calldata key, int value) external;

    function getBool(string calldata key) external view returns (bool);

    function setBool(string calldata key, bool value) external;
}
