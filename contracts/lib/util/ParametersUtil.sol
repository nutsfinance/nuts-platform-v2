pragma solidity ^0.5.0;

import "../protobuf/InstrumentData.sol";

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

}