// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MasterContract
 * @dev Simple contract for storing and retrieving a uint256 value.
 */
contract MasterContract {
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
 * @title MinimalProxyFactory
 * @dev A factory contract for deploying minimal proxies to a MasterContract.
 */
contract MinimalProxyFactory {
    address public masterContract;
    address[] public deployedProxies;

    event ProxyDeployed(address indexed proxyAddress);

    /**
     * @dev Constructor for the MinimalProxyFactory.
     * @param $masterContract The address of the MasterContract to which proxies will delegate calls.
     */
    constructor(address $masterContract) {
        masterContract = $masterContract;
    }

    /**
     * @notice Deploys a new minimal proxy contract for the MasterContract.
     * @dev This function deploys a minimal proxy (EIP-1167) that delegates calls to a master contract.
     * It uses `CREATE2` for deterministic address generation, allowing for predictable addresses.
     * @param $salt A unique value used to ensure the deployed address is unique.
     * @return The address of the newly deployed minimal proxy contract.
     */
    function deployProxy(bytes32 $salt) public returns (address) {
        address clone;
        bytes20 targetBytes = bytes20(masterContract);

        // EIP-1167 Proxy Creation Code
        assembly {
            let _clone := mload(0x40)
            mstore(_clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(_clone, 0x14), targetBytes)
            mstore(add(_clone, 0x28), 0x5af43d82803e903d91602b57fd5bf3)
            clone := create2(0, _clone, 0x37, $salt)
        }
        deployedProxies.push(clone);
        emit ProxyDeployed(clone);
        return clone;
    }


    /**
     * @dev Calculates the address of a contract deployed with CREATE2.
     * @param bytecode The bytecode of the contract to be deployed.
     * @param salt A unique salt for deterministic address generation.
     * @return The address of the contract that would be created with the given bytecode and salt.
     */

    function getCreate2Address(
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
     * @dev Retrieves all deployed minimal proxy contracts.
     * @return An array of addresses of all deployed proxy contracts.
     */
    function getAllDeployedProxies() public view returns (address[] memory) {
        return deployedProxies;
    }
}
