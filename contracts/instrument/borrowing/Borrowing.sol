pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/BorrowingData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/SupplementalLineItem.sol";
import "../../lib/util/Constants.sol";
import "../InstrumentBase.sol";

contract Borrowing is InstrumentBase {
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

    // Custom data
    bytes32 constant internal BORROWING_DATA = "borrowing_data";

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
    function createIssuance(address callerAddress, bytes memory makerParametersData) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Initiated, "Issuance not in Initiated");
        BorrowingMakerParameters.Data memory makerParameters = BorrowingMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.collateralTokenAddress != address(0x0), "Collateral token not set");
        require(makerParameters.borrowingTokenAddress != address(0x0), "Borrowing token not set");
        require(makerParameters.borrowingAmount > 0, "Borrowing amount not set");
        require(makerParameters.tenorDays >= 2 && makerParameters.tenorDays <= 90, "Invalid tenor days");
        require(makerParameters.collateralRatio >= 5000 && makerParameters.collateralRatio <= 20000, "Invalid collateral ratio");
        require(makerParameters.interestRate >= 10 && makerParameters.interestRate <= 50000, "Invalid interest rate");

        // Calculate the collateral amount. Collateral is calculated at the time of issuance creation.
        PriceOracleInterface priceOracle = PriceOracleInterface(_priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(makerParameters.borrowingTokenAddress,
            makerParameters.collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        uint256 collateralAmount = denominator.mul(makerParameters.borrowingAmount).mul(makerParameters.collateralRatio)
            .div(COLLATERAL_RATIO_DECIMALS).div(numerator);

        // Validate collateral token balance
        uint256 collateralTokenBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress,
            makerParameters.collateralTokenAddress);
        require(collateralTokenBalance >= collateralAmount, "Insufficient collateral balance");

        // Sets common properties
        _makerAddress = callerAddress;
        _creationTimestamp = now;
        _engagementDueTimestamp = now + ENGAGEMENT_DUE_DAYS;
        _state = IssuanceProperties.State.Engageable;

        // Sets borrowing parameters
        _borrowingTokenAddress = makerParameters.borrowingTokenAddress;
        _borrowingAmount = makerParameters.borrowingAmount;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _tenorDays = makerParameters.tenorDays;
        _interestRate = makerParameters.interestRate;
        _interestAmount = _borrowingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;
        _collateralAmount = collateralAmount;

        // Emits Scheduled Engagement Due event
        emit EventTimeScheduled(_issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Borrowing Created event
        emit BorrowingCreated(_issuanceId, _makerAddress, _issuanceEscrowAddress, _collateralTokenAddress, _borrowingTokenAddress,
            _borrowingAmount, _collateralRatio, _collateralAmount, _engagementDueTimestamp);

        // Transfers collateral token
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Collateral token inbound transfer: Maker
        transfers.actions[0] = Transfer.Data({
            transferType: Transfer.Type.Inbound,
            fromAddress: _makerAddress,
            toAddress: _makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        // Collateral token intra-issuance transfer: Maker --> Custodian
        transfers.actions[1] = Transfer.Data({
            transferType: Transfer.Type.IntraIssuance,
            fromAddress: _makerAddress,
            toAddress: Constants.getCustodianAddress(),
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        transfersData = Transfers.encode(transfers);
        // Create payable 1: Custodian --> Maker
        _supplementalLineItems.push(SupplementalLineItem.Data({
            id: 1,
            lineItemType: SupplementalLineItem.Type.Payable,
            state: SupplementalLineItem.State.Unpaid,
            obligatorAddress: Constants.getCustodianAddress(),
            claimorAddress: _makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount,
            dueTimestamp: _engagementDueTimestamp,
            reinitiatedTo: 0
        }));
    }

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(address callerAddress, bytes memory /** takerParameters */) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Engageable, "Issuance not in Engageable");

        // Validates borrowing balance
        uint256 borrowingBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress, _borrowingTokenAddress);
        require(borrowingBalance >= _borrowingAmount, "Insufficient borrowing balance");

        // Sets common properties
        _takerAddress = callerAddress;
        _engagementTimestamp = now;
        _issuanceDueTimestamp = now + _tenorDays * 1 days;

        // Emits Scheduled Borrowing Due event
        emit EventTimeScheduled(_issuanceId, _issuanceDueTimestamp, ISSUANCE_DUE_EVENT, "");

        // Emits Borrowing Engaged event
        emit BorrowingEngaged(_issuanceId, _takerAddress, _issuanceDueTimestamp);

        // Transition to Engaged state.
        _state = IssuanceProperties.State.Engaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](3));
        // Principal token inbound transfer: Taker
        transfers.actions[0] = Transfer.Data({
            transferType: Transfer.Type.Inbound,
            fromAddress: _takerAddress,
            toAddress: _takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount
        });
        // Principal token intra-issuance transfer: Taker --> Maker
        transfers.actions[1] = Transfer.Data({
            transferType: Transfer.Type.IntraIssuance,
            fromAddress: _takerAddress,
            toAddress: _makerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount
        });
        // Create payable 2: Maker --> Taker
         _supplementalLineItems.push(SupplementalLineItem.Data({
            id: 2,
            lineItemType: SupplementalLineItem.Type.Payable,
            state: SupplementalLineItem.State.Unpaid,
            obligatorAddress: _makerAddress,
            claimorAddress: _takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount,
            dueTimestamp: _issuanceDueTimestamp,
            reinitiatedTo: 0
        }));
        // Create payable 3: Maker --> Taker
         _supplementalLineItems.push(SupplementalLineItem.Data({
            id: 3,
            lineItemType: SupplementalLineItem.Type.Payable,
            state: SupplementalLineItem.State.Unpaid,
            obligatorAddress: _makerAddress,
            claimorAddress: _takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _interestAmount,
            dueTimestamp: _issuanceDueTimestamp,
            reinitiatedTo: 0
        }));
        // Create payable 4: Custodian --> Maker
        _supplementalLineItems.push(SupplementalLineItem.Data({
            id: 4,
            lineItemType: SupplementalLineItem.Type.Payable,
            state: SupplementalLineItem.State.Unpaid,
            obligatorAddress: Constants.getCustodianAddress(),
            claimorAddress: _makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount,
            dueTimestamp: _issuanceDueTimestamp,
            reinitiatedTo: 0
        }));
        // Mark payable 1 as reinitiated by payable 4
        _supplementalLineItems[0].state = SupplementalLineItem.State.Reinitiated;
        _supplementalLineItems[0].reinitiatedTo = 4;
        // Principal token outbound transfer: Taker
        transfers.actions[2] = Transfer.Data({
            transferType: Transfer.Type.Outbound,
            fromAddress: _makerAddress,
            toAddress: _makerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param callerAddress Address which invokes this function.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(address callerAddress, address tokenAddress, uint256 amount) public returns (bytes memory transfersData) {
        // Important: Token deposit can happen only in repay!
        require(_state == IssuanceProperties.State.Engaged, "Issuance not in Engaged");
        require(callerAddress == _makerAddress, "Only maker can repay");
        require(tokenAddress == _borrowingTokenAddress, "Must repay with borrowing token");
        require(amount == _borrowingAmount + _interestAmount, "Must repay in full");

        // Sets common properties
        _settlementTimestamp = now;

        // Emits Borrowing Repaid event
        emit BorrowingRepaid(_issuanceId);

        // Updates to Complete Engaged state.
        _state = IssuanceProperties.State.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](4));
        // Principal token intra-issuance transfer: Maker --> Taker
        transfers.actions[0] = Transfer.Data({
            transferType: Transfer.Type.IntraIssuance,
            fromAddress: _makerAddress,
            toAddress: _takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount + _interestAmount
        });
        // Mark payable 2 & 3 as paid
        _supplementalLineItems[1].state = SupplementalLineItem.State.Paid;
        _supplementalLineItems[2].state = SupplementalLineItem.State.Paid;
        // Collateral token intra-issuance transfer: Custodian --> Maker
        transfers.actions[1] = Transfer.Data({
            transferType: Transfer.Type.IntraIssuance,
            fromAddress: Constants.getCustodianAddress(),
            toAddress: _makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        // Mark payable 4 as paid
        _supplementalLineItems[4].state = SupplementalLineItem.State.Paid;
        // Collateral token outbound transfer: Maker
        transfers.actions[2] = Transfer.Data({
            transferType: Transfer.Type.Outbound,
            fromAddress: _makerAddress,
            toAddress: _makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        // Principal token outbound transfer: Taker
        transfers.actions[3] = Transfer.Data({
            transferType: Transfer.Type.Outbound,
            fromAddress: _takerAddress,
            toAddress: _takerAddress,
            tokenAddress: _borrowingTokenAddress,
            amount: _borrowingAmount + _interestAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev A custom event is triggered.
     * @param callerAddress Address which invokes this function.
     * @param eventName The name of the custom event.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(address callerAddress, bytes32 eventName, bytes memory /** eventPayload */) public
        returns (bytes memory transfersData) {

        if (eventName == ENGAGEMENT_DUE_EVENT) {
            // Engagement Due will be processed only when:
            // 1. Issuance is in Engageable state
            // 2. Engagement due timestamp is passed
            if (_state == IssuanceProperties.State.Engageable && now >= _engagementDueTimestamp) {
                // Emits Borrowing Complete Not Engaged event
                emit BorrowingCompleteNotEngaged(_issuanceId);

                // Updates to Complete Not Engaged state
                _state = IssuanceProperties.State.CompleteNotEngaged;

                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
                // Collateral token intra-issuance transfer: Custodian --> Maker
                transfers.actions[0] = Transfer.Data({
                    transferType: Transfer.Type.IntraIssuance,
                    fromAddress: Constants.getCustodianAddress(),
                    toAddress: _makerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                // Mark payable 1 as paid
                _supplementalLineItems[0].state = SupplementalLineItem.State.Paid;
                // Collateral token outbound transfer: Maker
                transfers.actions[1] = Transfer.Data({
                    transferType: Transfer.Type.Outbound,
                    fromAddress: _makerAddress,
                    toAddress: _makerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                transfersData = Transfers.encode(transfers);
            }
        } else if (eventName == ISSUANCE_DUE_EVENT) {
            // Borrowing Due will be processed only when:
            // 1. Issuance is in Engaged state
            // 2. Borrowing due timestamp has passed
            if (_state == IssuanceProperties.State.Engaged && now >= _issuanceDueTimestamp) {
                // Emits Borrowing Deliquent event
                emit BorrowingDelinquent(_issuanceId);

                // Updates to Delinquent state
                _state = IssuanceProperties.State.Delinquent;

                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](3));
                // Collateral token intra-issuance transfer: Custodian --> Maker
                transfers.actions[0] = Transfer.Data({
                    transferType: Transfer.Type.IntraIssuance,
                    fromAddress: Constants.getCustodianAddress(),
                    toAddress: _makerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                // Mark payable 4 as paid
                _supplementalLineItems[4].state = SupplementalLineItem.State.Paid;
                // Collateral token intra-issuance transfer: Maker --> Taker
                transfers.actions[0] = Transfer.Data({
                    transferType: Transfer.Type.IntraIssuance,
                    fromAddress: _makerAddress,
                    toAddress: _takerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                // Collateral token outbound transfer: Taker
                transfers.actions[2] = Transfer.Data({
                    transferType: Transfer.Type.Outbound,
                    fromAddress: _takerAddress,
                    toAddress: _takerAddress,
                    tokenAddress: _collateralTokenAddress,
                    amount: _collateralAmount
                });
                transfersData = Transfers.encode(transfers);
            }
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            // Cancel Issuance must be processed in Engageable state
            require(_state == IssuanceProperties.State.Engageable, "Cancel issuance not in engageable state");
            // Only maker can cancel issuance
            require(callerAddress == _makerAddress, "Only maker can cancel issuance");

            // Emits Borrowing Cancelled event
            emit BorrowingCancelled(_issuanceId);

            // Updates to Cancelled state.
            _state = IssuanceProperties.State.Cancelled;

            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
            // Collateral token intra-issuance transfer: Custodian --> Maker
            transfers.actions[0] = Transfer.Data({
                transferType: Transfer.Type.IntraIssuance,
                fromAddress: Constants.getCustodianAddress(),
                toAddress: _makerAddress,
                tokenAddress: _collateralTokenAddress,
                amount: _collateralAmount
            });
            // Mark payable 1 as paid
            _supplementalLineItems[0].state = SupplementalLineItem.State.Paid;
            // Collateral token outbound transfer: Maker
            transfers.actions[1] = Transfer.Data({
                transferType: Transfer.Type.Outbound,
                fromAddress: _makerAddress,
                toAddress: _makerAddress,
                tokenAddress: _collateralTokenAddress,
                amount: _collateralAmount
            });
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
        if (dataName == BORROWING_DATA) {
            BorrowingProperties.Data memory borrowingProperties = BorrowingProperties.Data({
                borrowingTokenAddress: _borrowingTokenAddress,
                collateralTokenAddress: _collateralTokenAddress,
                borrowingAmount: _borrowingAmount,
                collateralRatio: _collateralRatio,
                collateralAmount: _collateralAmount,
                interestRate: _interestRate,
                interestAmount: _interestAmount,
                tenorDays: _tenorDays
            });

            BorrowingCompleteProperties.Data memory borrowingCompleteProperties = BorrowingCompleteProperties.Data({
                issuanceProperties: getIssuanceProperties(),
                borrowingProperties: borrowingProperties
            });

            return BorrowingCompleteProperties.encode(borrowingCompleteProperties);
        } else {
            revert('Unknown data');
        }
    }
}