// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title WithdrawableContract
 * @dev A simple contract that allows users to deposit and withdraw Ether.
 */
contract WithdrawableContract {
    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /**
     * @notice Withdraws a specified amount of Ether to the sender's address.
     * @dev Transfers a specified amount of Ether from the contract to the address calling the function.
     * @param amount The amount of Ether (in wei) to withdraw.
     */    function withdraw(uint256 amount) external {
        payable(msg.sender).transfer(amount);
    }
}
