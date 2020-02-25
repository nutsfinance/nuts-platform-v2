pragma solidity 0.5.16;

import "../protobuf/InstrumentData.sol";
import "../protobuf/LendingData.sol";
import "../protobuf/BorrowingData.sol";
import "../protobuf/SwapData.sol";

/**
 * @dev A util contract to generate custom parameters.
 */
contract ParametersUtil {
    /**
     * @dev Get serialized instrument parameters defined in protocol buf.
     */
    function getInstrumentParameters(
        uint256 instrumentTerminationTimestamp,
        uint256 instrumentOverrideTimestamp,
        address brokerAddress,
        bool supportMakerWhitelist,
        bool supportTakerWhitelist
    ) public pure returns (bytes memory) {
        InstrumentParameters.Data memory instrumentParameters = InstrumentParameters
            .Data(
            instrumentTerminationTimestamp,
            instrumentOverrideTimestamp,
            brokerAddress,
            supportMakerWhitelist,
            supportTakerWhitelist
        );
        return InstrumentParameters.encode(instrumentParameters);
    }

    /**
     * @dev Get serialized lending maker parameters defined in protocol buf.
     */
    function getLendingMakerParameters(
        address collateralTokenAddress,
        address lendingTokenAddress,
        uint256 lendingAmount,
        uint32 collateralRatio,
        uint32 tenorDays,
        uint32 interestRate
    ) public pure returns (bytes memory) {
        LendingMakerParameters.Data memory lendingMakerParamaters = LendingMakerParameters
            .Data(
            collateralTokenAddress,
            lendingTokenAddress,
            lendingAmount,
            collateralRatio,
            tenorDays,
            interestRate
        );
        return LendingMakerParameters.encode(lendingMakerParamaters);
    }

    /**
     * @dev Get serialized borrowing maker parameters defined in protocol buf.
     */
    function getBorrowingMakerParameters(
        address collateralTokenAddress,
        address borrowingTokenAddress,
        uint256 borrowingAmount,
        uint32 collateralRatio,
        uint32 tenorDays,
        uint32 interestRate
    ) public pure returns (bytes memory) {
        BorrowingMakerParameters.Data memory borrowingMakerParamaters = BorrowingMakerParameters
            .Data(
            collateralTokenAddress,
            borrowingTokenAddress,
            borrowingAmount,
            collateralRatio,
            tenorDays,
            interestRate
        );
        return BorrowingMakerParameters.encode(borrowingMakerParamaters);
    }

    /**
     * @dev Get serialized spot swap maker parameters defined in protocol buf.
     */
    function getSpotSwapMakerParameters(
        address inputTokenAddress,
        address outputTokenAddress,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 duration
    ) public pure returns (bytes memory) {
        SpotSwapMakerParameters.Data memory spotSwapMakerParameters = SpotSwapMakerParameters
            .Data(
            inputTokenAddress,
            outputTokenAddress,
            inputAmount,
            outputAmount,
            duration
        );
        return SpotSwapMakerParameters.encode(spotSwapMakerParameters);
    }
}
