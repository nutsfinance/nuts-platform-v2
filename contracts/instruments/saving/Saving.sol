pragma solidity ^0.5.0;

import "../../instrument/v1/InstrumentV1.sol";

contract Saving is InstrumentV1 {
    /**
     * @dev Create a new issuance of the financial instrument
     */
    function createIssuance(bytes memory, bytes memory) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Unsupported opeartion");
    }

    /**
     * @dev A taker engages to the issuance
     */
    function engageIssuance(bytes memory, bytes memory, bytes memory) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Unsupported opeartion");
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     */
    function processTokenDeposit(bytes memory, address, uint256, bytes memory) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Unsupported opeartion");
    }


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     */
    function processTokenWithdraw(bytes memory, address, uint256, bytes memory) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Unsupported opeartion");
    }

    /**
     * @dev A custom event is triggered.
     */
    function processCustomEvent(bytes memory, bytes32, bytes memory, bytes memory) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Unsupported opeartion");
    }
}