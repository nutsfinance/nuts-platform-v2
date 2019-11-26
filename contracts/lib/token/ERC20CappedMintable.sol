pragma solidity ^0.5.0;

import "./ERC20.sol";
import "../access/Ownable.sol";

/**
 * @dev Extension of `ERC20Mintable` that adds a cap on the number
 * of token each minter can mint.
 *
 * Only the owner of the token can set cap.
 *
 * No MinterRole is needed as each minter is given a cap of 0 without setting minter cap.
 */
contract ERC20CappedMintable is ERC20, Ownable {

    event MinterCapUpdated(address indexed account, uint256 cap);

    // Cap for total supply.
    uint256 private _cap;
    // Cap for individual minter.
    mapping(address => uint256) private _minterCaps;
    // Number of token minted by individual minter.
    mapping(address => uint256) private _minterAmount;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20CappedMintable: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Sets the minter cap.
     *
     * Requirements:
     *
     * - The caller must be the owner.
     * - The new cap must not be smaller than the current minter amount.
     */
    function setMinterCap(address account, uint256 cap) public onlyOwner returns (bool) {
        require(_minterAmount[account] <= cap, "ERC20CappedMintable: cap smaller than current amount.");
        _minterCaps[account] = cap;

        emit MinterCapUpdated(account, cap);

        return true;
    }

    /**
     * @dev Gets the minter cap.
     * @param account The account of the minter to check minter cap.
     */
    function getMinterCap(address account) public view returns (uint256) {
        return _minterCaps[account];
    }

    /**
     * @dev Get the token amount minted by this minter.
     * @param account The account of the minter to check minter cap.
     */
    function getMinterAmount(address account) public view returns (uint256) {
        return _minterAmount[account];
    }

    /**
     * @dev See `ERC20Mintable.mint`.
     *
     * Requirements:
     *
     * - `value` must not cause the total supply to go over the cap.
     * - `value` must not cause the minter amount to go over the minter cap.
     */
    function mint(address account, uint256 value) public returns (bool) {
        address minter = msg.sender;
        require(totalSupply().add(value) <= _cap, "ERC20CappedMintable: cap exceeded");
        require(_minterAmount[minter].add(value) <= _minterCaps[minter], "ERC20CappedMintable: minter cap exceeded");
        _minterAmount[minter] = _minterAmount[minter].add(value);
        _mint(account, value);

        return true;
    }
}
