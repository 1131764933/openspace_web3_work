// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDex {
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex is IDex {
    IUniswapV2Router02 public uniswapRouter;

    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = buyToken;

        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        address[] memory path = new address[](2);
        path[0] = sellToken;
        path[1] = uniswapRouter.WETH();

        IERC20(sellToken).transferFrom(msg.sender, address(this), sellAmount);
        IERC20(sellToken).approve(address(uniswapRouter), sellAmount);

        uniswapRouter.swapExactTokensForETH(
            sellAmount,
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp
        );
    }

    receive() external payable {}
}
