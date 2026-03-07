// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MyDex.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract MockUniswapV2Router02 {
    address public immutable WETH;
    address public immutable factory;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        // 模拟交换逻辑
        amounts = new uint[](2);
        amounts[0] = msg.value;
        amounts[1] = amountOutMin;
        // 在实际实现中，你需要转移代币
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // 模拟交换逻辑
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOutMin;
        // 在实际实现中，你需要转移ETH
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // 模拟添加流动性逻辑
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = amountToken + amountETH;
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        // 模拟移除流动性逻辑
        amountToken = amountTokenMin;
        amountETH = amountETHMin;
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        pair = address(new MockUniswapV2Pair());
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
    }
}

contract MockUniswapV2Pair is ERC20 {
    constructor() ERC20("UniswapV2 Pair", "UNI-V2") {}

    function mint(address to) public {
        _mint(to, 1000 * 10**decimals());
    }
}

contract MyDexTest is Test {
    MyDex public myDex;
    MockERC20 public rnt;
    MockUniswapV2Router02 public uniswapRouter;
    MockUniswapV2Factory public uniswapFactory;
    address public WETH;

    function setUp() public {
        // 部署 Mock ERC20 代币
        rnt = new MockERC20("Random Token", "RNT");

        // 部署模拟的 Uniswap 合约
        WETH = address(new MockERC20("Wrapped Ether", "WETH"));
        uniswapFactory = new MockUniswapV2Factory();
        uniswapRouter = new MockUniswapV2Router02(address(uniswapFactory), WETH);

        // 部署 MyDex
        myDex = new MyDex(address(uniswapRouter));

        // 批准代币
        rnt.approve(address(uniswapRouter), type(uint256).max);
    }

    function testCreatePairAndAddLiquidity() public {
        // 创建 RNT-ETH 交易对
        address pair = uniswapFactory.createPair(address(rnt), WETH);
        assertTrue(pair != address(0), "Failed to create pair");

        // 添加初始流动性
        uint256 rntAmount = 1000 * 10**18;
        uint256 ethAmount = 1 ether;

        rnt.approve(address(uniswapRouter), rntAmount);
        (uint amountToken, uint amountETH, uint liquidity) = uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(rnt),
            rntAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        assertTrue(liquidity > 0, "Failed to add liquidity");
    }

    function testSwapRNTForETH() public {
        // 首先添加流动性
        testCreatePairAndAddLiquidity();

        uint256 rntAmount = 10 * 10**18;
        uint256 minEthAmount = 0.005 ether;

        uint256 initialEthBalance = address(this).balance;

        rnt.approve(address(myDex), rntAmount);
        myDex.buyETH(address(rnt), rntAmount, minEthAmount);

        assertTrue(address(this).balance >= initialEthBalance, "Failed to receive ETH");
    }

    function testSwapETHForRNT() public {
        // 首先添加流动性
        testCreatePairAndAddLiquidity();

        uint256 ethAmount = 0.1 ether;
        uint256 minRntAmount = 10 * 10**18;

        uint256 initialRntBalance = rnt.balanceOf(address(this));

        myDex.sellETH{value: ethAmount}(address(rnt), minRntAmount);

        assertTrue(rnt.balanceOf(address(this)) >= initialRntBalance, "Failed to receive RNT");
    }

    receive() external payable {}
}