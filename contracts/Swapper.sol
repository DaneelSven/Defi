pragma solidity ^0.8.4;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/** 
 * @title Swapper
 * @dev Implements a simple AMM (Automated Market Maker) for swapping between two ERC20 tokens.
 */
contract Swapper is ERC20 {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveTokenA;
    uint256 public reserveTokenB;

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    /**
     * @dev Initializes the contract with two ERC20 tokens.
     * @param $tokenA Address of the first ERC20 token.
     * @param $tokenB Address of the second ERC20 token.
     */
    constructor(IERC20 $tokenA, IERC20 $tokenB) ERC20("Swap", "Swap") {
        tokenA = $tokenA;
        tokenB = $tokenB;
    }


    /**
     * @dev Returns the balance of Token A in the contract.
     * @return uint256 Balance of Token A.
     */
    function getTokenABalance() public view returns (uint256) {
        return tokenA.balanceOf(address(this));
    }

    /**
     * @dev Returns the balance of Token B in the contract.
     * @return uint256 Balance of Token B.
     */
    function getTokenBBalance() public view returns (uint256) {
        return tokenB.balanceOf(address(this));
    }

    /**
     * @dev Calculates the price of a specific amount of Token A in terms of Token B.
     * @param $amountTokenA Amount of Token A.
     * @return uint256 Price of the specified amount of Token A in Token B.
     */
    function getPriceOfA(uint256 $amountTokenA) public view returns (uint256) {
        return (reserveTokenB * $amountTokenA) / reserveTokenA;
    }


    /**
     * @dev Calculates the price of a specific amount of Token B in terms of Token A.
     * @param $amountTokenB Amount of Token B.
     * @return uint256 Price of the specified amount of Token B in Token A.
     */
    function getPriceOfB(uint256 $amountTokenB) public view returns (uint256) {
        return (reserveTokenA * $amountTokenB) / reserveTokenB;
    }


    /**
     * @dev Adds liquidity to the pool for both tokens.
     * Users provide both tokens in proportion to the current pool reserves to maintain the price.
     * Initial liquidity provision sets the initial price ratio between the tokens.
     * If the pool is not empty, the amounts must be in the correct ratio to the reserves.
     * @param $amountTokenA The amount of Token A to add.
     * @param $amountTokenB The amount of Token B to add.
     */
    function addLiquidity(uint256 $amountTokenA, uint256 $amountTokenB)
        external
    {
        uint256 _amountTokenAOptimal;
        uint256 _amountTokenBOptimal;
        if (reserveTokenA == 0 && reserveTokenB == 0) {
            _amountTokenAOptimal = $amountTokenA;
            _amountTokenBOptimal = $amountTokenB;
        } else {
            _amountTokenAOptimal = getPriceOfA($amountTokenA);
            _amountTokenBOptimal = getPriceOfB($amountTokenB);
        }
        tokenA.transferFrom(msg.sender, address(this), _amountTokenAOptimal);
        tokenB.transferFrom(msg.sender, address(this), _amountTokenBOptimal);
        uint256 _liquidity;
        // mint logic
        if (totalSupply() == 0) {
            // calc geometric mean by liquidiity
            _liquidity =
                Math.sqrt(_amountTokenAOptimal * _amountTokenBOptimal) -
                MINIMUM_LIQUIDITY;
        } else {
            uint256 _liquidityA = (_amountTokenAOptimal * totalSupply()) /
                reserveTokenA;
            uint256 _liquidityB = (_amountTokenBOptimal * totalSupply()) /
                reserveTokenB;
            _liquidity = _liquidityA > _liquidityB ? _liquidityB : _liquidityA;
        }
        _mint(msg.sender, _liquidity);
        reserveTokenA -= _amountTokenAOptimal;
        reserveTokenB += _amountTokenBOptimal;
    }

    /**
     * @dev Burns liquidity tokens to withdraw liquidity from the pool.
     * @param $amountLP The amount of liquidity tokens to burn.
     */
    function burn(uint256 $amountLP) external {
        _transfer(msg.sender, address(this), $amountLP);
        uint256 _amountA = ($amountLP * getTokenABalance()) / totalSupply();
        uint256 _amountB = ($amountLP * getTokenBBalance()) / totalSupply();
        _burn(address(this), $amountLP);
        tokenA.transfer(msg.sender, _amountA);
        tokenB.transfer(msg.sender, _amountB);
        reserveTokenA -= _amountA;
        reserveTokenB -= _amountB;
    }

    /**
     * @dev Swaps Token B for an exact amount of Token A.
     * The swap includes a fee of 0.3%, where the multiplication by 1000 represents the total amount 
     * (100%), and the division by 997 accounts for the remaining amount after subtracting the fee (99.7%).
     * @param $amountTokenA The amount of Token A to receive.
     */
    function swapTokenBForExactTokenA(uint256 $amountTokenA) external {
        uint256 _tokenAReserves = reserveTokenA;
        uint256 _tokenBReserves = reserveTokenB;
        uint256 _tokenBRequired = (1000 * ($amountTokenA * _tokenBReserves)) /
            (997 * (_tokenAReserves - $amountTokenA)); // 0.03%, 99.7
        tokenB.transferFrom(msg.sender, address(this), _tokenBRequired);
        tokenA.transfer(msg.sender, $amountTokenA);
        _tokenAReserves -= $amountTokenA;
        _tokenBReserves += _tokenBRequired;
    }

    /**
     * @dev Swaps an exact amount of Token B for Token A.
     * The swap includes a fee of 0.3%, where the multiplication by 1000 represents the total amount 
     * (100%), and the division by 997 accounts for the remaining amount after subtracting the fee (99.7%).
     * @param $amountTokenB The amount of Token B to swap.
     */
    function swapExactTokenBForTokenA(uint256 $amountTokenB) external {
        uint256 _tokenAReserves = reserveTokenA;
        uint256 _tokenBReserves = reserveTokenB;
        // calculate tokenA amount to be transferred
        uint256 _amountTokenA = (_tokenAReserves * $amountTokenB * 997) /
            ((_tokenBReserves * 1000) + ($amountTokenB * 997));
        
        tokenB.transferFrom(msg.sender, address(this), $amountTokenB);
        // transfer tokenA to the user
        tokenA.transfer(msg.sender, _amountTokenA);
        reserveTokenA -= _amountTokenA;
        reserveTokenB += $amountTokenB;
    }

    /**
     * @dev Swaps Token A for an exact amount of Token B.
     * The swap includes a fee of 0.3%, where the multiplication by 1000 represents the total amount 
     * (100%), and the division by 997 accounts for the remaining amount after subtracting the fee (99.7%).
     * @param $amountTokenB The amount of Token B to receive.
     */
    function swapTokenAForExactTokenB(uint256 $amountTokenB) external {
        uint256 _tokenAReserves = reserveTokenA;
        uint256 _tokenBReserves = reserveTokenB;
        // calculate amount of tokenA required against _amountTokenB
        uint256 _amountTokenARequired = (_tokenAReserves *
            $amountTokenB *
            1000) / (997 * (_tokenBReserves + $amountTokenB));

        // tokenA is transferred from user to this contract
        tokenA.transferFrom(msg.sender, address(this), _amountTokenARequired);
        // transfer _amountTokenB tokenB to user
        tokenB.transfer(msg.sender, $amountTokenB);
        reserveTokenA += _amountTokenARequired;
        reserveTokenB -= $amountTokenB;
    }

    /**
     * @dev Swaps an exact amount of Token A for Token B.
     * The swap includes a fee of 0.3%, where the multiplication by 1000 represents the total amount 
     * (100%), and the division by 997 accounts for the remaining amount after subtracting the fee (99.7%).
     * @param $amountTokenA The amount of Token A to swap.
     */
    function swapExactTokenAForTokenB(uint256 $amountTokenA) external {
        uint256 _tokenAReserves = reserveTokenA;
        uint256 _tokenBReserves = reserveTokenB;
        // calculate tokenB amount to be transferred
      uint256 _amountTokenB = (_tokenBReserves * $amountTokenA * 997) /
            ((_tokenAReserves * 1000) + (997 * $amountTokenA));
        // _amountTokenA is transfered from user to this contract
        tokenA.transferFrom(msg.sender, address(this), $amountTokenA);
        // transfer tokenB to the user
        tokenB.transfer(msg.sender, _amountTokenB);
        reserveTokenA += $amountTokenA;
        reserveTokenB -= _amountTokenB;
    }   
}