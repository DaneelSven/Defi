// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* Importing ERC1155 and related extensions from OpenZeppelin library */
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


/** Custom errors for handling specific contract conditions */
error CoolDownError();
error ForgeRequired();
error ContractPaused();

/**
  @title MultiToken Contract
  @notice Manages minting, burning, and pausing of ERC1155 tokens
  @dev Inherits from ERC1155, ERC1155Pausable, ERC1155Burnable, and ERC1155Supply. Implements cool down, mint limits, and batch checks
  @author Sven
*/
contract MultiToken is
    ERC1155,
    AccessControl,
    Ownable,
    ERC1155Pausable,
    ERC1155Burnable,
    ERC1155Supply
{
    /* State variables */
    uint256 private _coolDownTimer;
    string private baseURI;
    bytes32 private constant FORGE_ROLE = keccak256("FORGE_ROLE");

    /* 
       Modifier to limit minting to certain token IDs.
    */
    modifier mintLimit(uint256 tokenId) {
        if (tokenId >= 3) revert ForgeRequired();
        _;
    }

    /* 
       Modifier to enforce a cooldown period for minting operations.
    */
    modifier coolDownCheck() {
        if (block.timestamp < _coolDownTimer  + 60) revert CoolDownError();
        _;
    }

    /* 
       Modifier to check if contract is paused.
    */
    modifier pauseCheck() {
        if (paused()) revert ContractPaused();
        _;
    }

    /* Event to log mint operations */
    event Mint(uint256 tokenId, uint256 amount);
    event AccessGranted(address requester);
    event AccessRevoked(address operator);

    /**
       @dev Constructor to initialize the contract with initial tokens.
       @param initialOwner The initial owner of the contract.
    */
    constructor(address initialOwner) ERC1155(_baseURI()) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _coolDownTimer = block.timestamp;
    }

    /**
      @dev Function to pause the contract. Only callable by the owner.
    */
    function pause() public onlyOwner {
        _pause();
    }

    /**
      @dev Function to unpause the contract. Only callable by the owner.
    */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
       @dev Function to mint new tokens.
       @param account The address to mint the tokens to.
       @param tokenId The ID of the token to mint.
       @param data Additional data.
    */
    function mint(
        address account,
        uint256 tokenId,
        bytes memory data
    ) public mintLimit(tokenId) coolDownCheck() pauseCheck {
        _mint(account, tokenId, 1, data);
        _coolDownTimer = block.timestamp;
        emit Mint(tokenId, 1);
    }

    /**
       @dev Function to mint new tokens.
       @param account The address to mint the tokens to.
       @param tokenId The ID of the token to mint.
       @param data Additional data.
    */
    function mintForge(
        address account,
        uint256 tokenId,
        bytes memory data
    ) external onlyRole(FORGE_ROLE) pauseCheck {
        _mint(account, tokenId, 1, data);
        _coolDownTimer = block.timestamp;
        emit Mint(tokenId, 1);
    }

    /**
       @dev Function to Grant Forging Access.
       @param forgingContract The address to grant forging role.
       This function can only be called by the owner of the contract.
    */
    function grantForgeRole(address forgingContract) public onlyOwner {
        grantRole(FORGE_ROLE, forgingContract);
        emit AccessGranted(forgingContract);
    }

    /**
       @dev Function to Revoke Forging Access.
       @param forgingContract The address to revoke forging role.
       This function can only be called by the owner of the contract.
    */
    function revokeForgeRole(address forgingContract) public onlyOwner {
        revokeRole(FORGE_ROLE, forgingContract);
        emit AccessRevoked(forgingContract);
    }

    /**
      @dev Overrides required by Solidity for combining multiple inherited contracts.
    */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return ERC1155.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
    /**
       @dev External function to return the base URI for the tokens.
       @return The base URI as a string.
    */
    function getURI() external view returns (string memory) {
        return baseURI;
    }


    /**
       @dev Function to set a new URI for all token types.
       @param newuri The new URI to set.
       This function can only be called by the owner of the contract.
    */
    function setURI(string memory newuri) public onlyOwner {
        baseURI = newuri;
        _setURI(baseURI);
    }

    /**
     * @notice Internal function to return the base URI for the tokens
     * @return The base URI as a string
     */
    function _baseURI() internal pure returns (string memory) {
        return "ipfs://QmYjwPGrMeBMnSsGi5Zcw3Tus24j6KDdi6bUi5G2RX2CPn/";
    }
}