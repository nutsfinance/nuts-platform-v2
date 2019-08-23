pragma solidity ^0.5.0;

import "../lib/access/Roles.sol";
import "../lib/access/Ownable.sol";

/**
 * @dev Defines the writer role. Only the owner can grant the writer role.
 * The writer can renounce their own writer role.
 */
contract WriterRole is Ownable {
    using Roles for Roles.Role;

    event WriterAdded(address indexed account);
    event WriterRemoved(address indexed account);

    Roles.Role private _writers;

    modifier onlyWriter() {
        require(isWriter(msg.sender), "WriterRole: Caller does not have the Writer role");
        _;
    }

    function isWriter(address account) public view returns (bool) {
        return _writers.has(account);
    }

    function addWriter(address account) public onlyOwner {
        _addWriter(account);
    }

    function removeWriter(address account) public onlyOwner {
        _removeWriter(account);
    }

    function renounceWriter() public {
        _removeWriter(msg.sender);
    }

    function _addWriter(address account) internal {
        _writers.add(account);
        emit WriterAdded(account);
    }

    function _removeWriter(address account) internal {
        _writers.remove(account);
        emit WriterAdded(account);
    }
}