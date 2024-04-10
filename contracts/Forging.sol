// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* Importing necessary components from OpenZeppelin library */
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./MultiToken.sol";

/* Custom error for insufficient token balance during burning process */
error InsufficientTokensBurn();
error InvalidForgeId();
error InvalidElement();

/**
 * @title Forging
 * @notice This contract manages the forging and buring of erc-1155 tokens.
 * @dev Inherits from Ownable2Step.
 * @author Sven
 */
contract Forging is Ownable {
    MultiToken nfts;

    /* 
      Modifier to ensure trades are valid with the given token IDs.
    */
    modifier TradeCheck(uint256 requestToken, uint256 offerToken) {
        if (requestToken > 2 || offerToken > 2 || requestToken == offerToken)
            revert InvalidElement();
        _;
    }

    /* Events to log forging, forge access, and trading operations */
    event Forge(uint256 tokenId, uint256 amount);
    event Trade(uint256 tokenIdRequest, uint256 tokenIdOffer, uint256 amount);
    event RequestForgeAccess();


    /**
      @dev Constructor to initialize the Forging contract.
      @param initialOwner The initial owner of the contract.
      @param nftAddress Address of the NFT contract.
    */
    constructor(
        address initialOwner,
        address nftAddress
    ) Ownable(initialOwner) {
        nfts = MultiToken(nftAddress);
    }

    /**
      @dev forge Token function to handle the forging logic.
      @param mintTokenId Token ID to mint.
    */
    function forgeToken(uint256 mintTokenId) external {
        if (mintTokenId == 3) {
            if (
                nfts.balanceOf(msg.sender, 0) < 1 ||
                nfts.balanceOf(msg.sender, 1) < 1
            ) revert InsufficientTokensBurn();
            nfts.burn(msg.sender, 0, 1);
            nfts.burn(msg.sender, 1, 1);
        } else if (mintTokenId == 4) {
            if (
                nfts.balanceOf(msg.sender, 1) < 1 ||
                nfts.balanceOf(msg.sender, 2) < 1
            ) revert InsufficientTokensBurn();
            nfts.burn(msg.sender, 1, 1);
            nfts.burn(msg.sender, 2, 1);
        } else if (mintTokenId == 5) {
            if (
                nfts.balanceOf(msg.sender, 0) < 1 ||
                nfts.balanceOf(msg.sender, 2) < 1
            ) revert InsufficientTokensBurn();
            nfts.burn(msg.sender, 0, 1);
            nfts.burn(msg.sender, 2, 1);
        } else if (mintTokenId == 6) {
            if (
                nfts.balanceOf(msg.sender, 0) < 1 ||
                nfts.balanceOf(msg.sender, 1) < 1 ||
                nfts.balanceOf(msg.sender, 2) < 1
            ) revert InsufficientTokensBurn();
            nfts.burn(msg.sender, 0, 1);
            nfts.burn(msg.sender, 1, 1);
            nfts.burn(msg.sender, 2, 1);
        } else {
            revert InvalidForgeId();
        }

        nfts.mintForge(msg.sender, mintTokenId, "0x");
        emit Forge(mintTokenId, 1);
    }

    /**
      @dev Trade function allows users to trade their tokens, This function burns the offer token and mints the requested token in equal amounts.
      @param requestedToken Token ID that the user wants to receive.
      @param offerToken Token ID that the user offers to trade.
      The function requires that the user has at least the amount of the requested and offer tokens.
      Reverts if the user does not have sufficient tokens to trade.
    */
    function trade(
        uint256 requestedToken,
        uint256 offerToken
    ) external TradeCheck(requestedToken, offerToken) {
        if (
            nfts.balanceOf(msg.sender, offerToken) < 1 ||
            nfts.balanceOf(msg.sender, requestedToken) < 1
        ) revert InsufficientTokensBurn();

        nfts.burn(msg.sender, offerToken, 1);
        nfts.mint(msg.sender, requestedToken, "0x");
        emit Trade(requestedToken, offerToken, 1);
    }

    /**
      @dev requestForgeAccess function allows the owner to request Forge access.
      This function can only be called by the owner of the contract.
    */
    function requestForgeAccess() external onlyOwner {
        emit RequestForgeAccess();
    }

    /**
      @dev MintTokens function allows the owner to mint new tokens.
      @param tokenId The ID of the token to mint.
      This function can only be called by the owner of the contract.
    */
    function mintTokens(uint256 tokenId) external {
        nfts.mint(msg.sender, tokenId, "0x");
    }
}