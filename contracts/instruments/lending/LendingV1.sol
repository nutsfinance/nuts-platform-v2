pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LendingData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../instrument/v1/InstrumentV1.sol";
import "./LendingBase.sol";

contract LendingV1 is InstrumentV1, LendingBase {
    using SafeMath for uint256;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData) {

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
        LendingData.Data memory lendingData;
        lendingData.lendingTokenAddress = makerParameters.lendingTokenAddress;
        lendingData.collateralTokenAddress = makerParameters.collateralTokenAddress;
        lendingData.lendingAmount = makerParameters.lendingAmount;
        lendingData.tenorDays = makerParameters.tenorDays;
        lendingData.collateralRatio = makerParameters.collateralRatio;
        lendingData.interestAmount = makerParameters.lendingAmount.mul(makerParameters.tenorDays)
            .mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        lendingData.engagementDueTimestamp = now + ENGAGEMENT_DUE_DAYS;

        // Emits Scheduled Engagement Due event
        emit EventTimeScheduled(issuanceParameters.issuanceId, lendingData.engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Lending Created event
        emit LendingCreated(issuanceParameters.issuanceId, issuanceParameters.makerAddress, issuanceParameters.issuanceEscrowAddress,
            lendingData.collateralTokenAddress, lendingData.lendingTokenAddress, lendingData.lendingAmount,
            lendingData.collateralRatio, lendingData.engagementDueTimestamp);

        // Updates to Engageable state.
        updatedState = IssuanceStates.Engageable;
        updatedData = LendingData.encode(lendingData);

        // Transfers principal token from maker(Instrument Escrow) to maker(Issuance Escrow).
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: lendingData.lendingTokenAddress,
            amount: lendingData.lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param data The custom data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData, bytes memory /** takerParameters */, bytes memory data) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        LendingData.Data memory lendingData = LendingData.decode(data);

        // Calculate the collateral amount. Collateral is calculated at the time of engagement.
        PriceOracleInterface priceOracle = PriceOracleInterface(issuanceParameters.priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(lendingData.lendingTokenAddress, lendingData.collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        lendingData.collateralAmount = denominator.mul(lendingData.lendingAmount).mul(lendingData.collateralRatio)
            .div(COLLATERAL_RATIO_DECIMALS).div(numerator);

        // Validates collateral balance
        uint256 collateralBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
            .getTokenBalance(issuanceParameters.takerAddress, lendingData.collateralTokenAddress);
        require(collateralBalance >= lendingData.collateralAmount, "Insufficient collateral balance");

        // Emits Scheduled Lending Due event
        lendingData.lendingDueTimestamp = now + lendingData.tenorDays * 1 days;
        emit EventTimeScheduled(issuanceParameters.issuanceId, lendingData.lendingDueTimestamp, LENDING_DUE_EVENT, "");

        // Emits Lending Engaged event
        emit LendingEngaged(issuanceParameters.issuanceId, issuanceParameters.takerAddress, lendingData.lendingDueTimestamp,
            lendingData.collateralAmount);

        // Transition to Engaged state.
        updatedState = IssuanceStates.Engaged;
        updatedData = LendingData.encode(lendingData);

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers collateral token from taker(Instrument Escrow) to taker(Issuance Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: lendingData.collateralTokenAddress,
            amount: lendingData.collateralAmount
        });
        // Transfers lending token from maker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: lendingData.lendingTokenAddress,
            amount: lendingData.lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount, bytes memory data) public
        returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        LendingData.Data memory lendingData = LendingData.decode(data);

        // Important: Token deposit can happen only in repay!
        require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged, "Must repay in engaged state");
        require(issuanceParameters.callerAddress == issuanceParameters.takerAddress, "Only taker can repay");
        require(tokenAddress == lendingData.lendingTokenAddress, "Must repay with lending token");
        require(amount == lendingData.lendingAmount + lendingData.interestAmount, "Must repay in full");

        // Emits Lending Repaid event
        emit LendingRepaid(issuanceParameters.issuanceId);

        // Updates to Complete Engaged state.
        updatedState = IssuanceStates.CompleteEngaged;
        updatedData = data;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers lending amount + interest from taker(Issuance Escrow) to maker(Instrument Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: lendingData.lendingTokenAddress,
            amount: lendingData.lendingAmount + lendingData.interestAmount
        });
        // Transfers collateral from taker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: lendingData.collateralTokenAddress,
            amount: lendingData.collateralAmount
        });
        transfersData = Transfers.encode(transfers);
    }


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     */
    function processTokenWithdraw(bytes memory /* issuanceParametersData */, address /* tokenAddress */, uint256 /* amount */,
        bytes memory /** data */) public returns (IssuanceStates, bytes memory, bytes memory) {
        revert("Withdrawal not supported.");
    }

    /**
     * @dev A custom event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @param data The data for this issuance
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory /** eventPayload */, bytes memory data)
        public returns (IssuanceStates updatedState, bytes memory updatedData, bytes memory transfersData) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        LendingData.Data memory lendingData = LendingData.decode(data);

        if (eventName == ENGAGEMENT_DUE_EVENT) {
            // Engagement Due will be processed only when:
            // 1. Issuance is in Engageable state
            // 2. Engagement due timestamp is passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable && now >= lendingData.engagementDueTimestamp) {
                // Emits Lending Complete Not Engaged event
                emit LendingCompleteNotEngaged(issuanceParameters.issuanceId);

                // Updates to Complete Not Engaged state
                updatedState = IssuanceStates.CompleteNotEngaged;
                updatedData = data;

                // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.makerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: lendingData.lendingTokenAddress,
                    amount: lendingData.lendingAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not processed Engagement Due event
                updatedState = IssuanceStates(issuanceParameters.state);
                updatedData = data;
            }
        } else if (eventName == LENDING_DUE_EVENT) {
            // Lending Due will be processed only when:
            // 1. Issuance is in Engaged state
            // 2. Lending due timestamp has passed
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged && now >= lendingData.lendingDueTimestamp) {
                // Emits Lending Deliquent event
                emit LendingDelinquent(issuanceParameters.issuanceId);

                // Updates to Delinquent state
                updatedState = IssuanceStates.Delinquent;
                updatedData = data;

                // Transfers collateral token from taker(Issuance Escrow) to maker(Instrument Escrow).
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: issuanceParameters.takerAddress,
                    toAddress: issuanceParameters.makerAddress,
                    tokenAddress: lendingData.collateralTokenAddress,
                    amount: lendingData.collateralAmount
                });
                transfersData = Transfers.encode(transfers);
            } else {
                // Not process Lending Due event
                updatedState = IssuanceStates(issuanceParameters.state);
                updatedData = data;
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
            updatedData = data;

            // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: issuanceParameters.makerAddress,
                toAddress: issuanceParameters.makerAddress,
                tokenAddress: lendingData.lendingTokenAddress,
                amount: lendingData.lendingAmount
            });
            transfersData = Transfers.encode(transfers);

        } else {
            revert("Unknown event");
        }
    }

    /**
     * @dev Read custom data.
     */
    function readCustomData(bytes memory /** issuanceParametersData */, bytes32 /** dataName */,
        bytes memory /** data */) public view returns (bytes memory) {
        revert('Unsupported operation.');
    }
}