pragma solidity 0.5.16;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LendingData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/SupplementalLineItem.sol";
import "../../lib/util/Constants.sol";
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

    // Custom data
    bytes32 constant internal LENDING_DATA = "lending_data";

    // Lending parameters
    address private _lendingTokenAddress;
    address private _collateralTokenAddress;
    uint256 private _lendingAmount;
    uint256 private _tenorDays;
    uint256 private _collateralRatio;
    uint256 private _collateralAmount;
    uint256 private _interestRate;
    uint256 private _interestAmount;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param callerAddress Address which invokes this function.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(address callerAddress, bytes memory makerParametersData) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Initiated, "Issuance not in Initiated");
        LendingMakerParameters.Data memory makerParameters = LendingMakerParameters.decode(makerParametersData);

        // Validates parameters.
        require(makerParameters.collateralTokenAddress != address(0x0), "Collateral token not set");
        require(makerParameters.lendingTokenAddress != address(0x0), "Lending token not set");
        require(makerParameters.lendingAmount > 0, "Lending amount not set");
        require(makerParameters.tenorDays >= 2 && makerParameters.tenorDays <= 90, "Invalid tenor days");
        require(makerParameters.collateralRatio >= 5000 && makerParameters.collateralRatio <= 20000, "Invalid collateral ratio");
        require(makerParameters.interestRate >= 10 && makerParameters.interestRate <= 50000, "Invalid interest rate");

        // Validate principal token balance
        uint256 principalTokenBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress,
            makerParameters.lendingTokenAddress);
        require(principalTokenBalance >= makerParameters.lendingAmount, "Insufficient principal balance");

        // Sets common properties
        _makerAddress = callerAddress;
        _creationTimestamp = now;
        _engagementDueTimestamp = now.add(ENGAGEMENT_DUE_DAYS);

        // Sets lending properties
        _lendingTokenAddress = makerParameters.lendingTokenAddress;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _lendingAmount = makerParameters.lendingAmount;
        _tenorDays = makerParameters.tenorDays;
        _interestRate = makerParameters.interestRate;
        _interestAmount = _lendingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;

        // Updates to Engageable state
        _state = IssuanceProperties.State.Engageable;

        // Emits Scheduled Engagement Due event
        emit EventTimeScheduled(_issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Lending Created event
        emit LendingCreated(_issuanceId, _makerAddress, _issuanceEscrowAddress,
            _collateralTokenAddress, _lendingTokenAddress, _lendingAmount, _collateralRatio, _engagementDueTimestamp);

        // Transfers principal token
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Principal token inbound transfer: Maker
        transfers.actions[0] = _createInboundTransfer(_makerAddress, _lendingTokenAddress, _lendingAmount);
        // Principal token intra-issuance transfer: Maker --> Custodian
        transfers.actions[1] = _createIntraIssuanceTransfer(_makerAddress, Constants.getCustodianAddress(),
            _lendingTokenAddress, _lendingAmount);
        transfersData = Transfers.encode(transfers);
        // Create payable 1: Custodian --> Maker
        _createNewPayable(1, Constants.getCustodianAddress(), _makerAddress, _lendingTokenAddress, _lendingAmount, _engagementDueTimestamp);
    }

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(address callerAddress, bytes memory /** takerParameters */) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Engageable, "Issuance not in Engageable");

        // Calculate the collateral amount. Collateral is calculated at the time of engagement.
        PriceOracleInterface priceOracle = PriceOracleInterface(_priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(_lendingTokenAddress, _collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        uint256 collateralAmount = numerator.mul(_lendingAmount).mul(_collateralRatio).div(COLLATERAL_RATIO_DECIMALS).div(denominator);

        // Validates collateral balance
        uint256 collateralBalance = EscrowBaseInterface(_instrumentEscrowAddress).getTokenBalance(callerAddress, _collateralTokenAddress);
        require(collateralBalance >= collateralAmount, "Insufficient collateral balance");

        // Sets common properties
        _takerAddress = callerAddress;
        _engagementTimestamp = now;
        _issuanceDueTimestamp = now.add(_tenorDays * 1 days);

        // Sets lending properties
        _collateralAmount = collateralAmount;

        // Emits Scheduled Lending Due event
        emit EventTimeScheduled(_issuanceId, _issuanceDueTimestamp, ISSUANCE_DUE_EVENT, "");

        // Emits Lending Engaged event
        emit LendingEngaged(_issuanceId, _takerAddress, _issuanceDueTimestamp, _collateralAmount);

        // Transition to Engaged state.
        _state = IssuanceProperties.State.Engaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](5));
        // Collateral token inbound transfer: Taker
        transfers.actions[0] = _createInboundTransfer(_takerAddress, _collateralTokenAddress, _collateralAmount);
        // Collateral token intra-issuance transfer: Taker --> Custodian
        transfers.actions[1] = _createIntraIssuanceTransfer(_takerAddress, Constants.getCustodianAddress(),
            _collateralTokenAddress, _collateralAmount);
        // Create payable 2: Custodian --> Taker
        _createNewPayable(2, Constants.getCustodianAddress(), _takerAddress, _collateralTokenAddress, _collateralAmount, _issuanceDueTimestamp);
        // Principal token intra-issuance transfer: Custodian --> Maker
        transfers.actions[2] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress,
            _lendingTokenAddress, _lendingAmount);
        // Principal token intra-issuance transfer: Maker --> Taker
        transfers.actions[3] = _createIntraIssuanceTransfer(_makerAddress, _takerAddress, _lendingTokenAddress, _lendingAmount);
        // Create payable 3: Taker --> Maker
        _createNewPayable(3, _takerAddress, _makerAddress, _lendingTokenAddress, _lendingAmount, _issuanceDueTimestamp);
        // Create payable 4: Taker --> Maker
        _createNewPayable(4, _takerAddress, _makerAddress, _lendingTokenAddress, _interestAmount, _issuanceDueTimestamp);
        // Mark payable 1 as reinitiated by payable 4
        _updatePayable(1, SupplementalLineItem.State.Reinitiated, 4);
        // Principal token outbound transfer: Taker
        transfers.actions[4] = _createOutboundTransfer(_takerAddress, _lendingTokenAddress, _lendingAmount);
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
        require(callerAddress == _takerAddress, "Only taker can repay");
        require(tokenAddress == _lendingTokenAddress, "Must repay with lending token");
        require(amount == _lendingAmount + _interestAmount, "Must repay in full");

        // Sets common properties
        _settlementTimestamp = now;

        // Emits Lending Repaid event
        emit LendingRepaid(_issuanceId);

        // Updates to Complete Engaged state.
        _state = IssuanceProperties.State.CompleteEngaged;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](4));
        // Principal token intra-issuance transfer: Taker --> Maker
        transfers.actions[0] = _createIntraIssuanceTransfer(_takerAddress, _makerAddress, _lendingTokenAddress,
            _lendingAmount + _interestAmount);
        // Mark payable 3 & 4 as paid
        _updatePayable(3, SupplementalLineItem.State.Paid, 0);
        _updatePayable(4, SupplementalLineItem.State.Paid, 0);
        // Collateral token intra-issuance transfer: Custodian --> Taker
        transfers.actions[1] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _takerAddress,
            _collateralTokenAddress, _collateralAmount);
        // Mark payable 2 as paid
        _updatePayable(2, SupplementalLineItem.State.Paid, 0);
        // Collateral token outbound transfer: Taker
        transfers.actions[2] = _createOutboundTransfer(_takerAddress, _collateralTokenAddress, _collateralAmount);
        // Principal token outbound transfer: Maker
        transfers.actions[3] = _createOutboundTransfer(_makerAddress, _lendingTokenAddress, _lendingAmount + _interestAmount);
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
                // Emits Lending Complete Not Engaged event
                emit LendingCompleteNotEngaged(_issuanceId);

                // Updates to Complete Not Engaged state
                _state = IssuanceProperties.State.CompleteNotEngaged;

                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
                // Principal token intra-issuance transfer: Custodian --> Maker
                transfers.actions[0] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress, _lendingTokenAddress, _lendingAmount);
                // Mark payable 1 as paid
                _updatePayable(1, SupplementalLineItem.State.Paid, 0);
                // Principal token outbound transfer: Maker
                transfers.actions[1] = _createOutboundTransfer(_makerAddress, _lendingTokenAddress, _lendingAmount);
                transfersData = Transfers.encode(transfers);
            }
        } else if (eventName == ISSUANCE_DUE_EVENT) {
            // Lending Due will be processed only when:
            // 1. Issuance is in Engaged state
            // 2. Lending due timestamp has passed
            if (_state == IssuanceProperties.State.Engaged && now >= _issuanceDueTimestamp) {
                // Emits Lending Deliquent event
                emit LendingDelinquent(_issuanceId);

                // Updates to Delinquent state
                _state = IssuanceProperties.State.Delinquent;

                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](3));
                // Collateral token intra-issuance transfer: Custodian --> Taker
                transfers.actions[0] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _takerAddress, _collateralTokenAddress, _collateralAmount);
                // Mark payable 2 as paid
                _updatePayable(2, SupplementalLineItem.State.Paid, 0);
                // Collateral token intra-issuance transfer: Taker --> Maker
                transfers.actions[1] = _createIntraIssuanceTransfer(_takerAddress, _makerAddress, _collateralTokenAddress, _collateralAmount);
                // Collateral token outbound transfer: Maker
                transfers.actions[2] = _createOutboundTransfer(_makerAddress, _collateralTokenAddress, _collateralAmount);
                transfersData = Transfers.encode(transfers);
            }
        } else if (eventName == CANCEL_ISSUANCE_EVENT) {
            // Cancel Issuance must be processed in Engageable state
            require(_state == IssuanceProperties.State.Engageable, "Cancel issuance not in engageable state");
            // Only maker can cancel issuance
            require(callerAddress == _makerAddress, "Only maker can cancel issuance");

            // Emits Lending Cancelled event
            emit LendingCancelled(_issuanceId);

            // Updates to Cancelled state.
            _state = IssuanceProperties.State.Cancelled;

            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
            // Principal token intra-issuance transfer: Custodian --> Maker
            transfers.actions[0] = _createIntraIssuanceTransfer(Constants.getCustodianAddress(), _makerAddress, _lendingTokenAddress, _lendingAmount);
            // Mark payable 1 as paid
            _updatePayable(1, SupplementalLineItem.State.Paid, 0);
            // Principal token outbound transfer: Maker
            transfers.actions[1] = _createOutboundTransfer(_makerAddress, _lendingTokenAddress, _lendingAmount);
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
        if (dataName == LENDING_DATA) {
            LendingProperties.Data memory lendingProperties = LendingProperties.Data({
                lendingTokenAddress: _lendingTokenAddress,
                collateralTokenAddress: _collateralTokenAddress,
                lendingAmount: _lendingAmount,
                collateralRatio: _collateralRatio,
                collateralAmount: _collateralAmount,
                interestRate: _interestRate,
                interestAmount: _interestAmount,
                tenorDays: _tenorDays
            });

            LendingCompleteProperties.Data memory lendingCompleteProperties = LendingCompleteProperties.Data({
                issuanceProperties: _getIssuanceProperties(),
                lendingProperties: lendingProperties
            });

            return LendingCompleteProperties.encode(lendingCompleteProperties);
        } else {
            revert('Unknown data');
        }
    }
}
