pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/* @notice Custom errors for DopeBearsStake contract */
error InsuficientTokenbalance();
error NotNftOrigniatorContract();
error NotOriginialOwner();
error AlreadyStaked();


/**
 * @title StakeManager for ERC721 Tokens
 * @notice This contract allows users to stake their ERC721 tokens and earn rewards based on staking duration.
 * @dev Inherits from ERC721Holder and Ownable2Step for handling ERC721 tokens and ownership management.
 */
contract StakeManagerV2 is ERC721Holder, Ownable2Step {
    IERC721 private _itemNFT;
    IMintableERC20 private _erc20Token;

    /* Mapping from token ID to the original owner's address */
    mapping(uint256 => StakedNFT) public stakedNFTs;    
    mapping(uint256 => bool) private _isTokenStaked;

    /**
     * @notice Struct to represent a staked NFT, containing its ID and the start time of staking.
     */
    struct StakedNFT {
        address owner;
        uint256 startTime;
    }

    /***
     * @notice Modifier to check if the caller is the original owner of the staked token.
     * @param index The index of the staked token in the owner's array.
     */
    modifier originalOwner(uint256 $tokenId) {
        if (stakedNFTs[$tokenId].owner != msg.sender) revert NotOriginialOwner();
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
     * @param tokenId The ID of the token to stake.
     */
    function _stake(address $owner, uint256 $tokenId) alreadyStaked($tokenId) internal {
        stakedNFTs[$tokenId] = StakedNFT($owner, block.timestamp);
        _isTokenStaked[$tokenId] = false;
    }

    /***
     * @notice Allows users to unstake their NFTs.
     * @param tokenId The ID of the token to unstake.
     */
    function unstake(uint256 $tokenId) originalOwner($tokenId) external {
        StakedNFT storage nft = stakedNFTs[$tokenId];

        uint256 reward = _getReward(nft);
        delete _isTokenStaked[$tokenId];        
        // Transfer NFT back to the owner and remove the stake record
        _itemNFT.safeTransferFrom(address(this), msg.sender, $tokenId);
        
        emit ClaimStake(msg.sender, $tokenId, reward);
        emit Unstake(msg.sender, $tokenId);
    }

    /***
     * @notice Allows users to claim rewards for their staked NFTs.
     * @param tokenId The ID of the token for which to claim rewards.
     */
    function getRewards() external {
        for (uint256 i = 0; i < 10; i++) {
            StakedNFT storage nft = stakedNFTs[i];

            if (nft.owner == msg.sender) {
                uint256 reward = _getReward(nft);
                emit ClaimStake(msg.sender, i, reward);
            }
        }
    }

    /***
     * @notice Calculates and transfers the reward for a staked NFT based on the staking duration.
     * @dev This internal function calculates the reward based on the time elapsed since the NFT was staked.
     *      It then transfers the calculated reward to the sender. This function also resets the staked NFT's
     *      start time and sets its owner to the zero address, effectively unstaking it.
     * @param nft The staked NFT struct, passed by storage reference.
     * @return amount The calculated reward amount.
     * @throws InsuficientTokenbalance If the contract does not have enough ERC20 tokens to cover the reward.
     */
    function _getReward(
        StakedNFT storage nft
    ) internal returns (uint256 amount) {
        uint256 stakedDuration = block.timestamp - nft.startTime;
        uint256 reward = stakedDuration * 10 ** 18 / 1 days;

        nft.startTime = block.timestamp;
        nft.owner = address(0);
        _erc20Token.mint(msg.sender, reward);

        return reward;
    }
}