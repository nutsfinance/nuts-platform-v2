pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LendingData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../InstrumentBase.sol";

contract Lending is InstrumentBase {
    using SafeMath for uint256;

    event LendingCreated(uint256 indexed issuanceId, address indexed makerAddress, address escrowAddress,
        address collateralTokenAddress, address lendingTokenAddress, uint256 lendingAmount,
        uint256 collateralRatio, uint256 engagementDueTimestamp);

    event LendingEngaged(uint256 indexed issuanceId, address indexed takerAddress, uint256 lendingDueTimstamp,
        uint256 collateralTokenAmount);

    event LendingRepaid(uint256 indexed issuanceId);

    event LendingCompleteNotEngaged(uint256 indexed issuanceId);

    event LendingDelinquent(uint256 indexed issuanceId);

    event LendingCancelled(uint256 indexed issuanceId);

    // Constants
    uint256 constant internal ENGAGEMENT_DUE_DAYS = 14 days;                 // Time available for taker to engage
    uint256 constant internal COLLATERAL_RATIO_DECIMALS = 10000;             // 0.01%
    uint256 constant internal INTEREST_RATE_DECIMALS = 1000000;              // 0.0001%

    // Scheduled custom events
    bytes32 constant internal ENGAGEMENT_DUE_EVENT = "engagement_due";
    bytes32 constant internal LENDING_DUE_EVENT = "lending_due";

    // Custom events
    bytes32 constant internal CANCEL_ISSUANCE_EVENT = "cancel_issuance";

    // Lending parameters
    address private _lendingTokenAddress;
    address private _collateralTokenAddress;
    uint256 private _tenorDays;
    uint256 private _lendingAmount;
    uint256 private _collateralRatio;
    uint256 private _engagementDueTimestamp;
    uint256 private _lendingDueTimestamp;
    uint256 private _interestAmount;
    uint256 private _collateralAmount;

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
        LendingMakerParameters.Data memory makerParameters = LendingMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.collateralTokenAddress != address(0x0), "Collateral token not set");
        require(makerParameters.lendingTokenAddress != address(0x0), "Lending token not set");
        require(makerParameters.lendingAmount > 0, "Lending amount not set");
        require(makerParameters.tenorDays >= 2 && makerParameters.tenorDays <= 90, "Invalid tenor days");
        require(makerParameters.collateralRatio >= 5000 && makerParameters.collateralRatio <= 20000, "Invalid collateral ratio");
        require(makerParameters.interestRate >= 10 && makerParameters.interestRate <= 50000, "Invalid interest rate");

        // Validate principal token balance
        uint256 principalTokenBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.makerAddress, makerParameters.lendingTokenAddress);
        require(principalTokenBalance >= makerParameters.lendingAmount, "Insufficient principal balance");
 
        // Persists lending parameters
        _lendingTokenAddress = makerParameters.lendingTokenAddress;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _lendingAmount = makerParameters.lendingAmount;
        _tenorDays = makerParameters.tenorDays;
        _interestAmount = _lendingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;

        // Emits Scheduled Engagement Due event
        _engagementDueTimestamp = now + ENGAGEMENT_DUE_DAYS;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Lending Created event
        emit LendingCreated(issuanceParameters.issuanceId, issuanceParameters.makerAddress, issuanceParameters.issuanceEscrowAddress,
            _collateralTokenAddress, _lendingTokenAddress, _lendingAmount, _collateralRatio, _engagementDueTimestamp);

        // Updates to Engageable state.
        updatedState = IssuanceStates.Engageable;

        // Transfers principal token from maker(Instrument Escrow) to maker(Issuance Escrow).
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
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

        // Calculate the collateral amount. Collateral is calculated at the time of engagement.
        PriceOracleInterface priceOracle = PriceOracleInterface(issuanceParameters.priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(_lendingTokenAddress, _collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        _collateralAmount = denominator.mul(_lendingAmount).mul(_collateralRatio).div(COLLATERAL_RATIO_DECIMALS).div(numerator);

        // Validates collateral balance
        uint256 collateralBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.takerAddress, _collateralTokenAddress);
        require(collateralBalance >= _collateralAmount, "Insufficient collateral balance");

        // Emits Scheduled Lending Due event
        _lendingDueTimestamp = now + _tenorDays * 1 days;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _lendingDueTimestamp, LENDING_DUE_EVENT, "");

        // Emits Lending Engaged event
        emit LendingEngaged(issuanceParameters.issuanceId, issuanceParameters.takerAddress, _lendingDueTimestamp,
            _collateralAmount);

        // Transition to Engaged state.
        updatedState = IssuanceStates.Engaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers collateral token from taker(Instrument Escrow) to taker(Issuance Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        // Transfers lending token from maker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount) public
        returns (IssuanceStates updatedState, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

        // Important: Token deposit can happen only in repay!
        require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged, "Must repay in engaged state");
        require(issuanceParameters.callerAddress == issuanceParameters.takerAddress, "Only taker can repay");
        require(tokenAddress == _lendingTokenAddress, "Must repay with lending token");
        require(amount == _lendingAmount + _interestAmount, "Must repay in full");

        // Emits Lending Repaid event
        emit LendingRepaid(issuanceParameters.issuanceId);

        // Updates to Complete Engaged state.
        updatedState = IssuanceStates.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers lending amount + interest from taker(Issuance Escrow) to maker(Instrument Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount + _interestAmount
        });
        // Transfers collateral from taker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        transfersData = Transfers.encode(transfers);
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

        if (eventName == ENGAGEMENT_DUE_EVENT) {
            // Engagement Due will be processed only when:
            // 1. Issuance is in Engageable state
            // 2. Engagement due timestamp is passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable && now >= _engagementDueTimestamp) {
                // Emits Lending Complete Not Engaged event
                emit LendingCompleteNotEngaged(issuanceParameters.issuanceId);

                // Updates to Complete Not Engaged state
                updatedState = IssuanceStates.CompleteNotEngaged;

                // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.makerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: _lendingTokenAddress,
                    amount: _lendingAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not processed Engagement Due event
                updatedState = IssuanceStates(issuanceParameters.state);
            }
        } else if (eventName == LENDING_DUE_EVENT) {
            // Lending Due will be processed only when:
            // 1. Issuance is in Engaged state
            // 2. Lending due timestamp has passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged && now >= _lendingDueTimestamp) {
                // Emits Lending Deliquent event
                emit LendingDelinquent(issuanceParameters.issuanceId);

                // Updates to Delinquent state
                updatedState = IssuanceStates.Delinquent;

                // Transfers collateral token from taker(Issuance Escrow) to maker(Instrument Escrow).
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.takerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not process Lending Due event
                updatedState = IssuanceStates(issuanceParameters.state);
            }
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            // Cancel Issuance must be processed in Engageable state
            require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable, "Cancel issuance not in engageable state");
            // Only maker can cancel issuance
            require(issuanceParameters.callerAddress == issuanceParameters.makerAddress, "Only maker can cancel issuance");

            // Emits Lending Cancelled event
            emit LendingCancelled(issuanceParameters.issuanceId);

            // Updates to Cancelled state.
            updatedState = IssuanceStates.Cancelled;

            // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: issuanceParameters.makerAddress,
                toAddress: issuanceParameters.makerAddress,
                tokenAddress: _lendingTokenAddress,
                amount: _lendingAmount
            });
            transfersData = Transfers.encode(transfers);

        } else {
            revert("Unknown event");
        }
    }

    /**
     * @dev Read custom data.
     */
    function readCustomData(bytes memory /** issuanceParametersData */, bytes32 /** dataName */) public view returns (bytes memory) {
        revert('Unsupported operation.');
    }
}