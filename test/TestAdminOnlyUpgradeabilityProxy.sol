pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "../contracts/lib/proxy/AdminOnlyUpgradeabilityProxy.sol";
import "../contracts/mock/TokenMock.sol";

contract TestAdminOnlyUpgradeabilityProxy {
    function testProxy() public {
        TokenMock token = new TokenMock();
        AdminOnlyUpgradeabilityProxy proxy = new AdminOnlyUpgradeabilityProxy(address(token), address(this), new bytes(0));
        TokenMock proxiedToken = TokenMock(address(proxy));
        Assert.equal(proxiedToken.balanceOf(address(this)), 0, "Token amount should be zero.");
    }
}