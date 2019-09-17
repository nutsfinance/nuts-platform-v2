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
    mapping(string => string) private _stringData;
    mapping(string => address) private _addressData;
    mapping(string => uint) private _uintData;
    mapping(string => int) private _intData;
    mapping(string => bool) private _boolData;

    function getString(string memory key) public view returns (string memory) {
        return _stringData[key];
    }

    function setString(string memory key, string memory value) public onlyWriter {
       _stringData[key] = value;
    }

    function getBytes(string memory key) public view returns (bytes memory) {
        return bytes(_stringData[key]);
    }

    function setBytes(string memory key, bytes memory value) public {
        _stringData[key] = string(value);
    }

    function getAddress(string memory key) public view returns (address) {
        return _addressData[key];
    }

    function setAddress(string memory key, address value) public onlyWriter {
       _addressData[key] = value;
    }

    function getUint(string memory key) public view returns (uint) {
        return _uintData[key];
    }

    function setUint(string memory key, uint value) public onlyWriter {
       _uintData[key] = value;
    }

    function getInt(string memory key) public view returns (int) {
        return _intData[key];
    }

    function setInt(string memory key, int value) public onlyWriter {
       _intData[key] = value;
    }

    function getBool(string memory key) public view returns (bool) {
        return _boolData[key];
    }

    function setBool(string memory key, bool value) public onlyWriter {
       _boolData[key] = value;
    }
}
