pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CommitReveal.sol";

error FunctionInvalidAtThisStage();
error InvalidMerkleProof();
error AlreadyClaimed();
error NotEnoughEth();
error NotSameLength();

/**
 * @title Advanced NFT Contract with Commit-Reveal Scheme
 * @dev Extends ERC721 Enumerable with commit-reveal for minting NFTs in stages.
 * @author Sven
 */
contract AdvancedNft is ERC721Enumerable, Ownable2Step, CommitReveal {
    using Strings for uint256;
    using BitMaps for BitMaps.BitMap;
    using ECDSA for bytes32;

    enum Stages {
        preSale,
        publicSale,
        saleColsed
    }
    Stages public stage = Stages.preSale;

    bytes32 public merkleRoot;
    uint256 public creationTime = block.timestamp;
    uint256 preSaleTime = 10 days;
    uint256 publicSaleTime = 30 days;
    uint256 mintPrice = 0.00001 ether;
    uint256 private constant MAX_SUPPLY = 2;
    uint256 private _mintNr;
    uint256 private bitMapIndex;
    BitMaps.BitMap private bitMap;
    string private baseUri;

    /**
     * @notice Tracks whether an address has already claimed their whitelist spot
     * @dev Mapping of address to boolean indicating claim status
     */
    mapping(address => bool) public whitelistClaimed;
    mapping(address => uint256) public addressToIndex;
    mapping(address => uint256) addressTokenId;

    /**
     * @dev Ensures operations are performed at a specific stage.
     */
    modifier atStage(Stages _stage) {
        if (stage != _stage) revert FunctionInvalidAtThisStage();
        _;
    }

    /**
     * @dev Ensures operations are performed at specific stages.
     */
    modifier atStages(Stages _stage1, Stages _stage2) {
        if (stage != _stage1 && stage != _stage2)
            revert FunctionInvalidAtThisStage();
        _;
    }

    /**
     * @dev Ensures stage transitions based on time.
     */
    modifier timedTransitions() {
        if (
            stage == Stages.preSale &&
            block.timestamp >= creationTime + preSaleTime
        ) {
            _nextStage();
        }
        if (
            stage == Stages.publicSale &&
            block.timestamp >= creationTime + publicSaleTime
        ) {
            _nextStage();
            // Adjust the mint price for public sale here if needed
            mintPrice = 0.001 ether;
        }
        _;
    }

    event Claimed(address claimant, uint256 index);
    event PreSaleOpen(uint256 block);
    event PublicSaleOpen(uint256 block);
    event SaleClosed(uint256 block);

    /**
     * @dev Sets the initial merkleRoot for whitelist verification.
     * @param merkleRoot Merkle root for whitelist verification.
     */
    constructor(bytes32 merkleRoot)
        ERC721("Advanced Nft", "AdNft")
        Ownable(msg.sender)
    {
        merkleRoot = merkleRoot;
    }

    /**
     * @dev Advances to the next stage.
     */
    function _nextStage() internal {
        stage = Stages(uint256(stage) + 1);
    }

    /**
     * @dev Commits to an NFT claim.
     * @param _commit Commit hash for the NFT claim.
     */
    function commitNftClaim(bytes32 _commit) external {
        commit(_commit);
    }

    /**
     * @dev Reveals and claims an NFT based on the previous commit.
     * @param revealHash Hash used for the reveal.
     */
    function revealNftClaim(bytes32 revealHash) external {
        uint256 tokenId = reveal(revealHash);
        addressTokenId[msg.sender] = tokenId;
    }

    /**
     * @notice Allows whitelisted addresses to mint, given they provide a valid Merkle proof
     * @dev Verifies the caller's address against the merkle root to ensure they are whitelisted
     * @param _merkleProof The Merkle proof that proves the sender's address is in the Merkle tree
     */
    function whitelistMintMapping(bytes32[] calldata _merkleProof) public {
        if (whitelistClaimed[msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf))
            revert InvalidMerkleProof();

        whitelistClaimed[msg.sender] = true;
    }

    /**
     * @dev Allows minting based on bitmap and Merkle proof to ensure uniqueness and whitelisting.
     * @param _merkleProof Merkle proof for whitelisting.
     * @param index Index for the bitmap to prevent double claiming.
     */
    function whitelistMintBitmap(
        bytes32[] calldata _merkleProof,
        uint256 index
    ) public {
        if (bitMap.get(index)) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, index));

        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf))
            revert InvalidMerkleProof();

        bitMap.set(bitMapIndex);
        _safeMint(msg.sender, index);

        emit Claimed(msg.sender, index);
    }

    /**
     * @dev Mint an NFT during the presale or public sale stage.
     */
    function MintNft()
        external
        timedTransitions
        atStages(Stages.preSale, Stages.publicSale)
    {
        if (!whitelistClaimed[msg.sender]) revert AlreadyClaimed();

        if (_mintNr >= MAX_SUPPLY) {
            stage = Stages.saleColsed;
            emit SaleClosed(block.number);
        }
        _safeMint(msg.sender, addressTokenId[msg.sender]);
        _mintNr++;
    }

    /**
     * @dev Allows the owner to advance to the next stage manually.
     */
    function increaseState() external {
        stage = Stages(uint256(stage) + 1);
    }

    /**
     * @notice Executes multiple NFT transfers from the caller to various addresses.
     * @dev This function allows batching of multiple NFT transfers in a single transaction, saving gas.
     * It requires that the caller is the owner or approved for each of the NFTs being transferred.
     * @param addresses An array of recipient addresses for each NFT.
     * @param tokenIds An array of token IDs to be transferred to the corresponding address in `addresses`.
     */
    function multiCallTransfer(
        address[] calldata addresses,
        uint256[] calldata tokenIds
    ) external {
        if (addresses.length != tokenIds.length) revert NotSameLength();

        for (uint256 i; i < addresses.length; i++) {
            // safeTransfer checks that transaciton is good and gets tokens
            safeTransferFrom(msg.sender, addresses[i], tokenIds[i]);
        }
    }

    /* 
       External function to return the base URI for the tokens.
       @return The base URI as a string.
    */
    function getURI() external view returns (string memory) {
        return baseUri;
    }

    /* @notice Internal function to return the base URI for the tokens
     * @return The base URI as a string
     */
    function baseURI() internal pure returns (string memory) {
        return "ipfs://QmYjwPGrMeBMnSsGi5Zcw3Tus24j6KDdi6bUi5G2RX2CPn/";
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
     * @notice Withdraws the contract's Ether balance to the owner's address
     */
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}