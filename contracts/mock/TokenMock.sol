pragma solidity 0.5.16;

import "../lib/token/ERC20.sol";

contract TokenMock is ERC20 {
    constructor() public {
        _mint(msg.sender, 1000000000000);
    }
}
