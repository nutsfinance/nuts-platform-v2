pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LendingData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/token/IERC20.sol";
import "../../lib/util/Constants.sol";
import "../../lib/util/StringUtil.sol";
import "../../instrument/v3/InstrumentV3.sol";

contract Lending is InstrumentV3 {
    using SafeMath for uint256;
    using StringUtil for string;

    event LendingCreated(uint256 indexed issuanceId, address indexed makerAddress, address escrowAddress,
        address collateralTokenAddress, address lendingTokenAddress, uint256 lendingAmount,
        uint256 collateralRatio, uint256 engagementDueTimestamp);

    event LendingEngaged(uint256 indexed issuanceId, address indexed takerAddress, uint256 lendingDueTimstamp,
        uint256 collateralTokenAmount);

    event LendingRepaid(uint256 indexed issuanceId);

    event LendingCompleteNotEngaged(uint256 indexed issuanceId);

    event LendingDelinquent(uint256 indexed issuanceId);

    // Constants
    uint256 constant ENGAGEMENT_DUE_DAYS = 30 days;             // Time available for taker to engage
    uint256 constant COLLATERAL_RATIO_DECIMALS = 4;             // 0.01%
    uint256 constant INTEREST_RATE_DECIMALS = 6;                // 0.0001%

    // Scheduled event list
    bytes32 constant ENGAGEMENT_DUE_EVENT = "engagement_due";
    bytes32 constant LENDING_DUE_EVENT = "lending_due";

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

        // Transfers principal token from Instrument Escrow to Issuance Escrow.
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
        _collateralAmount = numerator.mul(_lendingAmount).mul(_collateralRatio).div(COLLATERAL_RATIO_DECIMALS).div(denominator);

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

        // Transfers collateral token from Instrument Escrow to Issuance Escrow.
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _collateralAmount
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
        // Transfers lending amount + interest to maker.
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount + _interestAmount
        });
        // Transfers collateral to taker.
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
            // Engagement Due must be processed in Engageable state
            require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable, "Engagement due not in engageable state");
            // Engagement Due must be processed after engagement due timestamp
            require(now >= _engagementDueTimestamp, "Engagement not due");

            // Emits Lending Complete Not Engaged event
            emit LendingCompleteNotEngaged(issuanceParameters.issuanceId);

            // Updates to Complete Not Engaged state
            updatedState = IssuanceStates.CompleteNotEngaged;

            // Transfers principal token from Issuance Escrow to Instrument Escrow
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

        } else if (eventName == LENDING_DUE_EVENT) {
            // Lending Due must be processed in Engaged state
            require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged, "Lending due not in engaged state");
            // Lending Due must be processed after lending due timestamp
            require(now >= _lendingDueTimestamp, "Lending not due");

            // Emits Lending Deliquent event
            emit LendingDelinquent(issuanceParameters.issuanceId);

            // Updates to Delinquent state
            updatedState = IssuanceStates.Delinquent;

            // Transfers collateral token from Issuance Escrow to Instrument Escrow.
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: issuanceParameters.takerAddress,
                toAddress: issuanceParameters.makerAddress,
                tokenAddress: _lendingTokenAddress,
                amount: _collateralAmount
            });
            transfersData = Transfers.encode(transfers);
        } else {
            revert("Unknown event");
        }
    }
}