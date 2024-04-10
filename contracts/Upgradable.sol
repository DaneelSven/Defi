// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DopeBears ERC721 Token Contract
 * @notice Implements an ERC721 token representing ownership of DopeBears
 * @dev Extends ERC721 and Ownable from OpenZeppelin for NFT functionality and ownership management
 */
contract Upgradable is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC721Receiver
{
    using Strings for uint256;

    uint256 private _mintNr;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /***
     * @notice Initializer for Upgradable pattern
     * @param intialOwner The initial owner of the contract
     */
    function initialize(address intialOwner) public initializer {
        __ERC721_init("DopeBears", "DB");
        __Ownable_init(intialOwner);
    }

    /***
     * @notice Function to mint DopeBear tokens
     * @param _tokenId The unique identifier for the token
     */
    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId); // Mint a new DopeBear
    }

    /***
     * @notice Returns the token URI for a given token
     * @param tokenId The identifier of the token
     * @return The token URI as a string
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, tokenId.toString())
                : "";
    }

    /**
     * @notice Internal function to return the base URI for the tokens
     * @return The base URI as a string
     */
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmYjwPGrMeBMnSsGi5Zcw3Tus24j6KDdi6bUi5G2RX2CPn/";
    }

    /**
     * @notice Withdraws the contract's Ether balance to the owner's address
     */
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /***
     * @dev Ensures that only the owner can upgrade the contract.
     * This function overrides the empty `_authorizeUpgrade` function defined in
     * `UUPSUpgradeable`. It uses the `onlyOwner` modifier from `OwnableUpgradeable`
     * to restrict the upgrade capability to the current owner of the contract.
     *
     * The UUPS upgrade mechanism calls this function before applying an upgrade,
     * and if any conditions within this function aren't met, the upgrade will revert.
     *
     * In its simplest form, as shown below, it checks that the caller is the owner,
     * which is sufficient for many projects. However, more complex governance models
     * might require additional logic inside this function:
     * - For multi-signature approval, it could integrate with a multi-sig contract
     *   and verify that an upgrade proposal has the necessary approvals.
     * - For DAO governance, it could check the outcome of a token holder vote.
     * - For added security with a timelock, it could ensure a certain time period
     *   has elapsed since an upgrade proposal.
     *
     * @param newImplementation The address of the new contract implementation to which
     * the upgrade is being made. This parameter can be used in custom logic to
     * verify the implementation address, though it's not used in the basic `onlyOwner` check.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}