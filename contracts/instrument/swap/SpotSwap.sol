pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/protobuf/SwapData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/SupplementalLineItem.sol";
import "../../lib/util/Constants.sol";
import "../InstrumentBase.sol";

contract SpotSwap is InstrumentBase {
    using SafeMath for uint256;

    event SwapCreated(uint256 indexed issuanceId, address indexed makerAddress, address escrowAddress,
        address inputTokenAddress, address outputTokenAddress, uint256 inputAmount, uint256 outputAmount,
        uint256 swapDueTimestamp);

    event SwapEngaged(uint256 indexed issuanceId, address indexed takerAddress);

    event SwapCompleteNotEngaged(uint256 indexed issuanceId);

    event SwapCancelled(uint256 indexed issuanceId);

    // Custom data
    bytes32 constant internal SWAP_DATA = "swap_data";

    // SpotSwap parameters
    address private _inputTokenAddress;
    address private _outputTokenAddress;
    uint256 private _inputAmount;
    uint256 private _outputAmount;
    uint256 private _duration;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param callerAddress Address which invokes this function.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(address callerAddress, bytes memory makerParametersData) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Initiated, "Issuance not in Initiated");
        SpotSwapMakerParameters.Data memory makerParameters = SpotSwapMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.inputTokenAddress != address(0x0), "Input token not set");
        require(makerParameters.outputTokenAddress != address(0x0), "Output token not set");
        require(makerParameters.inputAmount > 0, "Input amount not set");
        require(makerParameters.outputAmount > 0, "Output amount not set");
        require(makerParameters.duration >= 1 && makerParameters.duration <= 90, "Invalid duration");

        // Validate input token balance
        uint256 inputTokenBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress,
            makerParameters.inputTokenAddress);
        require(inputTokenBalance >= makerParameters.inputAmount, "Insufficient input balance");

        // Sets common properties
        _makerAddress = callerAddress;
        _creationTimestamp = now;
        _state = IssuanceProperties.State.Engageable;
        _engagementDueTimestamp = now.add(1 days * makerParameters.duration);
        _issuanceDueTimestamp = _engagementDueTimestamp;

        // Sets swap parameters
        _inputTokenAddress = makerParameters.inputTokenAddress;
        _outputTokenAddress = makerParameters.outputTokenAddress;
        _inputAmount = makerParameters.inputAmount;
        _outputAmount = makerParameters.outputAmount;
        _duration = makerParameters.duration;

        // Emits Scheduled Swap Due event
        emit EventTimeScheduled(_issuanceId, _issuanceDueTimestamp, ISSUANCE_DUE_EVENT, "");

        // Emits Swap Created event
        emit SwapCreated(_issuanceId, _makerAddress, _issuanceEscrowAddress, _inputTokenAddress, _outputTokenAddress,
            _inputAmount, _outputAmount, _issuanceDueTimestamp);

        // Updates to Engageable state.
        _state = IssuanceProperties.State.Engageable;

        // Transfers principal token
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Input token inbound transfer: Maker
        transfers.actions[0] = _createInboundTransfer(_makerAddress, _inputTokenAddress, _inputAmount);
        // Input token intra-issuance transfer: Maker --> Custodian
        transfers.actions[1] = _createIntraIssuanceTransfer(_makerAddress, Constants.getCustodianAddress(),
            _inputTokenAddress, _inputAmount);
        transfersData = Transfers.encode(transfers);
        // Create payable 1: Custodian --> Maker
        _createNewPayable(1, Constants.getCustodianAddress(), _makerAddress, _inputTokenAddress, _inputAmount, _engagementDueTimestamp);
    }

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(address callerAddress, bytes memory /** takerParameters */) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Engageable, "Issuance not in Engageable");

        // Validates output balance
        uint256 outputTokenBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress, _outputTokenAddress);
        require(outputTokenBalance >= _outputAmount, "Insufficient output balance");

        // Sets common properties
        _takerAddress = callerAddress;
        _engagementTimestamp = now;
        _settlementTimestamp = now;

        // Transition to Complete Engaged state.
        _state = IssuanceProperties.State.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](6));
        // Output token inbound transfer: Taker
        transfers.actions[0] = _createInboundTransfer(_takerAddress, _outputTokenAddress, _outputAmount);
        // Input token intra-issuance transfer: Custodian --> Maker
        transfers.actions[1] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress, _inputTokenAddress, _inputAmount);
        // Maker payable 1 as paid
        _updatePayable(1, SupplementalLineItem.State.Paid, 0);
        // Input token intra-issuance transfer: Maker --> Taker
        transfers.actions[2] = _createIntraIssuanceTransfer(_makerAddress, _takerAddress, _inputTokenAddress, _inputAmount);
        // Output token intra-issuance transfer: Taker --> Maker
        transfers.actions[3] = _createIntraIssuanceTransfer(_takerAddress, _makerAddress, _outputTokenAddress, _outputAmount);
        // Output token outbound transfer: Maker
        transfers.actions[4] = _createOutboundTransfer(_makerAddress, _outputTokenAddress, _outputAmount);
        // Input token outbound transfer: Taker
        transfers.actions[5] = _createOutboundTransfer(_takerAddress, _inputTokenAddress, _inputAmount);
        transfersData = Transfers.encode(transfers);
        emit SwapEngaged(_issuanceId, _takerAddress);
    }

    /**
     * @dev A custom event is triggered.
     * @param callerAddress Address which invokes this function.
     * @param eventName The name of the custom event.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(address callerAddress, bytes32 eventName, bytes memory /** eventPayload */) public
        returns (bytes memory transfersData) {

        if (eventName == ISSUANCE_DUE_EVENT) {
            // Swap Due will be processed only when:
            // 1. Issuance is in Engageable state
            // 2. Swap due timestamp is passed
            if (_state == IssuanceProperties.State.Engageable && now >= _issuanceDueTimestamp) {
                // Emits Swap Complete Not Engaged event
                emit SwapCompleteNotEngaged(_issuanceId);

                // Updates to Complete Not Engaged state
                _state = IssuanceProperties.State.CompleteNotEngaged;

                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
                // Input token intra-issuance transfer: Custodian --> Maker
                transfers.actions[0] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress, _inputTokenAddress, _inputAmount);
                // Mark payable 1 as paid
                _updatePayable(1, SupplementalLineItem.State.Paid, 0);
                // Input token outbound transfer: Maker
                transfers.actions[1] = _createOutboundTransfer(_makerAddress, _inputTokenAddress, _inputAmount);
                transfersData = Transfers.encode(transfers);
            }
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            // Cancel Issuance must be processed in Engageable state
            require(_state == IssuanceProperties.State.Engageable, "Cancel issuance not in engageable state");
            // Only maker can cancel issuance
            require(callerAddress == _makerAddress, "Only maker can cancel issuance");

            // Emits Swap Cancelled event
            emit SwapCancelled(_issuanceId);

            // Updates to Cancelled state.
            _state = IssuanceProperties.State.Cancelled;

            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
            // Input token intra-issuance transfer: Custodian --> Maker
            transfers.actions[0] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress, _inputTokenAddress, _inputAmount);
            // Mark payable 1 as paid
            _updatePayable(1, SupplementalLineItem.State.Paid, 0);
            // Input token outbound transfer: Maker
            transfers.actions[1] = _createOutboundTransfer(_makerAddress, _inputTokenAddress, _inputAmount);
            transfersData = Transfers.encode(transfers);
        } else {
            revert("Unknown event");
        }
    }

    /**
     * @dev Get custom data.
     * @param dataName The name of the custom data.
     * @return customData The custom data of the issuance.
     */
    function getCustomData(address /** callerAddress */, bytes32 dataName) public view returns (bytes memory) {
        if (dataName == SWAP_DATA) {
            SpotSwapProperties.Data memory spotSwapProperties = SpotSwapProperties.Data({
                inputTokenAddress: _inputTokenAddress,
                outputTokenAddress: _outputTokenAddress,
                inputAmount: _inputAmount,
                outputAmount: _outputAmount,
                duration: _duration
            });

            SpotSwapCompleteProperties.Data memory spotSwapCompleteProperties = SpotSwapCompleteProperties.Data({
                issuanceProperties: _getIssuanceProperties(),
                spotSwapProperties: spotSwapProperties
            });

            return SpotSwapCompleteProperties.encode(spotSwapCompleteProperties);
        } else {
            revert('Unknown data');
        }
    }
}
