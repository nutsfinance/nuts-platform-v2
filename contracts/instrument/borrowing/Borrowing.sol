pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/BorrowingData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/SupplementalLineItem.sol";
import "../../lib/util/Constants.sol";
import "../InstrumentBase.sol";

contract Borrowing is InstrumentBase {
    using SafeMath for uint256;

    event BorrowingCreated(
        uint256 indexed issuanceId,
        address indexed makerAddress,
        address escrowAddress,
        address collateralTokenAddress,
        address borrowingTokenAddress,
        uint256 borrowingAmount,
        uint256 collateralRatio,
        uint256 collateralTokenAmount,
        uint256 engagementDueTimestamp
    );

    event BorrowingEngaged(
        uint256 indexed issuanceId,
        address indexed takerAddress,
        uint256 borrowingDueTimstamp
    );

    event BorrowingRepaid(uint256 indexed issuanceId);

    event BorrowingCompleteNotEngaged(uint256 indexed issuanceId);

    event BorrowingDelinquent(uint256 indexed issuanceId);

    event BorrowingCancelled(uint256 indexed issuanceId);

    // Constants
    uint256 constant ENGAGEMENT_DUE_DAYS = 14 days; // Time available for taker to engage
    uint256 internal constant TENOR_DAYS_MIN = 2; // Minimum tenor is 2 days
    uint256 internal constant TENOR_DAYS_MAX = 90; // Maximum tenor is 90 days
    uint256 internal constant COLLATERAL_RATIO_DECIMALS = 10**4; // 0.01%
    uint256 internal constant COLLATERAL_RATIO_MIN = 5000; // Minimum collateral is 50%
    uint256 internal constant COLLATERAL_RATIO_MAX = 20000; // Maximum collateral is 200%
    uint256 internal constant INTEREST_RATE_DECIMALS = 10**6; // 0.0001%
    uint256 internal constant INTEREST_RATE_MIN = 10; // Mimimum interest rate is 0.0010%
    uint256 internal constant INTEREST_RATE_MAX = 50000; // Maximum interest rate is 5.0000%

    // Custom data
    bytes32 internal constant BORROWING_DATA = "borrowing_data";

    // Borrowing parameters
    address private _collateralTokenAddress;
    address private _borrowingTokenAddress;
    uint256 private _borrowingAmount;
    uint256 private _tenorDays;
    uint256 private _interestRate;
    uint256 private _interestAmount;
    uint256 private _collateralRatio;
    uint256 private _collateralAmount;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param callerAddress Address which invokes this function.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(
        address callerAddress,
        bytes memory makerParametersData
    ) public returns (bytes memory transfersData) {
        require(
            _state == IssuanceProperties.State.Initiated,
            "Issuance not in Initiated"
        );
        BorrowingMakerParameters.Data memory makerParameters = BorrowingMakerParameters
            .decode(makerParametersData);

        // Validates parameters.
        require(
            makerParameters.collateralTokenAddress != address(0x0),
            "Collateral token not set"
        );
        require(
            makerParameters.borrowingTokenAddress != address(0x0),
            "Borrowing token not set"
        );
        require(
            makerParameters.borrowingAmount > 0,
            "Borrowing amount not set"
        );
        require(
            makerParameters.tenorDays >= TENOR_DAYS_MIN &&
                makerParameters.tenorDays <= TENOR_DAYS_MAX,
            "Invalid tenor days"
        );
        require(
            makerParameters.collateralRatio >= COLLATERAL_RATIO_MIN &&
                makerParameters.collateralRatio <= COLLATERAL_RATIO_MAX,
            "Invalid collateral ratio"
        );
        require(
            makerParameters.interestRate >= INTEREST_RATE_MIN &&
                makerParameters.interestRate <= INTEREST_RATE_MAX,
            "Invalid interest rate"
        );

        // Calculate the collateral amount. Collateral is calculated at the time of issuance creation.
        PriceOracleInterface priceOracle = PriceOracleInterface(
            _priceOracleAddress
        );
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(
            makerParameters.borrowingTokenAddress,
            makerParameters.collateralTokenAddress
        );
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        uint256 collateralAmount = numerator
            .mul(makerParameters.borrowingAmount)
            .mul(makerParameters.collateralRatio)
            .div(COLLATERAL_RATIO_DECIMALS)
            .div(denominator);

        // Validate collateral token balance
        uint256 collateralTokenBalance = EscrowBaseInterface(
            _instrumentEscrowAddress
        )
            .getTokenBalance(
            callerAddress,
            makerParameters.collateralTokenAddress
        );
        require(
            collateralTokenBalance >= collateralAmount,
            "Insufficient collateral balance"
        );

        // Sets common properties
        _makerAddress = callerAddress;
        _creationTimestamp = now;
        _engagementDueTimestamp = now.add(ENGAGEMENT_DUE_DAYS);
        _state = IssuanceProperties.State.Engageable;

        // Sets borrowing parameters
        _borrowingTokenAddress = makerParameters.borrowingTokenAddress;
        _borrowingAmount = makerParameters.borrowingAmount;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _tenorDays = makerParameters.tenorDays;
        _interestRate = makerParameters.interestRate;
        _interestAmount = _borrowingAmount
            .mul(makerParameters.tenorDays)
            .mul(makerParameters.interestRate)
            .div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;
        _collateralAmount = collateralAmount;

        // Emits Scheduled Engagement Due event
        emit EventTimeScheduled(
            _issuanceId,
            _engagementDueTimestamp,
            ENGAGEMENT_DUE_EVENT,
            ""
        );

        // Emits Borrowing Created event
        emit BorrowingCreated(
            _issuanceId,
            _makerAddress,
            _issuanceEscrowAddress,
            _collateralTokenAddress,
            _borrowingTokenAddress,
            _borrowingAmount,
            _collateralRatio,
            _collateralAmount,
            _engagementDueTimestamp
        );

        // Transfers collateral token
        Transfers.Data memory transfers = Transfers.Data(
            new Transfer.Data[](2)
        );
        // Collateral token inbound transfer: Maker
        transfers.actions[0] = _createInboundTransfer(
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount
        );
        // Collateral token intra-issuance transfer: Maker --> Custodian
        transfers.actions[1] = _createIntraIssuanceTransfer(
            _makerAddress,
            Constants.getCustodianAddress(),
            _collateralTokenAddress,
            _collateralAmount
        );
        transfersData = Transfers.encode(transfers);
        // Create payable 1: Custodian --> Maker
        _createNewPayable(
            1,
            Constants.getCustodianAddress(),
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount,
            _engagementDueTimestamp
        );
    }

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(
        address callerAddress,
        bytes memory /** takerParameters */
    ) public returns (bytes memory transfersData) {
        require(
            _state == IssuanceProperties.State.Engageable,
            "Issuance not in Engageable"
        );

        // Validates borrowing balance
        uint256 borrowingBalance = EscrowBaseInterface(_instrumentEscrowAddress)
            .getTokenBalance(callerAddress, _borrowingTokenAddress);
        require(
            borrowingBalance >= _borrowingAmount,
            "Insufficient borrowing balance"
        );

        // Sets common properties
        _takerAddress = callerAddress;
        _engagementTimestamp = now;
        _issuanceDueTimestamp = now.add(_tenorDays * 1 days);

        // Emits Scheduled Borrowing Due event
        emit EventTimeScheduled(
            _issuanceId,
            _issuanceDueTimestamp,
            ISSUANCE_DUE_EVENT,
            ""
        );

        // Emits Borrowing Engaged event
        emit BorrowingEngaged(
            _issuanceId,
            _takerAddress,
            _issuanceDueTimestamp
        );

        // Transition to Engaged state.
        _state = IssuanceProperties.State.Engaged;

        Transfers.Data memory transfers = Transfers.Data(
            new Transfer.Data[](3)
        );
        // Principal token inbound transfer: Taker
        transfers.actions[0] = _createInboundTransfer(
            _takerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        // Principal token intra-issuance transfer: Taker --> Maker
        transfers.actions[1] = _createIntraIssuanceTransfer(
            _takerAddress,
            _makerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        // Create payable 2: Maker --> Taker
        _createNewPayable(
            2,
            _makerAddress,
            _takerAddress,
            _borrowingTokenAddress,
            _borrowingAmount,
            _issuanceDueTimestamp
        );
        // Create payable 3: Maker --> Taker
        _createNewPayable(
            3,
            _makerAddress,
            _takerAddress,
            _borrowingTokenAddress,
            _interestAmount,
            _issuanceDueTimestamp
        );
        // Create payable 4: Custodian --> Maker
        _createNewPayable(
            4,
            Constants.getCustodianAddress(),
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount,
            _issuanceDueTimestamp
        );
        // Mark payable 1 as reinitiated by payable 4
        _updatePayable(1, SupplementalLineItem.State.Reinitiated, 4);
        // Principal token outbound transfer: Maker
        transfers.actions[2] = _createOutboundTransfer(
            _makerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev A custom event is triggered.
     * @param callerAddress Address which invokes this function.
     * @param eventName The name of the custom event.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(
        address callerAddress,
        bytes32 eventName,
        bytes memory /** eventPayload */
    ) public returns (bytes memory transfersData) {
        if (eventName == ENGAGEMENT_DUE_EVENT) {
            return processEngagementDue();
        } else if (eventName == ISSUANCE_DUE_EVENT) {
            return processIssuanceDue();
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            return cancelIssuance(callerAddress);
        } else if (eventName == REPAY_ISSUANCE_FULL_EVENT) {
            return repayIssuance(callerAddress);
        } else {
            revert("Unknown event");
        }
    }

    /**
     * @dev Processes the Engagement Due event.
     */
    function processEngagementDue()
        private
        returns (bytes memory transfersData)
    {
        // Engagement Due will be processed only when:
        // 1. Issuance is in Engageable state
        // 2. Engagement due timestamp is passed
        if (
            _state == IssuanceProperties.State.Engageable &&
            now >= _engagementDueTimestamp
        ) {
            // Emits Borrowing Complete Not Engaged event
            emit BorrowingCompleteNotEngaged(_issuanceId);

            // Updates to Complete Not Engaged state
            _state = IssuanceProperties.State.CompleteNotEngaged;

            Transfers.Data memory transfers = Transfers.Data(
                new Transfer.Data[](2)
            );
            // Collateral token intra-issuance transfer: Custodian --> Maker
            transfers.actions[0] = _createIntraIssuanceTransfer(
                Constants.getCustodianAddress(),
                _makerAddress,
                _collateralTokenAddress,
                _collateralAmount
            );
            // Mark payable 1 as paid
            _updatePayable(1, SupplementalLineItem.State.Paid, 0);
            // Collateral token outbound transfer: Maker
            transfers.actions[1] = _createOutboundTransfer(
                _makerAddress,
                _collateralTokenAddress,
                _collateralAmount
            );
            transfersData = Transfers.encode(transfers);
        }
    }

    /**
     * @dev Processes the Issuance Due event.
     */
    function processIssuanceDue() private returns (bytes memory transfersData) {
        // Borrowing Due will be processed only when:
        // 1. Issuance is in Engaged state
        // 2. Borrowing due timestamp has passed
        if (
            _state == IssuanceProperties.State.Engaged &&
            now >= _issuanceDueTimestamp
        ) {
            // Emits Borrowing Deliquent event
            emit BorrowingDelinquent(_issuanceId);

            // Updates to Delinquent state
            _state = IssuanceProperties.State.Delinquent;

            Transfers.Data memory transfers = Transfers.Data(
                new Transfer.Data[](3)
            );
            // Collateral token intra-issuance transfer: Custodian --> Maker
            transfers.actions[0] = _createIntraIssuanceTransfer(
                Constants.getCustodianAddress(),
                _makerAddress,
                _collateralTokenAddress,
                _collateralAmount
            );
            // Mark payable 4 as paid
            _updatePayable(4, SupplementalLineItem.State.Paid, 0);
            // Collateral token intra-issuance transfer: Maker --> Taker
            transfers.actions[1] = _createIntraIssuanceTransfer(
                _makerAddress,
                _takerAddress,
                _collateralTokenAddress,
                _collateralAmount
            );
            // Collateral token outbound transfer: Taker
            transfers.actions[2] = _createOutboundTransfer(
                _takerAddress,
                _collateralTokenAddress,
                _collateralAmount
            );
            transfersData = Transfers.encode(transfers);
        }
    }

    /**
     * @dev Cancels the issuance.
     * @param callerAddress Address of the caller who cancels the issuance.
     */
    function cancelIssuance(address callerAddress)
        private
        returns (bytes memory transfersData)
    {
        // Cancel Issuance must be processed in Engageable state
        require(
            _state == IssuanceProperties.State.Engageable,
            "Cancel issuance not in engageable state"
        );
        // Only maker can cancel issuance
        require(
            callerAddress == _makerAddress,
            "Only maker can cancel issuance"
        );

        // Emits Borrowing Cancelled event
        emit BorrowingCancelled(_issuanceId);

        // Updates to Cancelled state.
        _state = IssuanceProperties.State.Cancelled;

        Transfers.Data memory transfers = Transfers.Data(
            new Transfer.Data[](2)
        );
        // Collateral token intra-issuance transfer: Custodian --> Maker
        transfers.actions[0] = _createIntraIssuanceTransfer(
            Constants.getCustodianAddress(),
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount
        );
        // Mark payable 1 as paid
        _updatePayable(1, SupplementalLineItem.State.Paid, 0);
        // Collateral token outbound transfer: Maker
        transfers.actions[1] = _createOutboundTransfer(
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount
        );
        transfersData = Transfers.encode(transfers);
    }

    function repayIssuance(address callerAddress)
        private
        returns (bytes memory transfersData)
    {
        // Important: Token deposit can happen only in repay!
        require(
            _state == IssuanceProperties.State.Engaged,
            "Issuance not in Engaged"
        );
        require(callerAddress == _makerAddress, "Only maker can repay");
        uint256 repayAmount = _borrowingAmount + _interestAmount;
        // Validates borrowing balance
        uint256 borrowingBalance = EscrowBaseInterface(_instrumentEscrowAddress)
            .getTokenBalance(_makerAddress, _borrowingTokenAddress);
        require(
            borrowingBalance >= repayAmount,
            "Insufficient borrowing balance"
        );
        // Sets common properties
        _settlementTimestamp = now;

        // Emits Borrowing Repaid event
        emit BorrowingRepaid(_issuanceId);

        // Updates to Complete Engaged state.
        _state = IssuanceProperties.State.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(
            new Transfer.Data[](8)
        );

        // Pricipal inbound transfer: Maker
        transfers.actions[0] = _createInboundTransfer(
            _makerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        // Interest inbound transfer: Maker
        transfers.actions[1] = _createInboundTransfer(
            _makerAddress,
            _borrowingTokenAddress,
            _interestAmount
        );

        // Principal intra-issuance transfer: Maker --> Taker
        transfers.actions[2] = _createIntraIssuanceTransfer(
            _makerAddress,
            _takerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        // Mark payable 2 as paid
        _updatePayable(2, SupplementalLineItem.State.Paid, 0);
        // Interest intra-issuance transfer: Maker --> Taker
        transfers.actions[3] = _createIntraIssuanceTransfer(
            _makerAddress,
            _takerAddress,
            _borrowingTokenAddress,
            _interestAmount
        );
        // Mark payable 3 as paid
        _updatePayable(3, SupplementalLineItem.State.Paid, 0);
        // Collateral token intra-issuance transfer: Custodian --> Maker
        transfers.actions[4] = _createIntraIssuanceTransfer(
            Constants.getCustodianAddress(),
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount
        );
        // Mark payable 4 as paid
        _updatePayable(4, SupplementalLineItem.State.Paid, 0);
        // Collateral outbound transfer: Maker
        transfers.actions[5] = _createOutboundTransfer(
            _makerAddress,
            _collateralTokenAddress,
            _collateralAmount
        );
        // Principal outbound transfer: Taker
        transfers.actions[6] = _createOutboundTransfer(
            _takerAddress,
            _borrowingTokenAddress,
            _borrowingAmount
        );
        // Interest outbound transfer: Taker
        transfers.actions[7] = _createOutboundTransfer(
            _takerAddress,
            _borrowingTokenAddress,
            _interestAmount
        );
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev Get custom data.
     * @param dataName The name of the custom data.
     * @return customData The custom data of the issuance.
     */
    function getCustomData(
        address, /** callerAddress */
        bytes32 dataName
    ) public view returns (bytes memory) {
        if (dataName == BORROWING_DATA) {
            BorrowingProperties.Data memory borrowingProperties = BorrowingProperties
                .Data({
                borrowingTokenAddress: _borrowingTokenAddress,
                collateralTokenAddress: _collateralTokenAddress,
                borrowingAmount: _borrowingAmount,
                collateralRatio: _collateralRatio,
                collateralAmount: _collateralAmount,
                interestRate: _interestRate,
                interestAmount: _interestAmount,
                tenorDays: _tenorDays
            });

            BorrowingCompleteProperties.Data memory borrowingCompleteProperties = BorrowingCompleteProperties
                .Data({
                issuanceProperties: _getIssuanceProperties(),
                borrowingProperties: borrowingProperties
            });

            return
                BorrowingCompleteProperties.encode(borrowingCompleteProperties);
        } else {
            revert("Unknown data");
        }
    }
}
