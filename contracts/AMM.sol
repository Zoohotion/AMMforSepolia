// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AMM {
    IERC20 public tokenA; // SYX
    IERC20 public tokenB; // ZHC

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shareMinted
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shareBurned
    );

    event Swap(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "tokenA address invalid");
        require(_tokenB != address(0), "tokenB address invalid");
        require(_tokenA != _tokenB, "same token address");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 share) {
        require(amountA > 0 && amountB > 0, "amounts must be > 0");

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "tokenA transfer failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "tokenB transfer failed");

        if (totalShares == 0) {
            share = _sqrt(amountA * amountB);
        } else {
            uint256 shareA = (amountA * totalShares) / reserveA;
            uint256 shareB = (amountB * totalShares) / reserveB;
            share = _min(shareA, shareB);
        }

        require(share > 0, "share = 0");

        shares[msg.sender] += share;
        totalShares += share;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, share);
    }

    function removeLiquidity(uint256 share) external returns (uint256 amountA, uint256 amountB) {
        require(share > 0, "share must be > 0");
        require(shares[msg.sender] >= share, "not enough share");

        amountA = (share * reserveA) / totalShares;
        amountB = (share * reserveB) / totalShares;

        require(amountA > 0 && amountB > 0, "amounts = 0");

        shares[msg.sender] -= share;
        totalShares -= share;

        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "tokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "tokenB transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, share);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn must be > 0");
        require(reserveIn > 0 && reserveOut > 0, "invalid reserves");

        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function swapSYXForZHC(uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn must be > 0");

        amountOut = getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut > 0, "amountOut = 0");
        require(amountOut < reserveB, "not enough liquidity");

        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "tokenA transfer failed");
        require(tokenB.transfer(msg.sender, amountOut), "tokenB transfer failed");

        reserveA += amountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), amountIn, address(tokenB), amountOut);
    }

    function swapZHCForSYX(uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn must be > 0");

        amountOut = getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut > 0, "amountOut = 0");
        require(amountOut < reserveA, "not enough liquidity");

        require(tokenB.transferFrom(msg.sender, address(this), amountIn), "tokenB transfer failed");
        require(tokenA.transfer(msg.sender, amountOut), "tokenA transfer failed");

        reserveB += amountIn;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), amountIn, address(tokenA), amountOut);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }
}