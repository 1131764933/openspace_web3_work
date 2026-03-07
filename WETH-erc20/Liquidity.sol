// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract WETHLiquidityPool is ERC20 {
    using SafeERC20 for IERC20;

    address public WETH;
    address public token;  // 另一种ERC20代币
    uint256 public constant FEE_RATE = 3;  // 0.3% 交易手续费

    // 初始化时指定WETH和另一种ERC20代币
    constructor(address _WETH, address _token) ERC20("Liquidity Pool Token", "LP") {
        WETH = _WETH;
        token = _token;
    }

    // 添加流动性，提供者将WETH和另一种ERC20代币注入池中，获得流动性代币
    function addLiquidity(uint256 WETHAmount, uint256 tokenAmount) external {
        require(WETHAmount > 0 && tokenAmount > 0, "Invalid amounts");

        IERC20(WETH).safeTransferFrom(msg.sender, address(this), WETHAmount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);

        uint256 liquidity = _sqrt(WETHAmount * tokenAmount);
        _mint(msg.sender, liquidity);  // 发放流动性代币
    }

    // 移除流动性，流动性提供者可以用LP代币取回WETH和另一种ERC20代币
    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Invalid liquidity amount");

        uint256 totalSupply = totalSupply();
        uint256 WETHAmount = (IERC20(WETH).balanceOf(address(this)) * liquidity) / totalSupply;
        uint256 tokenAmount = (IERC20(token).balanceOf(address(this)) * liquidity) / totalSupply;

        _burn(msg.sender, liquidity);

        IERC20(WETH).safeTransfer(msg.sender, WETHAmount);
        IERC20(token).safeTransfer(msg.sender, tokenAmount);
    }

    // 用WETH兑换另一种ERC20代币
    function swapWETHForToken(uint256 WETHAmount) external {
        require(WETHAmount > 0, "Invalid WETH amount");

        uint256 WETHBalance = IERC20(WETH).balanceOf(address(this));
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));

        uint256 WETHAmountWithFee = WETHAmount * (1000 - FEE_RATE) / 1000;
        uint256 tokenOut = (WETHAmountWithFee * tokenBalance) / (WETHBalance + WETHAmountWithFee);

        require(tokenOut > 0, "Insufficient output amount");

        IERC20(WETH).safeTransferFrom(msg.sender, address(this), WETHAmount);
        IERC20(token).safeTransfer(msg.sender, tokenOut);
    }

    // 用另一种ERC20代币兑换WETH
    function swapTokenForWETH(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Invalid token amount");

        uint256 WETHBalance = IERC20(WETH).balanceOf(address(this));
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));

        uint256 tokenAmountWithFee = tokenAmount * (1000 - FEE_RATE) / 1000;
        uint256 WETHOut = (tokenAmountWithFee * WETHBalance) / (tokenBalance + tokenAmountWithFee);

        require(WETHOut > 0, "Insufficient output amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        IERC20(WETH).safeTransfer(msg.sender, WETHOut);
    }

    // 内部函数：计算平方根
    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}