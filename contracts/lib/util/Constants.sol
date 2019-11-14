pragma solidity ^0.5.0;

library Constants {

    /**
     * @dev Defines a special address to represent ETH.
     */
    function getEthAddress() internal pure returns (address) {
        return address(-1);
    }

    /**
     * @dev Defines a special address to represent custodian.
     */
    function getCustodianAddress() internal pure returns (address) {
        // address(bytes20(keccak256('nuts.finance.custodian')))
        return 0xDbE7A2544eeFfec81A7D898Ac08075e0D56FEac6;
    }

}