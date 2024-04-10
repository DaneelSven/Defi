pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/* @notice Custom errors for StakeManager contract */
error InsuficientTokenbalance();
error AlreadyStaked();
error NotOriginialOwner();
error NotStaked();
error NotNftOrigniatorContract();

/**
 * @title StakeManager for ERC721 Tokens
 * @notice This contract allows users to stake their ERC721 tokens and earn rewards based on staking duration.
 * @dev Inherits from ERC721Holder and Ownable2Step for handling ERC721 tokens and ownership management.
 */
contract StakeManager is ERC721Holder, Ownable2Step {
    IERC721 private immutable _itemNFT;
    IMintableERC20 private immutable _erc20Token;

    /* Mapping from token ID to the original owner's address */
    mapping(address => StakedNFT[]) public stakedNFTs;
    mapping(uint256 => address) private _originalOwner;
    mapping(uint256 => bool) private _isTokenStaked;

    /**
     * @notice Struct to represent a staked NFT, containing its ID and the start time of staking.
     */
    struct StakedNFT {
        uint256 tokenId;
        uint256 startTime;
    }

    /***
     * @notice Modifier to check if the caller is the original owner of the staked token.
     * @param index The index of the staked token in the owner's array.
     */
    modifier originalOwner(uint256 $tokenId) {
        if (_originalOwner[$tokenId] != msg.sender) revert NotOriginialOwner();
        _;
    }

    /***
     * @notice Modifier to check if the token is already staked.
     * @param tokenId The ID of the token to be staked.
     */
    modifier alreadyStaked(uint256 $tokenId) {
        if (_isTokenStaked[$tokenId]) revert AlreadyStaked();
        _;
    }

    event Stake(address indexed account, uint256 tokenId);
    event Unstake(address indexed account, uint256 tokenId);
    event ClaimStake(address indexed account, uint256 tokenId, uint256 amount);

    /***
     * @notice Constructs the StakeManager contract.
     * @param NFTAddress The address of the ERC721 token contract.
     * @param erc20Address The address of the ERC20 token contract for rewards.
     */
    constructor(
        address $NFTAddress,
        address $erc20Address
    ) Ownable(msg.sender) {
        _itemNFT = ERC721Enumerable($NFTAddress);
        _erc20Token = IMintableERC20($erc20Address);
    }

    /***
     * @notice Handles the receipt of an NFT (ERC721 token).
     * @dev Implements the ERC721Receiver interface. This function is called after a successful
     *      `safeTransferFrom` call. It ensures that the NFT being transferred originates from
     *      the expected contract. If not, it reverts the transaction. This function then records
     *      the original owner of the NFT and stakes the token.
     * @param $operator The address which called `safeTransferFrom` function on the ERC721 token contract.
     * @param $from The address which previously owned the token.
     * @param $tokenId The identifier for an NFT.
     * @param $data Additional data with no specified format, sent in call to `_to`.
     * @return bytes4 Returns `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     *         to indicate successful receipt.
     * @throws NotNftOrigniatorContract If the NFT does not originate from the expected contract.
     */
    function onERC721Received(
        address $operator,
        address $from,
        uint256 $tokenId,
        bytes memory $data
    ) public virtual override returns (bytes4) {
        if (IERC721(msg.sender) != _itemNFT) revert NotNftOrigniatorContract();
        
        _stake($from, $tokenId);
        emit Stake($from, $tokenId);
        return super.onERC721Received($operator, $from, $tokenId, $data);
    }

    /***
     * @notice Allows users to stake their NFTs.
     * @param from addres which wants stake their nft.
     * @param tokenId The ID of the token to stake.
     */
    function _stake(
        address $from,
        uint256 $tokenId
    ) internal alreadyStaked($tokenId) {
        _originalOwner[$tokenId] = $from;
        _isTokenStaked[$tokenId] = true;
        stakedNFTs[$from].push(StakedNFT($tokenId, block.timestamp));
    }

    /***
     * @notice Allows users to unstake their NFTs.
     * @param tokenId The ID of the token to unstake.
     */
    function unstake(uint256 $tokenId) originalOwner($tokenId) public {
        (StakedNFT storage stakedNft, uint256 index) = _getStakedNFT($tokenId);

        _getReward(stakedNft);
        // Transfer NFT back to the owner and remove the stake record
        _itemNFT.safeTransferFrom(address(this), msg.sender, $tokenId);
        stakedNFTs[msg.sender][index] = stakedNFTs[msg.sender][
            stakedNFTs[msg.sender].length - 1
        ];
        stakedNFTs[msg.sender].pop();
        delete _isTokenStaked[$tokenId];
        emit Unstake(msg.sender, $tokenId);
    }

    /*
     * @notice Allows users to claim rewards for their staked NFTs.
     * @param tokenId The ID of the token for which to claim rewards.
     */
    function getReward(uint256 $tokenId) public originalOwner($tokenId) {
        (StakedNFT storage nft, ) = _getStakedNFT($tokenId);
        _getReward(nft);

    }

    /***
     * @dev Internal function to find a staked NFT and its index.
     * @param tokenId The ID of the staked token.
     * @return The staked NFT and its index in the stakedNFTs array.
     */
    function _getStakedNFT(
        uint256 $tokenId
    ) internal returns (StakedNFT storage, uint256 stakedIndex) {
        uint256 index;
        bool found = false;
        uint256 _len = stakedNFTs[msg.sender].length;

        for (uint256 i = 0; i < _len; i++) {
            if (stakedNFTs[msg.sender][i].tokenId == $tokenId) {
                index = i;
                found = true;
                break;
            }
        }
        if (!found) revert NotStaked();

        return (stakedNFTs[msg.sender][index], index);
    }

    /***
     * @dev Internal function to calculate and distribute staking rewards.
     * @param userStake The staked NFT for which rewards are being calculated.
     */
    function _getReward(StakedNFT storage $userStake) internal {
        uint256 stakedDuration = block.timestamp - $userStake.startTime;
        uint256 reward = stakedDuration * 10 ** 18 / 1 days;

        $userStake.startTime = block.timestamp;
        _erc20Token.mint(msg.sender, reward);
        emit ClaimStake(msg.sender, $userStake.tokenId, reward);
    }
}