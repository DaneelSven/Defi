// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

error LowContractBalance();
error FailedTransaction();

/**
 * @title GaslessMetaTx Contract
 * @dev Extends ERC20 Token Standard basic implementation with burnable and access control features.
 * Allows for minting and burning of tokens by assigned roles.
 */
contract GaslessMetaTx is ERC20, ERC20Burnable, AccessControl, ERC2771Context {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event AccessGranted(address indexed requester, bytes32 role);
    event AccessRevoked(address indexed operator, bytes32 role);
    event EtherReceived(address indexed sender, uint256 amount);
    event EtherWithdrawn(address indexed recipient, uint256 amount);

    /**
     * @notice Constructs the Erc2771 token and grants initial roles.
     * @param _admin The address to grant the admin role.
     * @param _trustedForwarder The address of a truster forwarder
     */
    constructor(address _admin, address _trustedForwarder)
    payable
        ERC20("Gasless", "GAS")
        ERC2771Context(_trustedForwarder)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(BURNER_ROLE, _admin);
    }


    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Mints `amount` tokens to address `to`, requiring the sender to have the minter role.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) onlyRole(MINTER_ROLE) public {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @notice Burns `amount` tokens from the caller, requiring the burner role.
     * @param amount The amount of tokens to burn.
     */

    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
        emit Burn(_msgSender(), amount);
    }

    /**
     * @notice Grants the minter role to `requester`.
     * @param requester The address to be granted the minter role.
     */
    function grantMintRole(address requester) public  onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, requester);
        emit AccessGranted(requester, MINTER_ROLE);
    }

    /**
     * @notice Revokes the minter role from `revoker`.
     * @param revoker The address to have the minter role revoked.
     */
    function revokeMintRole(address revoker) public  onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, revoker);
        emit AccessRevoked(revoker, MINTER_ROLE);
    }

    /**
     * @notice Grants the burner role to `requester`.
     * @param requester The address to be granted the burner role.
     */
  function grantBurnRole(address requester) public  onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, requester);
        emit AccessGranted(requester, BURNER_ROLE);
    }

    /**
     * @notice Revokes the burner role from `revoker`.
     * @param revoker The address to have the burner role revoked.
     */
    function revokeBurnRole(address revoker) public  onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, revoker);
        emit AccessRevoked(revoker, BURNER_ROLE);
    }

    /***
     * @notice overrides contextSuffixLength and sets it to standard length.
     */
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
    return ERC2771Context._contextSuffixLength();
}


    /**
     * @notice Withdraws `amount` of Ether from the contract to the caller, requiring admin role.
     * @param $amount The amount of Ether to withdraw.
     */
    function withdraw(uint256 $amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if ($amount > address(this).balance) revert LowContractBalance();

        (bool success, ) = msg.sender.call{value: $amount}("");
        if (!success) revert FailedTransaction();

        emit EtherWithdrawn(msg.sender, $amount);
    }

    /**
     * @notice Allows the contract to receive Ether.
     */
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
}