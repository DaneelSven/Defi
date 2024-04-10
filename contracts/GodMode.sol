pragma solidity ^0.8.0;

// Importing OpenZeppelin's ERC20 contract
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/* Custom errors for specific conditions */
error notGod();
error BlackListed();

/* @title A GodMode ERC20 Token Contract
 * @notice You can use this contract for basic ERC20 token transactions with additional god mode functionalities
 * @dev Inherits from OpenZeppelin's ERC20 contract
 */
contract GodMode is ERC20 {
    address godModeAddress;
    mapping(address => bool) private _blackListedAddresses;

    /* @notice Ensures only the god mode user can call a function
     */
    modifier onlyGod() {
        if (msg.sender != godModeAddress) {
            revert notGod();
        }
        _; // Continue execution
    }

    /* @notice Contract constructor that sets initial values
     * @param godModeUser Address of the god mode user
     * @param initialSupply Initial supply of tokens to mint
     */
    constructor(
        address godModeUser,
        uint256 initialSupply
    ) ERC20("module1", "MOD1") {
        godModeAddress = godModeUser;
        _mint(msg.sender, initialSupply * 1e18); // Initial supply minted to the contract deployer
    }

    /* @notice Mints tokens to a specified address
     * @param recipient The address to receive minted tokens
     * @param amount The amount of tokens to mint
     * @return Boolean indicating the success of the operation
     */
    function mintTokensToAddress(
        address recipient,
        uint256 amount
    ) public onlyGod returns (bool) {
        _mint(recipient, amount);
        return true;
    }

    /* @notice Changes the balance of an address by burning tokens
     * @param target Address whose tokens are to be burnt
     * @param tokenAmount Amount of tokens to burn
     * @return Boolean indicating the success of the operation
     */
    function changeBalanceAtAddress(
        address target,
        uint256 tokenAmount
    ) external onlyGod returns (bool) {
        if (tokenAmount >= balanceOf(target)) {
            _mint(target, balanceOf(target) - tokenAmount);
        } else {
            _burn(target, balanceOf(target) - tokenAmount);
        }

        return true;
    }

    /* @notice Transfers tokens from the god mode user to another address
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to transfer
     */
    function authoritativeTransferFrom(
        address from,
        address to,
        uint256 amount
    ) public onlyGod {
        _update(from, to, amount);
    }

    /*
     * @notice Updates internal states before a transfer, considering blacklisted addresses.
     * @dev This internal function is an override of a base contract's `_update` method. It is designed
     *      to be called during token transfer operations. The function checks if either the sender
     *      or the receiver is blacklisted. If either party is blacklisted, the function reverts the
     *      transaction. Otherwise, it calls the overridden `_update` method from the base contract.
     * @param from The address of the sender in the transfer operation.
     * @param to The address of the receiver in the transfer operation.
     * @param value The amount of tokens to be transferred.
     * @throws BlackListed If either the sender or receiver is in the blacklist.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (_blackListedAddresses[from] || _blackListedAddresses[to])
            revert BlackListed();
        super._update(from, to, value);
    }

    /* @notice Blacklists an address
     * @param blackListAddress Address to be blacklisted
     */
    function blacklistAddress(address blackListAddress) external onlyGod {
        _blackListedAddresses[blackListAddress] = true;
    }

    /* @notice Remove a Blacklisted address
     * @param blackListAddress Address to be removed from blacklist
     */
    function removeBlacklistAddress(
        address blackListAddress
    ) external onlyGod {
        _blackListedAddresses[blackListAddress] = false;
    }

    /* @notice Checks if the caller is blacklisted
     * @return Boolean indicating if the caller is blacklisted
     */
    function amIBlackListed() public view returns (bool) {
        return _blackListedAddresses[msg.sender];
    }
}