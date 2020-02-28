pragma solidity 0.5.16;

/**
 * @title The interface of all instruments.
 */
interface InstrumentInterface {
    /**
     * @dev Initializes an issuance with common parameters.
     * @param issuanceId ID of the issuance.
     * @param fspAddress Address of the FSP who creates the issuance.
     * @param brokerAddress Address of the instrument broker.
     * @param instrumentEscrowAddress Address of the instrument escrow.
     * @param issuanceEscrowAddress Address of the issuance escrow.
     * @param priceOracleAddress Address of the price oracle.
     */
    function initialize(
        uint256 issuanceId,
        address fspAddress,
        address brokerAddress,
        address instrumentEscrowAddress,
        address issuanceEscrowAddress,
        address priceOracleAddress
    ) external;

    /**
     * @dev Checks whether the issuance is terminated. No futher action is taken on a terminated issuance.
     */
    function isTerminated() external view returns (bool);

    /**
     * @dev Create a new issuance of the financial instrument
     * @param callerAddress Address which invokes this function.
     * @param makerParametersData The custom parameters to the newly created issuance
     * @return transfersData The transfers to perform after the invocation
     */
    function createIssuance(
        address callerAddress,
        bytes calldata makerParametersData
    ) external returns (bytes memory transfersData);

    /**
     * @dev A taker engages to the issuance
     * @param callerAddress Address which invokes this function.
     * @param takerParameters The custom parameters to the new engagement
     * @return transfersData The transfers to perform after the invocation
     */
    function engageIssuance(
        address callerAddress,
        bytes calldata takerParameters
    ) external returns (bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token deposit to the issuance
     * @param callerAddress Address which invokes this function.
     * @param tokenAddress The address of the ERC20 token to deposit.
     * @param amount The amount of ERC20 token to deposit.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenDeposit(
        address callerAddress,
        address tokenAddress,
        uint256 amount
    ) external returns (bytes memory transfersData);

    /**
     * @dev An account has made an ERC20 token withdraw from the issuance
     * @param callerAddress Address which invokes this function.
     * @param tokenAddress The address of the ERC20 token to withdraw.
     * @param amount The amount of ERC20 token to withdraw.
     * @return transfersData The transfers to perform after the invocation
     */
    function processTokenWithdraw(
        address callerAddress,
        address tokenAddress,
        uint256 amount
    ) external returns (bytes memory transfersData);

    /**
     * @dev A custom event is triggered.
     * @param callerAddress Address which invokes this function.
     * @param eventName The name of the custom event.
     * @param eventPayload The custom parameters to the custom event
     * @return transfersData The transfers to perform after the invocation
     */
    function processCustomEvent(
        address callerAddress,
        bytes32 eventName,
        bytes calldata eventPayload
    ) external returns (bytes memory transfersData);

    /**
     * @dev Get custom data.
     * @param callerAddress Address which invokes this function.
     * @param dataName The name of the custom data.
     * @return customData The custom data of the issuance.
     */
    function getCustomData(address callerAddress, bytes32 dataName)
        external
        view
        returns (bytes memory);
}
