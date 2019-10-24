pragma solidity ^0.5.0;

import "./StorageInterface.sol";
import "../access/WriterRole.sol";

/**
 * @title A generic data storage contract.
 * Supported values include: string, bytes, address, int, uint, bool.
 * Complex types should look for serialization/deserialization frameworks.
 * Any account have read access to the storage, but only writer can write to it.
 */
contract UnifiedStorage is StorageInterface, WriterRole {
    mapping(bytes32 => string) private _stringData;
    mapping(bytes32 => address) private _addressData;
    mapping(bytes32 => uint) private _uintData;
    mapping(bytes32 => int) private _intData;
    mapping(bytes32 => bool) private _boolData;

    function getString(bytes32 key) public view returns (string memory) {
        return _stringData[key];
    }

    function setString(bytes32 key, string memory value) public onlyWriter {
       _stringData[key] = value;
    }

    function getAddress(bytes32 key) public view returns (address) {
        return _addressData[key];
    }

    function setAddress(bytes32 key, address value) public onlyWriter {
       _addressData[key] = value;
    }

    function getUint(bytes32 key) public view returns (uint) {
        return _uintData[key];
    }

    function setUint(bytes32 key, uint value) public onlyWriter {
       _uintData[key] = value;
    }

    function getInt(bytes32 key) public view returns (int) {
        return _intData[key];
    }

    function setInt(bytes32 key, int value) public onlyWriter {
       _intData[key] = value;
    }

    function getBool(bytes32 key) public view returns (bool) {
        return _boolData[key];
    }

    function setBool(bytes32 key, bool value) public onlyWriter {
       _boolData[key] = value;
    }
}
