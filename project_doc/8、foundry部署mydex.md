

部署自己的 UniswapV2 Dex
编写 MyDex 合约，任何人都可通过 MyDex 来买卖ETH，任何人都可以通过 `sellETH` 方法出售ETH兑换成 USDT，也可以通过 `buyETH` 将 USDT 兑换成 ETH。
下方是MyDex接口规范。

```
interface IDex {

    /**
     * @dev 卖出ETH，兑换成 buyToken
     *      msg.value 为出售的ETH数量
     * @param buyToken 兑换的目标代币地址
     * @param minBuyAmount 要求最低兑换到的 buyToken 数量
     */
    function sellETH(address buyToken,uint256 minBuyAmount) external payable  

    /**
     * @dev 买入ETH，用 sellToken 兑换
     * @param sellToken 出售的代币地址
     * @param sellAmount 出售的代币数量
     * @param minBuyAmount 要求最低兑换到的ETH数量
     */
    function buyETH(address sellToken,uint256 sellAmount,uint256 minBuyAmount) external   
}
```

Test合约测试：创建RNT-ETH交易对、添加初始化流动性、移除流动性、使用 RNT兑换 ETH，用 ETH兑换RNT

以下是详细的实现步骤：

### 1. 设置 Foundry 项目

首先，确保你已经安装了 Foundry。如果没有，请按照 Foundry 的文档进行安装。

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 创建 Foundry 项目

创建一个新的 Foundry 项目：

```
forge init my_DEX
cd my_DEX
```

配置项目

```
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install uniswap/v2-core --no-commit
forge install uniswap/v2-periphery --no-commit
```

末尾的`--no-commit`标志。这是因为你的项目文件夹已经与 git 存储库关联，所以我们必须指定不提交任何内容。

现在，让我们通过填写我们之前创建的**remappings.txt**文件来将导入配置到正确的路径。

```
vim remappings.txt
```

向文件中添加以下配置：

```
@uniswap/v2-core/=lib/v2-core/
@uniswap/v2-periphery/=lib/v2-periphery/
@openzeppelin/=lib/openzeppelin-contracts/

```



最后，让我们在环境中设置我们的私钥，使用以下变量名和你的私钥。在你的终端中运行以下命令，并将**YOUR_PRVATE_KEY**占位符更新为你的实际私钥。

```sh
export PRIVATE_KEY=YOUR_PRIVATE_KEY
```

首先,让我们实现 MyDex 合约:

```
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

```

这个 MyDex 合约实现了你要求的 `sellETH` 和 `buyETH` 功能。它使用 Uniswap V2 的路由器来执行实际的交换操作。

为了正确测试你的 DEX 合约，你需要一个部署好的 Uniswap V2 环境。我们可以使用 Foundry 提供的主网 fork 功能来模拟真实的 Uniswap V2 环境。

**创建测试环境：**

在 `foundry.toml` 文件中添加配置，启用主网 fork：

```
[anvil]
fork_url = "https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID"
```

现在,让我们创建一个 MyDexTest.sol 合约来测试 MyDex 的功能:

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MyDex.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract MyDexTest is Test {
    MyDex public myDex;
    MockERC20 public rnt;
    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;
    address public WETH;

    function setUp() public {
        // 部署 Mock ERC20 代币
        rnt = new MockERC20("Random Token", "RNT");

        // 使用真实的 Uniswap V2 路由器地址（例如：0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D）
        uniswapRouter = IUniswapV2Router02(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
        WETH = uniswapRouter.WETH();

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
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(rnt),
            rntAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        assertTrue(pairContract.balanceOf(address(this)) > 0, "Failed to add liquidity");
    }

    function testRemoveLiquidity() public {
        // 首先添加流动性
        testCreatePairAndAddLiquidity();

        // 获取交易对地址
        address pair = uniswapFactory.getPair(address(rnt), WETH);
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);

        // 获取 LP 代币余额
        uint256 liquidity = pairContract.balanceOf(address(this));

        // 批准 LP 代币
        pairContract.approve(address(uniswapRouter), liquidity);

        // 移除流动性
        uniswapRouter.removeLiquidityETH(
            address(rnt),
            liquidity,
            0,
            0,
            address(this),
            block.timestamp
        );

        assertTrue(pairContract.balanceOf(address(this)) == 0, "Failed to remove all liquidity");
    }

    function testSwapRNTForETH() public {
        // 首先添加流动性
        testCreatePairAndAddLiquidity();

        uint256 rntAmount = 10 * 10**18;
        uint256 minEthAmount = 0.005 ether;

        uint256 initialEthBalance = address(this).balance;

        rnt.approve(address(myDex), rntAmount);
        myDex.buyETH(address(rnt), rntAmount, minEthAmount);

        assertTrue(address(this).balance > initialEthBalance, "Failed to receive ETH");
    }

    function testSwapETHForRNT() public {
        // 首先添加流动性
        testCreatePairAndAddLiquidity();

        uint256 ethAmount = 0.1 ether;
        uint256 minRntAmount = 10 * 10**18;

        uint256 initialRntBalance = rnt.balanceOf(address(this));

        myDex.sellETH{value: ethAmount}(address(rnt), minRntAmount);

        assertTrue(rnt.balanceOf(address(this)) > initialRntBalance, "Failed to receive RNT");
    }

    receive() external payable {}
}

```

这个测试合约实现了你要求的所有测试场景:

1. 创建 RNT-ETH 交易对
2. 添加初始化流动性
3. 移除流动性
4. 使用 RNT 兑换 ETH
5. 用 ETH 兑换 RNT

要运行这些测试,你需要在 Foundry 环境中执行以下命令:

```
forge test -vvvv
```





使用 Foundry 来 fork 以太坊主网并测试你的 MyDex 和 Test 合约。它涵盖了从配置项目到运行和分析测试结果的整个过程。

主要的变化包括:

1. 我们不再使用模拟的 ERC20 代币,而是使用主网上真实存在的 DAI 代币。
2. 我们使用了主网上实际的 Uniswap V2 合约地址。
3. 我们使用 Foundry 的 `vm` 功能来模拟 ETH 和 DAI 余额,以便进行测试。
4. 测试用例被简化为直接测试 ETH 和 DAI 之间的兑换。

按照这个指南,你应该能够在一个非常接近真实环境的设置中测试你的 MyDex 合约。这种方法的优势在于它可以测试你的合约与实际部署在主网上的其他合约的交互,从而提供更可靠的测试结果。

# Foundry Fork 测试指南

本指南将帮助你使用 Foundry 来 fork 以太坊主网并测试 MyDex 和 Test 合约。

## 1. 准备工作

确保你已经安装了 Foundry 并设置好了项目。如果还没有,请参考之前的说明进行安装和设置。

## 2. 配置 Foundry 项目

1. 打开 `foundry.toml` 文件,添加或修改以下配置:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "@uniswap/v2-core/=lib/v2-core/",
    "@uniswap/v2-periphery/=lib/v2-periphery/"
]

[rpc_endpoints]
mainnet = "${ETH_RPC_URL}"
```

2. 设置环境变量:

在终端中运行:

```bash
export ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY
```

将 `YOUR-API-KEY` 替换为你的实际 Alchemy 或 Infura API 密钥。

## 3. 修改测试合约

修改 `test/MyDexTest.sol` 文件,使其适应主网 fork 测试:

1. 移除 MockERC20 合约
2. 使用主网上已存在的代币地址
3. 使用主网上的 Uniswap V2 合约地址

以下是修改后的测试合约示例:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MyDex.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MyDexTest is Test {
    MyDex public myDex;
    IERC20 public dai;
    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;
    address public WETH;

    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        // Use mainnet contract addresses
        uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER);
        uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
        WETH = uniswapRouter.WETH();
        dai = IERC20(DAI_ADDRESS);

        // Deploy MyDex
        myDex = new MyDex(UNISWAP_ROUTER);

        // Fund this contract with some ETH and DAI for testing
        vm.deal(address(this), 100 ether);
        deal(DAI_ADDRESS, address(this), 100000 * 10**18);

        // Approve tokens for router and MyDex
        dai.approve(UNISWAP_ROUTER, type(uint256).max);
        dai.approve(address(myDex), type(uint256).max);
    }

    function testSwapDAIForETH() public {
        uint256 daiAmount = 1000 * 10**18;
        uint256 minEthAmount = 0.1 ether;

        uint256 initialEthBalance = address(this).balance;

        myDex.buyETH(DAI_ADDRESS, daiAmount, minEthAmount);

        assertGt(address(this).balance, initialEthBalance, "Failed to receive ETH");
    }

    function testSwapETHForDAI() public {
        uint256 ethAmount = 1 ether;
        uint256 minDaiAmount = 1000 * 10**18;

        uint256 initialDaiBalance = dai.balanceOf(address(this));

        myDex.sellETH{value: ethAmount}(DAI_ADDRESS, minDaiAmount);

        assertGt(dai.balanceOf(address(this)), initialDaiBalance, "Failed to receive DAI");
    }

    function testRescueTokens() public {
        // Send some DAI to the MyDex contract
        uint256 amount = 100 * 10**18;
        dai.transfer(address(myDex), amount);

        // Try to rescue tokens (should fail as we're not the factory)
        vm.expectRevert("Only factory can rescue tokens");
        myDex.rescueTokens(DAI_ADDRESS, amount);

        // Pretend to be the factory and rescue tokens
        vm.prank(address(uniswapFactory));
        myDex.rescueTokens(DAI_ADDRESS, amount);

        assertEq(dai.balanceOf(address(uniswapFactory)), amount, "Failed to rescue tokens");
    }

    receive() external payable {}
}
```

## 4. 运行测试

在终端中运行以下命令来执行测试:

```bash
forge test -vv
```

`-vv` 参数会显示更详细的输出,包括每个测试的气体使用情况。

## 5. 分析结果

测试完成后,Foundry 会显示每个测试的结果,包括是否通过、气体使用量等信息。

如果测试失败,仔细查看错误信息并相应地调整你的合约或测试用例。

## 注意事项

1. 确保你的 RPC 提供商(如 Alchemy 或 Infura)有足够的配额来支持你的测试。
2. Fork 测试会比本地测试慢,因为它需要从远程节点获取数据。
3. 每次运行测试时,都会创建一个新的 fork,所以状态不会在测试运行之间保持。
4. 如果你需要在特定区块进行测试,可以在 `setUp()` 函数中使用 `vm.createSelectFork(vm.envString("ETH_RPC_URL"), BLOCK_NUMBER);`

通过这种方式,你可以在接近真实的环境中测试你的 MyDex 合约,确保它能在主网上正常工作。
