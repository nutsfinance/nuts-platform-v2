pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/BorrowingData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../instrument/v3/InstrumentV3.sol";

contract Borrowing is InstrumentV3 {
    using SafeMath for uint256;

    event BorrowingCreated(uint256 indexed issuanceId, address indexed makerAddress, address escrowAddress,
        address collateralTokenAddress, address borrowingTokenAddress, uint256 borrowingAmount,
        uint256 collateralRatio, uint256 collateralTokenAmount, uint256 engagementDueTimestamp);

    event BorrowingEngaged(uint256 indexed issuanceId, address indexed takerAddress, uint256 borrowingDueTimstamp);

    event BorrowingRepaid(uint256 indexed issuanceId);

    event BorrowingCompleteNotEngaged(uint256 indexed issuanceId);

    event BorrowingDelinquent(uint256 indexed issuanceId);

    event BorrowingCancelled(uint256 indexed issuanceId);

    // Constants
    uint256 constant ENGAGEMENT_DUE_DAYS = 14 days;                 // Time available for taker to engage
    uint256 constant COLLATERAL_RATIO_DECIMALS = 10000;             // 0.01%
    uint256 constant INTEREST_RATE_DECIMALS = 1000000;              // 0.0001%

    // Scheduled custom events
    bytes32 constant ENGAGEMENT_DUE_EVENT = "engagement_due";
    bytes32 constant BORROWING_DUE_EVENT = "borrowing_due";

    // Custom events
    bytes32 constant CANCEL_ISSUANCE_EVENT = "cancel_issuance";

    // Lending parameters
    address private _collateralTokenAddress;
    address private _borrowingTokenAddress;
    uint256 private _borrowingAmount;
    uint256 private _tenorDays;
    uint256 private _engagementDueTimestamp;
    uint256 private _borrowingDueTimestamp;
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
        BorrowingMakerParameters.Data memory makerParameters = BorrowingMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.collateralTokenAddress != address(0x0), "Collateral token not set");
        require(makerParameters.borrowingTokenAddress != address(0x0), "Borrowing token not set");
        require(makerParameters.borrowingAmount > 0, "Borrowing amount not set");
        require(makerParameters.tenorDays >= 2 && makerParameters.tenorDays <= 90, "Invalid tenor days");
        require(makerParameters.collateralRatio >= 5000 && makerParameters.collateralRatio <= 20000, "Invalid collateral ratio");
        require(makerParameters.interestRate >= 10 && makerParameters.interestRate <= 50000, "Invalid interest rate");

        // Calculate the collateral amount. Collateral is calculated at the time of issuance creation.
        PriceOracleInterface priceOracle = PriceOracleInterface(issuanceParameters.priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(_borrowingTokenAddress, _collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        _collateralAmount = denominator.mul(makerParameters.borrowingAmount).mul(makerParameters.collateralRatio)
            .div(COLLATERAL_RATIO_DECIMALS).div(numerator);

        // Validate collateral token balance
        uint256 collateralTokenBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.makerAddress, makerParameters.collateralTokenAddress);
        require(collateralTokenBalance >= _collateralAmount, "Insufficient collateral balance");

        // Persists borrowing parameters
        _borrowingTokenAddress = makerParameters.borrowingTokenAddress;
        _borrowingAmount = makerParameters.borrowingAmount;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _tenorDays = makerParameters.tenorDays;
        _interestAmount = _borrowingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);

        // Emits Scheduled Engagement Due event
        _engagementDueTimestamp = now + ENGAGEMENT_DUE_DAYS;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Borrowing Created event
        emit BorrowingCreated(issuanceParameters.issuanceId, issuanceParameters.makerAddress, issuanceParameters.issuanceEscrowAddress,
            _collateralTokenAddress, _borrowingTokenAddress, _borrowingAmount, makerParameters.collateralRatio,
            _collateralAmount, _engagementDueTimestamp);

        // Updates to Engageable state.
        updatedState = IssuanceStates.Engageable;

        // Transfers collateral token from maker(Instrument Escrow) to maker(Issuance Escrow).
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
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

        // Validates borrowing balance
        uint256 borrowingBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.takerAddress, _borrowingTokenAddress);
        require(borrowingBalance >= _borrowingAmount, "Insufficient borrowing balance");

        // Emits Scheduled Borrowing Due event
        _borrowingDueTimestamp = now + _tenorDays * 1 days;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _borrowingDueTimestamp, BORROWING_DUE_EVENT, "");

        // Emits Borrowing Engaged event
        emit BorrowingEngaged(issuanceParameters.issuanceId, issuanceParameters.takerAddress, _borrowingDueTimestamp);

        // Transition to Engaged state.
        updatedState = IssuanceStates.Engaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers borrowing token from taker(Instrument Escrow) to taker(Issuance Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount
        });
        // Transfers borrowing token from taker(Issuance Escrow) to maker(Instrument Escrow)
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount
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
        require(issuanceParameters.callerAddress == issuanceParameters.makerAddress, "Only maker can repay");
        require(tokenAddress == _borrowingTokenAddress, "Must repay with borrowing token");
        require(amount == _borrowingAmount + _interestAmount, "Must repay in full");

        // Emits Borrowing Repaid event
        emit BorrowingRepaid(issuanceParameters.issuanceId);

        // Updates to Complete Engaged state.
        updatedState = IssuanceStates.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers borrowing amount + interest from maker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount + _interestAmount
        });
        // Transfers collateral from maker(Issuance Escrow) to maker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
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
                // Emits Borrowing Complete Not Engaged event
                emit BorrowingCompleteNotEngaged(issuanceParameters.issuanceId);

                // Updates to Complete Not Engaged state
                updatedState = IssuanceStates.CompleteNotEngaged;

                // Transfers collateral token from maker(Issuance Escrow) to maker(Instrument Escrow)
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.makerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not processed Engagement Due event
                updatedState = IssuanceStates(issuanceParameters.state);
            }
        } else if (eventName == BORROWING_DUE_EVENT) {
            // Borrowing Due will be processed only when:
            // 1. Issuance is in Engaged state
            // 2. Borrowing due timestamp has passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged && now >= _borrowingDueTimestamp) {
                // Emits Borrowing Deliquent event
                emit BorrowingDelinquent(issuanceParameters.issuanceId);

                // Updates to Delinquent state
                updatedState = IssuanceStates.Delinquent;

                // Transfers collateral token from maker(Issuance Escrow) to taker(Instrument Escrow).
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.makerAddress,
                    toAddress: issuanceParameters.takerAddress,
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

            // Emits Borrowing Cancelled event
            emit BorrowingCancelled(issuanceParameters.issuanceId);

            // Updates to Cancelled state.
            updatedState = IssuanceStates.Cancelled;

            // Transfers collateral token from maker(Issuance Escrow) to maker(Instrument Escrow)
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: issuanceParameters.makerAddress,
                toAddress: issuanceParameters.makerAddress,
                tokenAddress: _collateralTokenAddress,
                amount: _collateralAmount
            });
            transfersData = Transfers.encode(transfers);

        } else {
            revert("Unknown event");
        }
    }
}