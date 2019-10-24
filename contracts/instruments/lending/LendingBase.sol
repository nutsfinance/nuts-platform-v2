pragma solidity ^0.5.0;

contract LendingBase {
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
}