// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MyContract
 * @dev Simple contract for storing and retrieving a uint256 value.
 */
contract MyContract {
    uint256 public data;

    /**
     * @dev Sets the `data` variable to a given value.
     * @param _data Value to set `data` to.
     */
    function setData(uint256 _data) public {
        data = _data;
    }

    /**
     * @dev Returns the value of the `data` variable.
     * @return uint256 Current value of `data`.
     */
    function getData() public view returns (uint256) {
        return data;
    }
}

/**
 * @title Factory
 * @dev Factory contract to create new instances of MyContract.
 */
contract Factory {
    // This array will keep track of all created MyContract instances.
    MyContract[] public deployedContracts;

    event Deployed(address addr);
    event Received(address addr, uint256 value);

    /**
     * @dev Creates a new MyContract instance using the provided `salt` for deterministic address generation.
     * @param salt Unique value used for the `CREATE2` address calculation.
    */ 
    function createMyContract(bytes32 salt) public {
        // Using create2 with a provided salt for deterministic address generation
        address newContract = address(new MyContract{salt: salt}());

        emit Deployed(newContract);
        // Additional logic to track the deployed contract, if necessary
    }

    /**
     * @dev Calculates the address of a contract deployed with CREATE2.
     * @param bytecode The bytecode of the contract to be deployed.
     * @param salt A unique salt used to create a deterministic address.
     * @return The address of the contract that will be created with the given bytecode and salt.
     * @notice This function does not deploy the contract; it only computes the address.
     */
    function getAddress(
        bytes memory bytecode,
        uint256 salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Retrieves all deployed MyContract instances.
     * @return An array of addresses of all deployed MyContract instances.
    */
    function getDeployedContracts() public view returns (MyContract[] memory) {
        return deployedContracts;
    }

    /**
     * @dev Generates the bytecode for MyContract with a given owner address.
     * @param owner The address to be set as the owner in the deployed contract.
     * @return The bytecode of MyContract.
     */
    function getBytecode(address owner) public pure returns (bytes memory) {
        bytes memory bytecode = type(MyContract).creationCode;
        return abi.encodePacked(bytecode, abi.encode(owner));
    }

    /**
     * @dev Fallback function to receive Ether. Emits a Received event with the sender and value.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
