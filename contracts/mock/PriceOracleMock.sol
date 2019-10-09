pragma solidity ^0.5.0;

import "../lib/priceoracle/PriceOracleInterface.sol";

contract PriceOracleMock is PriceOracleInterface {

    struct Rate {
        uint256 numerator;
        uint256 denominator;
    }

    mapping(address => mapping(address => Rate)) private _rates;


    function getRate(address baseTokenAddress, address quoteTokenAddress) public view
        returns (uint256 numerator, uint256 denominator) {

        if (baseTokenAddress == quoteTokenAddress)  return (1, 1);
        Rate storage rate = _rates[baseTokenAddress][quoteTokenAddress];
        return (rate.numerator, rate.denominator);
    }

    function setRate(address baseTokenAddress, address quoteTokenAddress, uint256 numerator, uint256 denominator) public {
        _rates[baseTokenAddress][quoteTokenAddress].numerator = numerator;
        _rates[baseTokenAddress][quoteTokenAddress].denominator = denominator;
    }
}