// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/* @notice Custom errors for DopeBearsMint contract */
error MaxMint();
error InsuficientBalance();

/**
 * @title DopeBearsMint
 * @notice This contract handles the minting of DopeBears NFTs in exchange for ERC20 tokens.
 * @dev Inherits from ERC721 and Ownable2Step for NFT functionality and ownership management.
 */
contract DopeBearsMint is ERC721, AccessControl, Ownable2Step {
    using Strings for uint256;

    /* ERC20 token used for purchases */
    IERC20 private _erc20Token;

    /* Price for minting one NFT */
    uint256 private _tokenPrice = 10 * 1 ether;

    /* Counter for minted NFTs */
    uint256 private _mintNr;

    /* Maximum supply of NFTs */
    uint256 private constant MAX_SUPPLY = 9;
    bytes32 private constant MINTER = keccak256("MINTER");

    /**
     * @notice Modifier to check if the max supply of NFTs is exceeded
     */
    modifier exceedMaxSupply() {
        if (_mintNr > MAX_SUPPLY) {
            revert MaxMint();
        }
        _;
    }

    event AccessGranted(address requester);
    event AccessRevoked(address operator);

    /**
     * @notice Constructs the DopeBearsMint contract.
     * @param intialOwner The initial owner of the contract.
     * @param erc20Address The address of the ERC20 token used for minting NFTs.
     */
    constructor(address intialOwner, address erc20Address)
        ERC721("DopeBears", "DB")
        Ownable(intialOwner)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, intialOwner);
        _erc20Token = IERC20(erc20Address);
        _safeMint(msg.sender, _mintNr);
    }

    /**
     * @notice Mints a new DopeBears NFT to a specified recipient.
     * @param recipient The address receiving the minted NFT.
     */
    function mint(address recipient)
        external
        onlyRole(MINTER)
        exceedMaxSupply
    {
        _mintNr++;
        _safeMint(recipient, _mintNr);
    }

    /**
     * @notice Returns the token URI for a given token ID.
     * @param tokenId The ID of the token.
     * @return The token URI as a string.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, tokenId.toString())
                : "";
    }

    /* 
       Function to Grant Minting Access.
       @param address The address to grant minting role.
       This function can only be called by the owner of the contract.

    */
    function grantForgeRole(address mintingContract) public onlyOwner {
        grantRole(MINTER, mintingContract);
        emit AccessGranted(mintingContract);
    }

    /* 
       Function to Revoke Minting Access.
       @param address The address to revoke minting role.
       This function can only be called by the owner of the contract.

    */
    function revokeForgeRole(address mintingContract) public onlyOwner {
        revokeRole(MINTER, mintingContract);
        emit AccessRevoked(mintingContract);
    }

    /**
     * @dev Determines if a given interface is supported by this contract.
     * Overrides the ERC165 implementation in both ERC721 and AccessControl contracts.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to return the base URI for the tokens.
     * @return The base URI as a string.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmYjwPGrMeBMnSsGi5Zcw3Tus24j6KDdi6bUi5G2RX2CPn/";
    }

    /**
     * @notice Withdraws the contract's Ether balance to the owner's address.
     */
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}