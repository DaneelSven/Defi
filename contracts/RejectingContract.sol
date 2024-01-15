// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RejectingContract
 * @dev A contract designed to test Ether withdrawal from another contract. 
 * It does not accept Ether directly and is used to validate proper handling of failed transactions.
 */
contract RejectingContract {
    /**
     * @dev Constructs the RejectingContract instance.
     */
    constructor() {}


    /**
     * @notice Attempts to withdraw Ether from another contract.
     * @dev Calls the `withdraw` function of another contract and reverts if the transaction fails.
     * @param yourContractAddress Address of the contract from which to withdraw Ether.
     * @param amount Amount of Ether (in wei) to withdraw.
     */
    function testWithdraw(
        address yourContractAddress,
        uint256 amount
    ) external {
        // Call withdraw function of YourContract
        (bool success, ) = yourContractAddress.call(
            abi.encodeWithSignature("withdraw(uint256)", amount)
        );

        if (!success) {
            revert("FailedTransaction");
        }
    }
}
