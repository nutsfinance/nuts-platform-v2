pragma solidity ^0.5.0;

import "../lib/priceoracle/PriceOracleInterface.sol";

contract PriceOracleMock is PriceOracleInterface {
    function getRate(address baseTokenAddress, address quoteTokenAddress) external
        returns (uint256 numerator, uint256 denominator) {
        if (baseTokenAddress == quoteTokenAddress)  return (1, 1);
        return (2, 100);
    }
}