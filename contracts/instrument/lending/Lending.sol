pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LendingData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/protobuf/StandardizedNonTokenLineItem.sol";
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
        uint256 principalTokenBalance = EscrowBaseInterface(_instrumentEscrowAddress)
            .getTokenBalance(_makerAddress, makerParameters.lendingTokenAddress);
        require(principalTokenBalance >= makerParameters.lendingAmount, "Insufficient principal balance");

        // Sets common properties
        _makerAddress = callerAddress;
        _creationTimestamp = now;
        _engagementDueTimestamp = now + ENGAGEMENT_DUE_DAYS;
        _state = IssuanceProperties.State.Engageable;
 
        // Sets lending properties
        _lendingTokenAddress = makerParameters.lendingTokenAddress;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _lendingAmount = makerParameters.lendingAmount;
        _tenorDays = makerParameters.tenorDays;
        _interestRate = makerParameters.interestRate;
        _interestAmount = _lendingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;

        // Emits Scheduled Engagement Due event
        emit EventTimeScheduled(_issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

        // Emits Lending Created event
        emit LendingCreated(_issuanceId, _makerAddress, _issuanceEscrowAddress,
            _collateralTokenAddress, _lendingTokenAddress, _lendingAmount, _collateralRatio, _engagementDueTimestamp);

        // Transfers principal token from maker(Instrument Escrow) to maker(Issuance Escrow).
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: _makerAddress,
            toAddress: _makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(address callerAddress, bytes memory /** takerParameters */) public returns (bytes memory transfersData) {
        require(_state == IssuanceProperties.State.Engageable, "Issuance not in Engageable");
        // Sets common properties
        _takerAddress = callerAddress;
        _engagementTimestamp = now;
        _issuanceDueTimestamp = now + _tenorDays * 1 days;

        // Calculate the collateral amount. Collateral is calculated at the time of engagement.
        PriceOracleInterface priceOracle = PriceOracleInterface(_priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(_lendingTokenAddress, _collateralTokenAddress);
        require(numerator > 0 && denominator > 0, "Exchange rate not found");
        _collateralAmount = denominator.mul(_lendingAmount).mul(_collateralRatio).div(COLLATERAL_RATIO_DECIMALS).div(numerator);

        // Validates collateral balance
        uint256 collateralBalance = EscrowBaseInterface(_instrumentEscrowAddress)
            .getTokenBalance(_takerAddress, _collateralTokenAddress);
        require(collateralBalance >= _collateralAmount, "Insufficient collateral balance");

        // Emits Scheduled Lending Due event
        emit EventTimeScheduled(_issuanceId, _issuanceDueTimestamp, ISSUANCE_DUE_EVENT, "");

        // Emits Lending Engaged event
        emit LendingEngaged(_issuanceId, _takerAddress, _issuanceDueTimestamp,
            _collateralAmount);

        // Transition to Engaged state.
        _state = IssuanceProperties.State.Engaged;

        // Create liabilities
        // Liability.Data memory liabilities1 = Liability.Data({
        //     id: 1,
        //     liabilityType: Liability.Type.Payable,
        //     obligator: Liability.Role.CollateralCustodian,
        //     claimor: Liability.Role.Taker,
        //     tokenAddress: _collateralTokenAddress,
        //     amount: _collateralAmount,
        //     dueTimestamp: _lendingDueTimestamp,
        //     paidOff: false
        // });
        // _liabilities.push(liabilities1);
        // Liability.Data memory liabilities2 = Liability.Data({
        //     id: 2,
        //     liabilityType: Liability.Type.Payable,
        //     obligator: Liability.Role.Taker,
        //     claimor: Liability.Role.Maker,
        //     tokenAddress: _lendingTokenAddress,
        //     amount: _lendingAmount,
        //     dueTimestamp: _lendingDueTimestamp,
        //     paidOff: false
        // });
        // _liabilities.push(liabilities2);
        // Liability.Data memory liabilities3 = Liability.Data({
        //     id: 3,
        //     liabilityType: Liability.Type.Payable,
        //     obligator: Liability.Role.Taker,
        //     claimor: Liability.Role.Maker,
        //     tokenAddress: _lendingTokenAddress,
        //     amount: _interestAmount,
        //     dueTimestamp: _lendingDueTimestamp,
        //     paidOff: false
        // });
        // _liabilities.push(liabilities3);

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers collateral token from taker(Instrument Escrow) to taker(Issuance Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: false,
            inbound: true,
            fromAddress: _takerAddress,
            toAddress: _takerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        // Transfers lending token from maker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: _makerAddress,
            toAddress: _takerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
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
        require(callerAddress == _takerAddress, "Only taker can repay");
        require(tokenAddress == _lendingTokenAddress, "Must repay with lending token");
        require(amount == _lendingAmount + _interestAmount, "Must repay in full");

        // Emits Lending Repaid event
        emit LendingRepaid(_issuanceId);
        _settlementTimestamp = now;

        // Updates to Complete Engaged state.
        _state = IssuanceProperties.State.CompleteEngaged;

        // Updates liabilities
        // _liabilities[0].paidOff = true;
        // _liabilities[1].paidOff = true;
        // _liabilities[2].paidOff = true;

        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfers lending amount + interest from taker(Issuance Escrow) to maker(Instrument Escrow).
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: _takerAddress,
            toAddress: _makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount + _interestAmount
        });
        // Transfers collateral from taker(Issuance Escrow) to taker(Instrument Escrow).
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            inbound: false,
            fromAddress: _takerAddress,
            toAddress: _takerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
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
                // Emits Lending Complete Not Engaged event
                emit LendingCompleteNotEngaged(_issuanceId);

                // Updates to Complete Not Engaged state
                _state = IssuanceProperties.State.CompleteNotEngaged;

                // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: _makerAddress,
                    toAddress: _makerAddress,
                    tokenAddress: _lendingTokenAddress,
                    amount: _lendingAmount
                });
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

                // Transfers collateral token from taker(Issuance Escrow) to maker(Instrument Escrow).
                Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
                transfers.actions[0] = Transfer.Data({
                    outbound: true,
                    inbound: false,
                    fromAddress: _takerAddress,
                    toAddress: _makerAddress,
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

            // Emits Lending Cancelled event
            emit LendingCancelled(_issuanceId);

            // Updates to Cancelled state.
            _state = IssuanceProperties.State.Cancelled;

            // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
            Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
            transfers.actions[0] = Transfer.Data({
                outbound: true,
                inbound: false,
                fromAddress: _makerAddress,
                toAddress: _makerAddress,
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
     * @param dataName The name of the custom data.
     * @return customData The custom data of the issuance.
     */
    function readCustomData(address /** callerAddress */, bytes32 dataName) public view returns (bytes memory) {
        if (dataName == LENDING_DATA) {
            IssuanceProperties.Data memory issuanceProperties = IssuanceProperties.Data({
                issuanceId: _issuanceId,
                makerAddress: _makerAddress,
                takerAddress: _takerAddress,
                engagementDueTimestamp: _engagementDueTimestamp,
                issuanceDueTimestamp: _issuanceDueTimestamp,
                creationTimestamp: _creationTimestamp,
                engagementTimestamp: _engagementTimestamp,
                settlementTimestamp: _settlementTimestamp,
                issuanceEscrowAddress: _issuanceEscrowAddress,
                state: _state,
                nonTokenLineItems: _standardizedNonTokenLineItems
            });

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
                issuanceProperties: issuanceProperties,
                lendingProperties: lendingProperties
            });

            return LendingCompleteProperties.encode(lendingCompleteProperties);
        } else {
            revert('Unknown data');
        }
    }
}