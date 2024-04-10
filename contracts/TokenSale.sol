// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* Importing ERC20, Pausable and Ownable2Step from OpenZeppelin */
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "hardhat/console.sol";


/* Custom errors for specific conditions */
error InvalidValue();
error SaleClosed();
error LowContractBalance();
error NoTokens();
error FailedTransaction();

/** 
 * @title Token Sale Contract
 * @notice Implements a token sale with custom rules, extending OpenZeppelin's ERC20 and Ownable2Step
 * @dev Uses ERC20 for token management and Ownable2Step for ownership
 * @author Sven Daneel
 */
contract TokenSale is ERC20Capped, Pausable, Ownable2Step {
    uint256 private constant tokensPerEther = 2000 * 1e18; // 1000 tokens for 0.5 ether
    uint256 private constant _CLOSED = 1;
    uint256 private constant _NOT_CLOSED = 2;
    uint256 public saleClosed;

    /* Events for logging activities */
    event EtherReceived(address indexed sender, uint256 amount);
    event EtherWithdrawn(address indexed recipient, uint256 amount);
    event ClosingSale();
    event OpenSale();

    /* Modifiers for enforcing rules */
    modifier mintRequirements() {
        if (msg.value != 1 ether) revert InvalidValue();
        _;
    }

    /** @notice Constructor to initialize the token sale
     * @param initalOwner The initial owner of the contract
     * @param initialSupply The initial supply of tokens
     */
    constructor(
        address initalOwner,
        uint256 initialSupply,
        uint256 maxSupply
    )
        payable
        ERC20("module1", "MOD1")
        ERC20Capped(maxSupply)
        Ownable(initalOwner)
    {
        // Initial supply minted to the contract deployer
        _mint(msg.sender, initialSupply * 1e18);        
        _mint(address(this), initialSupply * 1e18);

        saleClosed = _NOT_CLOSED;
    }

    /** 
     * @notice Mints tokens to a specified address under certain conditions
     * @return Boolean indicating the success of the operation
     */
    function mintTokensToAddress()
        public
        payable
        mintRequirements
        whenNotPaused
        returns (bool)
    {
        uint256 tokensToBeMinted = 1000 * 1e18; // add 1000 tokens

        if (balanceOf(address(this)) >= tokensToBeMinted) {
            //transfer(msg.sender, tokensToBeMinted); this does not work cause to and from are both msg.sender
            _transfer(address(this), msg.sender, tokensToBeMinted);

        } else {
            uint256 _tokenToBeMint = tokensToBeMinted - balanceOf(address(this));
            if (balanceOf(address(this)) > 0) {
                _transfer(address(this), msg.sender, balanceOf(address(this)));
            }
            _mint(msg.sender, _tokenToBeMint);
        }
        return true;
    }

    /** 
     * @notice Allows users to sell back tokens in exchange for Ether
     * @param tokenAmount The amount of tokens to sell back
     */
    function sellBack(uint256 tokenAmount) external payable {
        if (tokenAmount <= 0) {
            revert NoTokens();
        }

        uint256 etherAmount = (tokenAmount * 1 ether) / tokensPerEther; // calculate the ether to send for the given token amount

        if (balanceOf(address(this)) > tokenAmount) {
            // Transfer tokens from user to the contract
            transfer(address(this), tokenAmount);
        } else {
            _mint(msg.sender, tokenAmount);
        }

        // Send ether to the user
        payable(msg.sender).transfer(etherAmount);
    }

    /** 
     * @notice Withdraws a specific amount of Ether from the contract
     * @param amount The amount of Ether to withdraw
     */
    function withdraw(uint256 amount) public onlyOwner {
        if (amount > address(this).balance) revert LowContractBalance();

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert FailedTransaction();

        emit EtherWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Closes the token sale
     */
    function closeSale() public onlyOwner {
        _pause();
        emit ClosingSale();
    }

    /**
     * @notice Opens the token sale
     */
    function openSale() public onlyOwner {
        _unpause();
        emit OpenSale();
    }

    /**
     * @notice Helper Function to transfer tokens out of contract
    */
    function transferTokensOut(address to, uint256 amount) public onlyOwner {
    _transfer(address(this), to, amount);
}


    /**
     * @notice Function to allow contract to receive ether
     */
    receive() external payable {
        mintTokensToAddress();
        emit EtherReceived(msg.sender, msg.value);
    }
}