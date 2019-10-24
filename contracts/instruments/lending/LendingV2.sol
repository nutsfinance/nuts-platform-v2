pragma solidity ^0.5.0;

contract LendingV2 {}

// import "../../storage/StorageInterface.sol";
// import "../../escrow/EscrowBaseInterface.sol";
// import "../../lib/math/SafeMath.sol";
// import "../../lib/priceoracle/PriceOracleInterface.sol";
// import "../../lib/protobuf/LendingData.sol";
// import "../../lib/protobuf/InstrumentData.sol";
// import "../../lib/protobuf/TokenTransfer.sol";
// import "../../instrument/v2/InstrumentV2.sol";
// import "./LendingBase.sol";

// contract LendingV2 is InstrumentV2, LendingBase {
//     using SafeMath for uint256;

//     // Lending parameters
//     bytes32 constant private LENDING_TOKEN = "lending_token";
//     bytes32 constant private COLLATERAL_TOKEN = "collateral_token";
//     bytes32 constant private LENDING_AMOUNT = "lending_amount";
//     bytes32 constant private COLLETERAL_RATIO = "collateral_ratio";
//     bytes32 constant private TENOR = "tenor";
//     bytes32 constant private ENGAGEMENT_DUE = "engagement_due";
//     bytes32 constant private LENDING_DUE = "lending_due";
//     bytes32 constant private INTEREST_AMOUNT = "interest_amount";
//     bytes32 constant private COLLATERAL_AMOUNT = "collateral_amount";

//     /**
//      * @dev Create a new issuance of the financial instrument
//      * @param issuanceParametersData Issuance Parameters.
//      * @param makerParametersData The custom parameters to the newly created issuance
//      * @param issuanceStorage The storage contract for this issuance.
//      * @return updatedState The new state of the issuance.
//      * @return transfersData The transfers to perform after the invocation
//      */
//     function createIssuance(bytes memory issuanceParametersData, bytes memory makerParametersData, StorageInterface issuanceStorage)
//         public returns (IssuanceStates updatedState, bytes memory transfersData) {

//         IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);
//         LendingMakerParameters.Data memory makerParameters = LendingMakerParameters.decode(makerParametersData);

//         // Validates parameters.
//         require(makerParameters.collateralTokenAddress != address(0x0), "Collateral token not set");
//         require(makerParameters.lendingTokenAddress != address(0x0), "Lending token not set");
//         require(makerParameters.lendingAmount > 0, "Lending amount not set");
//         require(makerParameters.tenorDays >= 2 && makerParameters.tenorDays <= 90, "Invalid tenor days");
//         require(makerParameters.collateralRatio >= 5000 && makerParameters.collateralRatio <= 20000, "Invalid collateral ratio");
//         require(makerParameters.interestRate >= 10 && makerParameters.interestRate <= 50000, "Invalid interest rate");

//         // Validate principal token balance
//         uint256 principalTokenBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
//             .getTokenBalance(issuanceParameters.makerAddress, makerParameters.lendingTokenAddress);
//         require(principalTokenBalance >= makerParameters.lendingAmount, "Insufficient principal balance");
 
//         // Persists lending parameters
//         issuanceStorage.setAddress(LENDING_TOKEN, makerParameters.lendingTokenAddress);
//         issuanceStorage.setAddress(COLLATERAL_TOKEN, makerParameters.collateralTokenAddress);
//         issuanceStorage.setUint(LENDING_AMOUNT, makerParameters.lendingAmount);
//         issuanceStorage.setUint(TENOR, makerParameters.tenorDays);
//         issuanceStorage.setUint(INTEREST_AMOUNT, makerParameters.lendingAmount
//             .mul(makerParameters.tenorDays).mul(makerParameters.interestRate).div(INTEREST_RATE_DECIMALS));
//         issuanceStorage.setUint(COLLETERAL_RATIO, makerParameters.collateralRatio);

//         // Emits Scheduled Engagement Due event
//         uint256 engagementDueTimstamp = now + ENGAGEMENT_DUE_DAYS;
//         issuanceStorage.setUint(ENGAGEMENT_DUE, engagementDueTimstamp);
//         emit EventTimeScheduled(issuanceParameters.issuanceId, engagementDueTimstamp, ENGAGEMENT_DUE_EVENT, "");

//         // Emits Lending Created event
//         emit LendingCreated(issuanceParameters.issuanceId, issuanceParameters.makerAddress, issuanceParameters.issuanceEscrowAddress,
//             makerParameters.collateralTokenAddress, makerParameters.lendingTokenAddress, makerParameters.lendingAmount,
//             makerParameters.collateralRatio, engagementDueTimstamp);

//         // Updates to Engageable state.
//         updatedState = IssuanceStates.Engageable;

//         // Transfers principal token from maker(Instrument Escrow) to maker(Issuance Escrow).
//         Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
//         transfers.actions[0] = Transfer.Data({
//             outbound: false,
//             inbound: true,
//             fromAddress: issuanceParameters.makerAddress,
//             toAddress: issuanceParameters.makerAddress,
//             tokenAddress: makerParameters.lendingTokenAddress,
//             amount: makerParameters.lendingAmount
//         });
//         transfersData = Transfers.encode(transfers);
//     }

//     /**
//      * @dev A taker engages to the issuance
//      * @param issuanceParametersData Issuance Parameters.
//      * @param issuanceStorage The storage contract for this issuance.
//      * @return updatedState The new state of the issuance.
//      * @return transfersData The transfers to perform after the invocation
//      */
//     function engageIssuance(bytes memory issuanceParametersData, bytes memory /** takerParameters */, StorageInterface issuanceStorage)
//         public returns (IssuanceStates updatedState, bytes memory transfersData) {
//         IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

//         // Calculate the collateral amount. Collateral is calculated at the time of engagement.
//         PriceOracleInterface priceOracle = PriceOracleInterface(issuanceParameters.priceOracleAddress);
//         (uint256 numerator, uint256 denominator) = priceOracle.getRate(issuanceStorage.getAddress(LENDING_TOKEN),
//             issuanceStorage.getAddress(COLLATERAL_TOKEN));
//         require(numerator > 0 && denominator > 0, "Exchange rate not found");
//         issuanceStorage.setUint(COLLATERAL_AMOUNT, denominator.mul(issuanceStorage.getUint(LENDING_AMOUNT))
//             .mul(issuanceStorage.getUint(COLLETERAL_RATIO)).div(COLLATERAL_RATIO_DECIMALS).div(numerator));

//         // Validates collateral balance
//         uint256 collateralBalance = EscrowBaseInterface(issuanceParameters.instrumentEscrowAddress)
//             .getTokenBalance(issuanceParameters.takerAddress, issuanceStorage.getAddress(COLLATERAL_TOKEN));
//         require(collateralBalance >= issuanceStorage.getUint(COLLATERAL_AMOUNT), "Insufficient collateral balance");

//         // Emits Scheduled Lending Due event
//         issuanceStorage.setUint(LENDING_DUE, now + issuanceStorage.getUint(TENOR) * 1 days);
//         emit EventTimeScheduled(issuanceParameters.issuanceId, issuanceStorage.getUint(LENDING_DUE), LENDING_DUE_EVENT, "");

//         // Emits Lending Engaged event
//         emit LendingEngaged(issuanceParameters.issuanceId, issuanceParameters.takerAddress, issuanceStorage.getUint(LENDING_DUE),
//             issuanceStorage.getUint(COLLATERAL_AMOUNT));

//         // Transition to Engaged state.
//         updatedState = IssuanceStates.Engaged;

//         Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
//         // Transfers collateral token from taker(Instrument Escrow) to taker(Issuance Escrow).
//         transfers.actions[0] = Transfer.Data({
//             outbound: false,
//             inbound: true,
//             fromAddress: issuanceParameters.takerAddress,
//             toAddress: issuanceParameters.takerAddress,
//             tokenAddress: issuanceStorage.getAddress(COLLATERAL_TOKEN),
//             amount: issuanceStorage.getUint(COLLATERAL_AMOUNT)
//         });
//         // Transfers lending token from maker(Issuance Escrow) to taker(Instrument Escrow).
//         transfers.actions[1] = Transfer.Data({
//             outbound: true,
//             inbound: false,
//             fromAddress: issuanceParameters.makerAddress,
//             toAddress: issuanceParameters.takerAddress,
//             tokenAddress: issuanceStorage.getAddress(LENDING_TOKEN),
//             amount: issuanceStorage.getUint(LENDING_AMOUNT)
//         });
//         transfersData = Transfers.encode(transfers);
//     }

//     /**
//      * @dev An account has made an ERC20 token deposit to the issuance
//      * @param issuanceParametersData Issuance Parameters.
//      * @param tokenAddress The address of the ERC20 token to deposit.
//      * @param amount The amount of ERC20 token to deposit.
//      * @param issuanceStorage The storage contract for this issuance.
//      * @return updatedState The new state of the issuance.
//      * @return updatedData The updated data of the issuance.
//      * @return transfersData The transfers to perform after the invocation
//      */
//     function processTokenDeposit(bytes memory issuanceParametersData, address tokenAddress, uint256 amount, StorageInterface issuanceStorage)
//         public returns (IssuanceStates updatedState, bytes memory transfersData) {
//         IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

//         // Important: Token deposit can happen only in repay!
//         require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged, "Must repay in engaged state");
//         require(issuanceParameters.callerAddress == issuanceParameters.takerAddress, "Only taker can repay");
//         require(tokenAddress == issuanceStorage.getAddress(LENDING_TOKEN), "Must repay with lending token");
//         require(amount == issuanceStorage.getUint(LENDING_AMOUNT) + issuanceStorage.getUint(INTEREST_AMOUNT), "Must repay in full");

//         // Emits Lending Repaid event
//         emit LendingRepaid(issuanceParameters.issuanceId);

//         // Updates to Complete Engaged state.
//         updatedState = IssuanceStates.CompleteEngaged;

//         Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](2));
//         // Transfers lending amount + interest from taker(Issuance Escrow) to maker(Instrument Escrow).
//         transfers.actions[0] = Transfer.Data({
//             outbound: true,
//             inbound: false,
//             fromAddress: issuanceParameters.takerAddress,
//             toAddress: issuanceParameters.makerAddress,
//             tokenAddress: issuanceStorage.getAddress(LENDING_TOKEN),
//             amount: issuanceStorage.getUint(LENDING_AMOUNT) + issuanceStorage.getUint(INTEREST_AMOUNT)
//         });
//         // Transfers collateral from taker(Issuance Escrow) to taker(Instrument Escrow).
//         transfers.actions[1] = Transfer.Data({
//             outbound: true,
//             inbound: false,
//             fromAddress: issuanceParameters.takerAddress,
//             toAddress: issuanceParameters.takerAddress,
//             tokenAddress: issuanceStorage.getAddress(COLLATERAL_TOKEN),
//             amount: issuanceStorage.getUint(COLLATERAL_AMOUNT)
//         });
//         transfersData = Transfers.encode(transfers);
//     }


//     /**
//      * @dev An account has made an ERC20 token withdraw from the issuance
//      */
//     function processTokenWithdraw(bytes memory /* issuanceParametersData */, address /* tokenAddress */,
//         uint256 /* amount */, StorageInterface /** issuanceStorage */) public returns (IssuanceStates, bytes memory) {
//         revert("Withdrawal not supported.");
//     }

//     /**
//      * @dev A custom event is triggered.
//      * @param issuanceParametersData Issuance Parameters.
//      * @param eventName The name of the custom event.
//      * @return updatedState The new state of the issuance.
//      * @return updatedData The updated data of the issuance.
//      * @return transfersData The transfers to perform after the invocation
//      */
//     function processCustomEvent(bytes memory issuanceParametersData, bytes32 eventName, bytes memory /** eventPayload */,
//         StorageInterface issuanceStorage) public returns (IssuanceStates updatedState, bytes memory transfersData) {
//         IssuanceParameters.Data memory issuanceParameters = IssuanceParameters.decode(issuanceParametersData);

//         if (eventName == ENGAGEMENT_DUE_EVENT) {
//             // Engagement Due will be processed only when:
//             // 1. Issuance is in Engageable state
//             // 2. Engagement due timestamp is passed
//             if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable && now >= issuanceStorage.getUint(ENGAGEMENT_DUE)) {
//                 // Emits Lending Complete Not Engaged event
//                 emit LendingCompleteNotEngaged(issuanceParameters.issuanceId);

//                 // Updates to Complete Not Engaged state
//                 updatedState = IssuanceStates.CompleteNotEngaged;

//                 // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
//                 Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
//                 transfers.actions[0] = Transfer.Data({
//                     outbound: true,
//                     inbound: false,
//                     fromAddress: issuanceParameters.makerAddress,
//                     toAddress: issuanceParameters.makerAddress,
//                     tokenAddress: issuanceStorage.getAddress(LENDING_TOKEN),
//                     amount: issuanceStorage.getUint(LENDING_AMOUNT)
//                 });
//                 transfersData = Transfers.encode(transfers);
//             } else {
//                 // Not processed Engagement Due event
//                 updatedState = IssuanceStates(issuanceParameters.state);
//             }
//         } else if (eventName == LENDING_DUE_EVENT) {
//             // Lending Due will be processed only when:
//             // 1. Issuance is in Engaged state
//             // 2. Lending due timestamp has passed
//             if (IssuanceStates(issuanceParameters.state) == IssuanceStates.Engaged && now >= issuanceStorage.getUint(LENDING_DUE)) {
//                 // Emits Lending Deliquent event
//                 emit LendingDelinquent(issuanceParameters.issuanceId);

//                 // Updates to Delinquent state
//                 updatedState = IssuanceStates.Delinquent;

//                 // Transfers collateral token from taker(Issuance Escrow) to maker(Instrument Escrow).
//                 Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
//                 transfers.actions[0] = Transfer.Data({
//                     outbound: true,
//                     inbound: false,
//                     fromAddress: issuanceParameters.takerAddress,
//                     toAddress: issuanceParameters.makerAddress,
//                     tokenAddress: issuanceStorage.getAddress(COLLATERAL_TOKEN),
//                     amount: issuanceStorage.getUint(COLLATERAL_AMOUNT)
//                 });
//                 transfersData = Transfers.encode(transfers);
//             } else {
//                 // Not process Lending Due event
//                 updatedState = IssuanceStates(issuanceParameters.state);
//             }
//         } else if (eventName == CANCEL_ISSUANCE_EVENT) {
//             // Cancel Issuance must be processed in Engageable state
//             require(IssuanceStates(issuanceParameters.state) == IssuanceStates.Engageable, "Cancel issuance not in engageable state");
//             // Only maker can cancel issuance
//             require(issuanceParameters.callerAddress == issuanceParameters.makerAddress, "Only maker can cancel issuance");

//             // Emits Lending Cancelled event
//             emit LendingCancelled(issuanceParameters.issuanceId);

//             // Updates to Cancelled state.
//             updatedState = IssuanceStates.Cancelled;

//             // Transfers principal token from maker(Issuance Escrow) to maker(Instrument Escrow)
//             Transfers.Data memory transfers = Transfers.Data(new Transfer.Data[](1));
//             transfers.actions[0] = Transfer.Data({
//                 outbound: true,
//                 inbound: false,
//                 fromAddress: issuanceParameters.makerAddress,
//                 toAddress: issuanceParameters.makerAddress,
//                 tokenAddress: issuanceStorage.getAddress(LENDING_TOKEN),
//                 amount: issuanceStorage.getUint(LENDING_AMOUNT)
//             });
//             transfersData = Transfers.encode(transfers);

//         } else {
//             revert("Unknown event");
//         }
//     }
// }