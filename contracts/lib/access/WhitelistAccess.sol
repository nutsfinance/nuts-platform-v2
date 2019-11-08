pragma solidity ^0.5.0;

library WhitelistAccess {
    struct Whitelist{
        bool enabled;
        mapping(address => bool) allowers;
    }

    /**
     * @dev Updates the whitelist access for account.
     */
    function setAllowed(Whitelist storage self, address account, bool allowed) internal {
        require(self.enabled, "Whitelist disabled");
        self.allowers[account] = allowed;
    }

    /**
     * @dev Check whether the account is allowed to access.
     */
    function isAllowed(Whitelist storage self, address account) internal view returns (bool) {
        return !self.enabled || self.allowers[account];
    }
}