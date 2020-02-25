pragma solidity 0.5.16;

/**
 * @title A library to define access white list.
 */
library WhitelistAccess {
    struct Whitelist {
        bool enabled;
        mapping(address => bool) allowers;
    }

    /**
     * @dev Updates the whitelist access for account.
     */
    function setAllowed(Whitelist storage self, address account, bool allowed)
        internal
    {
        require(self.enabled, "Whitelist disabled");
        self.allowers[account] = allowed;
    }

    /**
     * @dev Check whether the account is allowed to access.
     * Access is allowed if whitelist is not enabled.
     */
    function isAllowed(Whitelist storage self, address account)
        internal
        view
        returns (bool)
    {
        return !self.enabled || self.allowers[account];
    }
}
