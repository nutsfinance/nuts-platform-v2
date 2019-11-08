pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/protobuf/SwapData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../InstrumentBase.sol";

contract SpotSwap is InstrumentBase {
    event SwapCreated(uint256 indexed issuanceId, address indexed makerAddress, address escrowAddress,
        address inputTokenAddress, address outputTokenAddress, uint256 inputAmount, uint256 outputAmount,
        uint256 swapDueTimestamp);

    event SwapEngaged(uint256 indexed issuanceId, address indexed takerAddress);

    event SwapCompleteNotEngaged(uint256 indexed issuanceId);

    event SwapCancelled(uint256 indexed issuanceId);

    // Scheduled custom events
    bytes32 constant SWAP_DUE_EVENT = "swap_due";

    // Custom events
    bytes32 constant CANCEL_ISSUANCE_EVENT = "cancel_issuance";

    // Lending parameters
    address private _inputTokenAddress;
    address private _outputTokenAddress;
    uint256 private _inputAmount;
    uint256 private _outputAmount;
    uint256 private _swapDueTimestamp;

    /**
     * @dev Creates a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState, bytes memory transfersData) {

        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        SpotSwapMakerParameters.Data memory makerParameters = SpotSwapMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.inputTokenAddress != address(0x0), "Input token not set");
        require(makerParameters.outputTokenAddress != address(0x0), "Output token not set");
        require(makerParameters.inputAmount > 0, "Input amount not set");
        require(makerParameters.outputAmount > 0, "Output amount not set");
        require(makerParameters.duration >= 1 && makerParameters.duration <= 90, "Invalid duration");

        // Validate input token balance
        uint256 inputTokenBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.makerAddress, makerParameters.inputTokenAddress);
        require(inputTokenBalance >= makerParameters.inputAmount, "Insufficient input balance");

        // Persists swap parameters
        _inputTokenAddress = makerParameters.inputTokenAddress;
        _outputTokenAddress = makerParameters.outputTokenAddress;
        _inputAmount = makerParameters.inputAmount;
        _outputAmount = makerParameters.outputAmount;

        // Emits Scheduled Swap Due event
        _swapDueTimestamp = now + 1 days * makerParameters.duration;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _swapDueTimestamp, SWAP_DUE_EVENT, "");

        // Emits Swap Created event
        emit SwapCreated(issuanceParameters.issuanceId, issuanceParameters.makerAddress, issuanceParameters.issuanceEscrowAddress,
            _inputTokenAddress, _outputTokenAddress, _inputAmount, _outputAmount, _swapDueTimestamp);

        // Updates to Engageable state.
        updatedState = IssuanceStates.Engageable;

        // Transfers input token from maker(Instrument Escrow) to maker(Issuance Escrow).
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _inputTokenAddress,
            amount: _inputAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData, bytes memory /* takerParameters */) public
        returns (IssuanceStates updatedState, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

        // Validates output balance
        uint256 outputTokenBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.takerAddress, _outputTokenAddress);
        require(outputTokenBalance >= _outputAmount, "Insufficient output balance");

        // Transition to Complete Engaged state.
        updatedState = IssuanceStates.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](3));
        // Transfers input token from maker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _inputTokenAddress,
            amount: _inputAmount
        });
        // Transfers output token from taker(Instrument Escrow) to taker(Issuance Escrow)
        transfers.actions[1] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _outputTokenAddress,
            amount: _outputAmount
        });
        // Transfers output token from taker(Issuance Escrow) to maker(Instrument Escrow).
        transfers.actions[2] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _outputTokenAddress,
            amount: _outputAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     */
    function processTokenDeposit(bytes memory /* issuanceParametersData */, address /* tokenAddress */, uint256 /* amount */) public
        returns (IssuanceStates, bytes memory) {
        revert("Deposit not supported.");
    }

    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     */
    function processTokenWithdraw(bytes memory /* issuanceParametersData */, address /* tokenAddress */, uint256 /* amount */)
        public returns (IssuanceStates, bytes memory) {
        revert("Withdrawal not supported.");
    }

    /**
     * @dev A custom event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory /* eventPayload */)
        public returns (IssuanceStates updatedState, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

        if (eventName == SWAP_DUE_EVENT) {
            // Swap Due will be processed only when:
            // 1. Issuance is in Engageable state
            // 2. Swap due timestamp is passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable && now >= _swapDueTimestamp) {
                // Emits Swap Complete Not Engaged event
                emit SwapCompleteNotEngaged(issuanceParameters.issuanceId);

                // Updates to Complete Not Engaged state
                updatedState = IssuanceStates.CompleteNotEngaged;

                // Transfers input token from maker(Issuance Escrow) to maker(Instrument Escrow)
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.makerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: _inputTokenAddress,
                    amount: _inputAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not processed Engagement Due event
                updatedState = IssuanceStates(issuanceParameters.state);
            }
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            // Cancel Issuance must be processed in Engageable state
            require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable, "Cancel issuance not in engageable state");
            // Only maker can cancel issuance
            require(issuanceParameters.callerAddress == issuanceParameters.makerAddress, "Only maker can cancel issuance");

            // Emits Swap Cancelled event
            emit SwapCancelled(issuanceParameters.issuanceId);

            // Updates to Cancelled state.
            updatedState = IssuanceStates.Cancelled;

            // Transfers collateral token from maker(Issuance Escrow) to maker(Instrument Escrow)
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: issuanceParameters.makerAddress,
                toAddress: issuanceParameters.makerAddress,
                tokenAddress: _inputTokenAddress,
                amount: _inputAmount
            });
            transfersData = Transfers.encode(transfers);

        } else {
            revert("Unknown event");
        }
    }

    /**
     * @dev Read custom data.
     * @return customData The custom data of the issuance.
     */
    function readCustomData(bytes memory /** issuanceParametersData */, bytes32 /** dataName */) public view returns (bytes memory) {
        revert('Unsupported operation.');
    }
}