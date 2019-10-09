pragma solidity ^0.5.0;

import "../../escrow/EscrowBaseInterface.sol";
import "../../lib/math/SafeMath.sol";
import "../../lib/priceoracle/PriceOracleInterface.sol";
import "../../lib/protobuf/LoanData.sol";
import "../../lib/protobuf/InstrumentData.sol";
import "../../lib/protobuf/TokenTransfer.sol";
import "../../lib/token/IERC20.sol";
import "../../lib/util/Constants.sol";
import "../../lib/util/StringUtil.sol";
import "../../instrument/v3/InstrumentV3.sol";

contract LendingV1 is InstrumentV3 {
    using SafeMath for uint256;
    using StringUtil for string;

    // Constants
    uint256 constant PRINCIPAL_DUE_DAYS = 2 days;               // Time available for maker to deposit principal
    uint256 constant COLLATERAL_DUE_DAYS = 2 days;              // Time availabel for tabker to deposit collateral
    uint256 constant COLLATERAL_RATIO_DECIMALS = 4;             // 0.01%
    uint256 constant INTEREST_RATE_DECIMALS = 6;                // 0.0001%

    // Scheduled event list
    bytes32 constant PRINCIPAL_DUE_EVENT = "principal_due";
    bytes32 constant ENGAGEMENT_DUE_EVENT = "engagement_due";
    bytes32 constant COLLATERAL_DUE_EVENT = "collateral_due";
    bytes32 constant LENDING_DUE_EVENT = "lending_due";

    // Lending parameters
    address private _lendingTokenAddress;
    address private _collateralTokenAddress;
    uint256 private _principalDueTimestamp;
    uint256 private _engagementDueTimestamp;
    uint256 private _collateralDueTimestamp;
    uint256 private _lendingDueTimestamp;
    uint256 private _engagementDueDays;
    uint256 private _tenorDays;
    uint256 private _lendingAmount;
    uint256 private _collateralRatio;
    uint256 private _interestAmount;
    uint256 private _collateralAmount;
    bool private _collateralComplete;

    /**
     * @dev Create a new issuance of the financial instrument
     * @param issuanceParametersData Issuance Parameters.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return updatedState The new state of the issuance.
     */
    function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData) public
        returns (IssuanceStates updatedState) {

        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        MakerParameters.Data memory makerParameters = MakerParameters.decode(makerParametersData);

        // Validate parameters
        require(makerParameters.collateralTokenAddress != address(0x0), "LendingV1: Collateral token address must be set.");
        require(makerParameters.lendingTokenAddress != address(0x0), "LendingV1: Lending token address must be set.");
        require(makerParameters.lendingAmount > 0, "LoanV1: Lending amount must be set.");
        require(makerParameters.collateralRatio > 0, "LoanV1: Collateral ratio must be set.");
        require(makerParameters.engagementDueDays > 0, "LoanV1: Engagement due days must be set");
        require(makerParameters.tenorDays > COLLATERAL_DUE_DAYS, "LoanV1: Tenor days must be greater than 1.");

        // Update lending parameters
        _lendingTokenAddress = makerParameters.lendingTokenAddress;
        _collateralTokenAddress = makerParameters.collateralTokenAddress;
        _principalDueTimestamp = now + PRINCIPAL_DUE_DAYS;
        _engagementDueDays = makerParameters.engagementDueDays;
        _tenorDays = makerParameters.tenorDays;
        _lendingAmount = makerParameters.lendingAmount;
        _interestAmount = _lendingAmount.mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS);
        _collateralRatio = makerParameters.collateralRatio;

        // Scheduled Principal Due event
        emit EventTimeScheduled(issuanceParameters.issuanceId, _principalDueTimestamp, PRINCIPAL_DUE_EVENT, "");

        return IssuanceStates.Initiated;
    }

    /**
     * @dev A taker engages to the issuance
     * @param issuanceParametersData Issuance Parameters.
     * @return updatedState The new state of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(bytes memory issuanceParametersData, bytes memory /* takerParameters */) public
        returns (IssuanceStates updatedState, bytes memory) {
        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

        // Calculate the collateral amount. Collateral is calculated at the time of engagement.
        PriceOracleInterface priceOracle = PriceOracleInterface(issuanceParameters.priceOracleAddress);
        (uint256 numerator, uint256 denominator) = priceOracle.getRate(_lendingTokenAddress, _collateralTokenAddress);
        _collateralAmount = numerator.mul(_lendingAmount).mul(_collateralRatio).div(COLLATERAL_RATIO_DECIMALS).div(denominator);
        
        // Scheduled Collateral Due event
        _collateralDueTimestamp = now + COLLATERAL_DUE_DAYS;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _collateralDueTimestamp, COLLATERAL_DUE_EVENT, "");

        // Scheduled Lending Due event
        _lendingDueTimestamp = now + _tenorDays * 1 days;
        emit EventTimeScheduled(issuanceParameters.issuanceId, _lendingDueTimestamp, LENDING_DUE_EVENT, "");

        // Transition to Engaged state.
        updatedState = IssuanceStates.Engaged;
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
        updatedState = IssuanceStates(issuanceParameters.state);
        // Deposited token should be either lending token or collateral token.
        if (tokenAddress == _lendingTokenAddress) {
            // Lending token deposit can be either principal deposit or repay.
            if (issuanceParameters.callerAddress == issuanceParameters.makerAddress) {
                // Principal deposit should happen only in Initiated state.
                require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Initiated, "LoanV1: Principal deposit should occur only in Initiated state.");
                // Maker must deposit principal in full.
                require(amount == _lendingAmount, "LoanV1: Principal must be deposited in full.");

                // Transitioned to Engageable state.
                updatedState = IssuanceStates.Engageable;

                // Schedule Engagement Due event.
                _engagementDueTimestamp = now + _engagementDueDays * 1 days;
                emit EventTimeScheduled(issuanceParameters.issuanceId, _engagementDueTimestamp, ENGAGEMENT_DUE_EVENT, "");

            } else if (issuanceParameters.callerAddress == issuanceParameters.takerAddress) {
                // Principal deposit should happen only in Initiated state.
                require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged, "LoanV1: Principal deposit should occur only in Engaged state.");
                require(!_collateralComplete, "LoanV1: Collateral is not deposited.");

                // Taker must deposit lending amount + interest amount in full.
                require(amount == _lendingAmount + _interestAmount, "LoanV1: Taker must repay in full.");

                // Early termination
                updatedState = IssuanceStates.CompleteEngaged;
                // Transfer principal + interest to maker and transfer collater to taker.
                _release(issuanceParameters);
            } else {
                revert("LoanV1: Token depositer unsupported.");
            }
        } else if (tokenAddress == _collateralTokenAddress) {
            // Collateral token deposit can only be collateral deposit.
            require(!_collateralComplete, "LoanV1: Collateral is already deposited.");
            // Taker must deposit collateral in full.
            require(amount == _collateralAmount, "LoanV1: Collateral must be deposited in full.");
            
            _collateralComplete = true;
            // Transfer principal to taker.
            transfersData = _transferPrincipalToTaker(issuanceParameters);
        } else {
            revert("LoanV1: Token deposited unsupported.");
        }
    }


    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     */
    function processTokenWithdraw(bytes memory /* issuanceParametersData */, address /* tokenAddress */, uint256 /* amount */)
        public returns (IssuanceStates, bytes memory) {

        revert("LoanV1: Operation not supported.");
    }

    /**
     * @dev A custom event is triggered.
     */
    function processCustomEvent(bytes memory /* issuanceParametersData */, bytes32 /* eventName  */, bytes memory /* eventPayload */)
        public returns (IssuanceStates, bytes memory) {

        revert("LoanV1: Unsupported operation.");
    }

    /**
     * @dev A scheduled event is triggered.
     * @param issuanceParametersData Issuance Parameters.
     * @param eventName The name of the custom event.
     * @return updatedState The new state of the issuance.
     * @return updatedData The updated data of the issuance.
     * @return transfersData The transfers to perform after the invocation
     */
    function processScheduledEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory /* eventPayload */)
        public returns (IssuanceStates updatedState, bytes memory transfersData) {

        IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
        updatedState = IssuanceStates(issuanceParameters.state);
        if (eventName == PRINCIPAL_DUE_EVENT) {
            // Principal is due if the issuance is in Initiated state
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Initiated) {
                // Maker must deposit principal in full. Therefore, the maker principal token balance must be zero.
                updatedState = IssuanceStates.Unfunded;
            }
        } else if (eventName == ENGAGEMENT_DUE_EVENT) {
            // Engagement is due if the issuance is in Engageable state
            if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable) {
                updatedState = IssuanceStates.Unfunded;
                transfersData = _transferPrincipalToMaker(issuanceParameters);
            }
        } else if (eventName == COLLATERAL_DUE_EVENT) {
            // Collateral is due if _collateralComplete = false
            if (!_collateralComplete) {
                // Taker must deposit collateral in full. Therefore, the taker collateral token balance must be zero.
                updatedState = IssuanceStates.Delinquent;
                transfersData = _transferPrincipalToMaker(issuanceParameters);
            }
        } else if (eventName == LENDING_DUE_EVENT) {
            // Lending is due if the issuance is not in Complate Engaged state
            if (IssuanceStates(issuanceParameters.state) != IssuanceStates.CompleteEngaged) {
                // Transfer collateral to maker.
                transfersData = _transferCollateralToMaker(issuanceParameters);
            }
        }
    }

    function _transferPrincipalToMaker(IssuanceParameters.Data memory issuanceParameters) private view
        returns (bytes memory transfersData) {
        
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    function _transferPrincipalToTaker(IssuanceParameters.Data memory issuanceParameters) private view
        returns (bytes memory transfersData) {
        
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            fromAddress: issuanceParameters.makerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    function _transferCollateralToMaker(IssuanceParameters.Data memory issuanceParameters) private view
        returns (bytes memory transfersData) {
        
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        transfersData = Transfers.encode(transfers);
    }

    function _release(IssuanceParameters.Data memory issuanceParameters) private view
        returns (bytes memory transfersData) {
        Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
        // Transfer lending amount + interest to maker.
        transfers.actions[0] = Transfer.Data({
            outbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.makerAddress,
            tokenAddress: _lendingTokenAddress,
            amount: _lendingAmount + _interestAmount
        });
        // Transfer collateral to taker
        transfers.actions[1] = Transfer.Data({
            outbound: true,
            fromAddress: issuanceParameters.takerAddress,
            toAddress: issuanceParameters.takerAddress,
            tokenAddress: _collateralTokenAddress,
            amount: _collateralAmount
        });
        transfersData = Transfers.encode(transfers);
    }
}