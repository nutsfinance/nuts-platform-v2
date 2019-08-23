pragma solidity ^0.5.0;

library Constants {

    /**
     * @dev Defines a special address to represent ETH.
     */
    function getEthAddress() internal pure returns (address) {
        return address(-1);
    }

}