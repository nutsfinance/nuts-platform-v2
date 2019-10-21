pragma solidity ^0.5.0;

import "../protobuf/InstrumentData.sol";
import "../protobuf/LendingData.sol";

/**
 * @dev A util contract to generate custom parameters.
 */
contract ParametersUtil {

    /**
     * @dev Get serialized instrument parameters defined in protocol buf.
     */
    function getInstrumentParameters(uint256 expiration, address brokerAddress, bool supportMakerWhitelist,
        bool supportTakerWhitelist) public pure returns (bytes memory) {

        InstrumentParameters.Data memory instrumentParameters = InstrumentParameters.Data(expiration, brokerAddress,
            supportMakerWhitelist, supportTakerWhitelist);
        return InstrumentParameters.encode(instrumentParameters);
    }

    /**
     * @dev Get serialized lending maker parameters defined in protocol buf.
     */
    function getLendingMakerParameters(address collateralTokenAddress, address lendingTokenAddress, uint256 lendingAmount,
        uint32 collateralRatio, uint32 tenorDays, uint32 interestRate) public pure returns (bytes memory) {

        LendingMakerParameters.Data memory lendingMakerParamaters = LendingMakerParameters.Data(collateralTokenAddress,
            lendingTokenAddress, lendingAmount, collateralRatio, tenorDays, interestRate);
        return LendingMakerParameters.encode(lendingMakerParamaters);
    }
}