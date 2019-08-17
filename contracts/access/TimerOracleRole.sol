pragma solidity ^0.5.0;

import "../lib/access/Roles.sol";

/**
 * @title Roles consumed by Timer Oracle.
 */
contract TimerOracleRole {
    using Roles for Roles.Role;

    event TimerOracleAdded(address indexed account);
    event TimerOracleRemoved(address indexed account);

    Roles.Role private _timerOracles;

    constructor () internal {
        _addTimerOracle(msg.sender);
    }

    modifier onlyTimerOracle() {
        require(isTimerOracle(msg.sender), "TimerOracleRole: caller does not have the TimerOracle role");
        _;
    }

    function isTimerOracle(address account) public view returns (bool) {
        return _timerOracles.has(account);
    }

    function addTimerOracle(address account) public onlyTimerOracle {
        _addTimerOracle(account);
    }

    function renounceTimerOracle() public {
        _removeTimerOracle(msg.sender);
    }

    function _addTimerOracle(address account) internal {
        _timerOracles.add(account);
        emit TimerOracleAdded(account);
    }

    function _removeTimerOracle(address account) internal {
        _timerOracles.remove(account);
        emit TimerOracleRemoved(account);
    }
}