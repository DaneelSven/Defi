// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/* @notice Custom errors for DopeBearsStake contract */
error MaxMint();
error InsuficientBalance();

/**
 * @title DopeBearsStake
 * @notice This contract manages the minting of DopeBears NFTs in exchange for ERC20 tokens.
 * @dev Inherits from ERC721Enumerable and Ownable2Step for NFT functionality and ownership management.
 */
contract DopeBearsStake is ERC721Enumerable, Ownable2Step {
    using Strings for uint256;
    
    IERC721 private _itemNFT;
    IERC20 private _erc20Token;
    uint256 private _tokenPrice = 10 * 1 ether;
    uint256 private _mintNr;
    uint256 private constant MAX_SUPPLY = 9;

    /**
     * @notice Modifier to check if the max supply of NFTs is exceeded
     */
    modifier exceedMaxSupply() {
        if (_mintNr > MAX_SUPPLY) {
            revert MaxMint();
        }
        _;
    }

    /**
     * @notice Constructs the DopeBearsStake contract.
     * @param intialOwner The initial owner of the contract.
     * @param erc20Address The address of the ERC20 token used for minting NFTs.
     */
    constructor(address intialOwner, address erc20Address)
        ERC721("DopeBears", "DB")
        Ownable(intialOwner)
    {
        _erc20Token = IERC20(erc20Address);
        _mint(msg.sender, 0); // Mint the first DopeBear
        _mintNr++;
    }
    

    /**
     * @notice Mints a new DopeBear NFT to a specified recipient.
     * @param recipient The address receiving the minted NFT.
     */
    function mint(address recipient) public exceedMaxSupply {
        _mintNr++;
        _mint(recipient, _mintNr); // Mint a new DopeBear
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
}