pragma solidity ^0.5.0;

import "./instruments/InstrumentManagerInterface.sol";
import "./instruments/InstrumentManagerFactoryInterface.sol";
import "./lib/token/IERC20.sol";
import "./lib/access/Ownable.sol";
import "./InstrumentConfig.sol";

contract InstrumentRegistry is Ownable, InstrumentConfig {
    constructor(address instrumentManagerFactoryAddress, address depositEscrowAddress, address depositTokenAddress) public {

    }
}