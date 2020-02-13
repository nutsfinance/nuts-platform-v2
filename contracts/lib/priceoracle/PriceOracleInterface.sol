pragma solidity 0.5.16;

interface PriceOracleInterface {

    /**
     * @dev Get the exchange rate between two tokens.
     * @param baseTokenAddress The address of base ERC20 token. ETH has a special address defined in Constants.getEthAddress()
     * @param quoteTokenAddress The address of quote ERC20 token. ETH has a special address defined in Constants.getEthAddress()
     * @return The rate expressed as numerator/denominator.
     */
    function getRate(address baseTokenAddress, address quoteTokenAddress) external view
        returns (uint256 numerator, uint256 denominator);
}
