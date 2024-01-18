// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenA
 * @dev Implementation of the ERC20 TokenA.
 * Initial supply of 1000 TokenA is minted to the deployer.
 */
contract TokenA is ERC20 {
    constructor() ERC20("TokenA", "A") {
        _mint(msg.sender, 10000 * 1 ether);
    }

    /**
     * @dev Mints `amount` tokens to address `to`.
     * @param to Address to which tokens will be minted.
     * @param amount Number of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
