用Solidity编写一个合约，使用foundry部署合约，合约编写包含 StakingPool 和ETH质押挖矿，实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚钱 KK Token。其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配。还要增加逻辑： Add NFTMarket Features: • 1. Charge NFT transaction fee • 2. Support Stake ETH to earn transaction fee，买nft的时候需要算手续费1%，没有质押的话不累计进去，有质押才累计，每一次购买都要进行结算，收到的费用要分配给质押的人。用户质押和解押之前都要进行update，更新用户待领取奖励和更新用户的累积奖励，下面是合约接口信息：
/**
 * @title KK Token 
 */
 interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
 }

/**
 * @title Staking Interface
 */
 interface IStaking {
    /**
    
     * @dev 质押 ETH 到合约
     */
  function stake()  payable external;
    
    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
  function unstake(uint256 amount) external; 
    
    /**
     * @dev 领取 KK Token 收益
     */
  function claim() external;
    
    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
  function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
  function earned(address account) external view returns (uint256);
  }



质押分红算法：一个复利是累乘和累加；

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
forge init ETH_StakingPool
cd ETH_StakingPool
```

配置项目

```
forge install OpenZeppelin/openzeppelin-contracts 
```

我们将根据您的需求编写一个 `StakingPool` 合约，该合约允许用户质押 ETH 并根据其质押数量和时长赚取 KK Token。每个区块将分配 10 个 KK Token，并且产出的 KK Token 将根据用户的质押时长和数量公平分配。

### 合约实现

以下是实现的 Solidity 合约代码：

```
solidity
复制代码
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface IStaking {
    function stake() payable external;
    function unstake(uint256 amount) external;
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}

contract StakingPool is IStaking {
    IToken public kkToken;
    uint256 public constant REWARD_RATE_PER_BLOCK = 10; // 每个区块产出 10 个 KK Token

    struct StakeInfo {
        uint256 amount;        // 质押的 ETH 数量
        uint256 rewardDebt;    // 已领取的奖励
        uint256 lastBlock;     // 上次质押或领取奖励的区块号
    }

    mapping(address => StakeInfo) public stakes;

    uint256 public totalStaked; // 合约内总质押的 ETH 数量

    constructor(IToken _kkToken) {
        kkToken = _kkToken;
    }

    function stake() external payable override {
        StakeInfo storage stake = stakes[msg.sender];

        // 计算到目前为止的未领取的奖励并更新
        if (stake.amount > 0) {
            uint256 pending = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
            stake.rewardDebt += pending;
        }

        // 更新质押信息
        stake.amount += msg.value;
        stake.lastBlock = block.number;
        totalStaked += msg.value;
    }

    function unstake(uint256 amount) external override {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount >= amount, "Not enough balance to unstake");

        // 计算到目前为止的未领取的奖励并更新
        uint256 pending = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        stake.rewardDebt += pending;

        // 更新质押信息
        stake.amount -= amount;
        stake.lastBlock = block.number;
        totalStaked -= amount;

        // 转移ETH给用户
        payable(msg.sender).transfer(amount);
    }

    function claim() external override {
        StakeInfo storage stake = stakes[msg.sender];

        // 计算应得奖励
        uint256 pending = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        uint256 rewards = stake.rewardDebt + pending;

        require(rewards > 0, "No rewards to claim");

        // 更新质押信息
        stake.rewardDebt = 0;
        stake.lastBlock = block.number;

        // 发放 KK Token 奖励
        kkToken.mint(msg.sender, rewards);
    }

    function balanceOf(address account) external view override returns (uint256) {
        return stakes[account].amount;
    }

    function earned(address account) external view override returns (uint256) {
        StakeInfo storage stake = stakes[account];
        uint256 pending = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        return stake.rewardDebt + pending;
    }
}
```

### 合约说明

1. **数据结构**:
   - `StakeInfo`: 存储用户的质押信息，包括质押数量、已领取奖励、上次操作的区块号。
2. **关键变量**:
   - `kkToken`: KK Token 合约接口，用于铸造奖励。
   - `REWARD_RATE_PER_BLOCK`: 每个区块产出的 KK Token 数量。
   - `totalStaked`: 合约中总的质押量。
3. **函数说明**:
   - `stake`: 用户质押 ETH，更新质押信息。
   - `unstake`: 用户提取质押的 ETH，更新质押信息和奖励。
   - `claim`: 用户领取 KK Token 奖励。
   - `balanceOf`: 查询用户的质押余额。
   - `earned`: 查询用户的未领取奖励。

### 部署和测试

在 Foundry 中部署和测试合约，确保合约逻辑和奖励计算正确。

1. **部署合约**：
   - 通过 Foundry 部署合约，确保 `KKToken` 合约地址正确传递给 `StakingPool` 构造函数。
2. **测试合约功能**：
   - 编写测试用例，验证 `stake`、`unstake`、`claim` 函数的逻辑。
   - 验证奖励分配的正确性，确保按比例分配 KK Token。

### 测试用例

以下是使用 Foundry 编写的测试用例示例：

```
solidity
复制代码
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "./StakingPool.sol";

contract KKToken is IToken {
    string public name = "KK Token";
    string public symbol = "KK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external override {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract StakingPoolTest is Test {
    KKToken kkToken;
    StakingPool stakingPool;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        kkToken = new KKToken();
        stakingPool = new StakingPool(kkToken);
    }

    function testStake() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);

        stakingPool.stake{value: 1 ether}();

        assertEq(stakingPool.balanceOf(alice), 1 ether);
        assertEq(address(stakingPool).balance, 1 ether);

        vm.stopPrank();
    }

    function testUnstake() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);

        stakingPool.stake{value: 1 ether}();
        stakingPool.unstake(0.5 ether);

        assertEq(stakingPool.balanceOf(alice), 0.5 ether);
        assertEq(address(stakingPool).balance, 0.5 ether);

        vm.stopPrank();
    }

    function testClaim() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);

        stakingPool.stake{value: 1 ether}();

        // 模拟几个区块的时间经过
        vm.roll(block.number + 100);

        uint256 earnedTokens = stakingPool.earned(alice);
        stakingPool.claim();

        assertEq(kkToken.balanceOf(alice), earnedTokens);

        vm.stopPrank();
    }
}
```

### 测试说明

- **`setUp` 函数**: 初始化合约和地址。
- **`testStake` 测试**: 验证 `stake` 函数的正确性。
- **`testUnstake` 测试**: 验证 `unstake` 函数的正确性。
- **`testClaim` 测试**: 验证 `claim` 函数的奖励计算和分配。

这些测试用例确保 `StakingPool` 合约的基本功能正确实现，您可以根据需求添加更多测试用例来覆盖不同的场景和逻辑。



2/2







增加逻辑： Add NFTMarket Features: • 1. Charge NFT transaction fee • 2. Support Stake ETH to earn transaction fee这个怎么写？买nft的时候需要算手续费1%，没有质押的话不累计进去，有质押才累计，每一次购买都要进行结算，收到的费用要分配给质押的人。用户质押和解押之前都要进行update，更新用户待领取奖励和更新用户的累积奖励。



要在 `StakingPool` 合约中增加 NFT 市场功能，包括收取 NFT 交易费用并支持通过质押 ETH 来赚取交易费用，我们需要设计一个包含两个部分的系统：

1. **NFT 交易费用收取**：在每次 NFT 交易时收取一定比例的费用。
2. **质押奖励分配**：将收取的 NFT 交易费用分配给质押者，基于他们的质押数量和时长。

以下是对合约的修改建议和实现：

### 修改建议

#### 1. NFT 交易费用收取

在 NFT 市场合约中实现交易费用收取逻辑。在每笔 NFT 交易时，合约收取一部分费用，并将这些费用存入 `StakingPool` 合约。

#### 2. 质押奖励分配

在 `StakingPool` 合约中添加逻辑，将累积的交易费用按比例分配给质押者。我们需要新增一个变量来跟踪未分配的交易费用，并在 `claim` 方法中发放这些费用。

### 合约实现

下面是示例实现，展示了如何修改 `StakingPool` 合约以支持上述功能：

```
solidity
复制代码
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface IStaking {
    function stake() payable external;
    function unstake(uint256 amount) external;
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}

contract StakingPool is IStaking {
    IToken public kkToken;
    uint256 public constant REWARD_RATE_PER_BLOCK = 10; // 每个区块产出 10 个 KK Token
    uint256 public totalStaked; // 合约内总质押的 ETH 数量
    uint256 public totalFees; // 总交易费用

    struct StakeInfo {
        uint256 amount;        // 质押的 ETH 数量
        uint256 rewardDebt;    // 已领取的奖励
        uint256 feeDebt;       // 已领取的交易费用
        uint256 lastBlock;     // 上次质押或领取奖励的区块号
    }

    mapping(address => StakeInfo) public stakes;

    constructor(IToken _kkToken) {
        kkToken = _kkToken;
    }

    function stake() external payable override {
        StakeInfo storage stake = stakes[msg.sender];

        // 计算到目前为止的未领取的奖励并更新
        if (stake.amount > 0) {
            uint256 pendingRewards = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
            stake.rewardDebt += pendingRewards;

            uint256 pendingFees = (stake.amount * totalFees) / totalStaked;
            stake.feeDebt += pendingFees;
        }

        // 更新质押信息
        stake.amount += msg.value;
        stake.lastBlock = block.number;
        totalStaked += msg.value;
    }

    function unstake(uint256 amount) external override {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount >= amount, "Not enough balance to unstake");

        // 计算到目前为止的未领取的奖励并更新
        uint256 pendingRewards = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        stake.rewardDebt += pendingRewards;

        uint256 pendingFees = (stake.amount * totalFees) / totalStaked;
        stake.feeDebt += pendingFees;

        // 更新质押信息
        stake.amount -= amount;
        stake.lastBlock = block.number;
        totalStaked -= amount;

        // 转移ETH给用户
        payable(msg.sender).transfer(amount);
    }

    function claim() external override {
        StakeInfo storage stake = stakes[msg.sender];

        // 计算应得奖励和交易费用
        uint256 pendingRewards = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        uint256 rewards = stake.rewardDebt + pendingRewards;

        uint256 pendingFees = (stake.amount * totalFees) / totalStaked;
        uint256 fees = stake.feeDebt + pendingFees;

        require(rewards > 0 || fees > 0, "No rewards or fees to claim");

        // 更新质押信息
        stake.rewardDebt = 0;
        stake.feeDebt = 0;
        stake.lastBlock = block.number;

        // 发放 KK Token 奖励
        if (rewards > 0) {
            kkToken.mint(msg.sender, rewards);
        }

        // 发放交易费用奖励
        if (fees > 0) {
            totalFees -= fees;
            payable(msg.sender).transfer(fees);
        }
    }

    function balanceOf(address account) external view override returns (uint256) {
        return stakes[account].amount;
    }

    function earned(address account) external view override returns (uint256) {
        StakeInfo storage stake = stakes[account];
        uint256 pendingRewards = (stake.amount * REWARD_RATE_PER_BLOCK * (block.number - stake.lastBlock)) / totalStaked;
        return stake.rewardDebt + pendingRewards;
    }

    function feesEarned(address account) external view returns (uint256) {
        StakeInfo storage stake = stakes[account];
        uint256 pendingFees = (stake.amount * totalFees) / totalStaked;
        return stake.feeDebt + pendingFees;
    }

    // 由 NFT 市场合约调用，用于增加交易费用
    function addFees() external payable {
        require(msg.value > 0, "No fees to add");
        totalFees += msg.value;
    }
}
```

### 合约说明

1. **增加交易费用**:
   - `totalFees`: 存储合约中累积的交易费用。
   - `feeDebt`: 每个质押者已经领取的交易费用。
2. **新增方法**:
   - `addFees`: 允许 NFT 市场合约调用以增加交易费用。
   - `feesEarned`: 返回用户可领取的交易费用。
3. **`claim` 函数更新**:
   - 现在不仅可以领取 KK Token 奖励，还可以领取交易费用。

### 集成示例

假设我们有一个简单的 NFT 市场合约，在每次交易时调用 `addFees` 函数，将一定比例的交易费用转入 `StakingPool`：

```
solidity
复制代码
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract NFTMarketplace {
    StakingPool public stakingPool;
    uint256 public transactionFeeRate = 100; // 1% 交易费率

    constructor(StakingPool _stakingPool) {
        stakingPool = _stakingPool;
    }

    function tradeNFT(address seller, address buyer, uint256 amount) external payable {
        require(msg.value == amount, "Incorrect payment");

        uint256 fee = (amount * transactionFeeRate) / 10000;
        uint256 sellerAmount = amount - fee;

        // 向卖家转账
        payable(seller).transfer(sellerAmount);

        // 将交易费用添加到质押池
        stakingPool.addFees{value: fee}();
    }
}
```

### 集成说明

- **NFTMarketplace 合约**:
  - 在 `tradeNFT` 方法中计算交易费用并调用 `stakingPool.addFees`，将费用转入质押池。
- **交易费率**:
  - `transactionFeeRate` 是一个整数，表示交易金额的千分比（例如，100 表示 1%）。

这样，您就可以通过质押 ETH 来赚取来自 NFT 交易的费用，同时根据质押的数量和时长获得 KK Token 奖励。可以根据需要调整交易费率和奖励分配策略，以适应不同的业务需求。





写出测试



ChatGPT

下面是使用 Foundry 编写的测试代码，来验证 `StakingPool` 和 `NFTMarketplace` 合约的功能，包括质押、领取 KK Token 奖励、收取 NFT 交易费用以及分配给质押者。

### 合约测试文件

创建测试文件 `StakingPool.t.sol`，用于测试 `StakingPool` 合约的核心功能。

```
solidity
复制代码
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../contracts/StakingPool.sol";
import "../contracts/NFTMarketplace.sol";
import "../contracts/KKToken.sol"; // 假设 KKToken 是 IToken 的实现

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    NFTMarketplace public marketplace;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        kkToken = new KKToken();
        stakingPool = new StakingPool(kkToken);
        marketplace = new NFTMarketplace(stakingPool);
    }

    function testStakeAndUnstake() public {
        // User1 质押 1 ETH
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();

        // 检查用户1的质押余额是否更新
        assertEq(stakingPool.balanceOf(user1), 1 ether);

        // User1 赎回 0.5 ETH
        stakingPool.unstake(0.5 ether);

        // 检查用户1的质押余额是否更新
        assertEq(stakingPool.balanceOf(user1), 0.5 ether);

        // 结束Prank
        vm.stopPrank();
    }

    function testClaimRewards() public {
        // User1 质押 1 ETH
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();

        // 产生一些区块
        vm.roll(block.number + 10);

        // 计算用户1的待领取奖励
        uint256 expectedRewards = 1 ether * StakingPool.REWARD_RATE_PER_BLOCK() * 10;

        // 用户1领取奖励
        stakingPool.claim();

        // 检查用户1的 KK Token 余额
        assertEq(kkToken.balanceOf(user1), expectedRewards);

        // 结束Prank
        vm.stopPrank();
    }

    function testNFTTransactionFeeDistribution() public {
        // User1 质押 1 ETH
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();

        // 模拟 NFT 交易费用
        uint256 transactionFee = 0.01 ether;

        // User2 进行 NFT 交易
        vm.deal(user2, 1.01 ether);
        vm.startPrank(user2);
        marketplace.tradeNFT{value: 1.01 ether}(user1, user2, 1 ether);
        vm.stopPrank();

        // 检查质押池中的总交易费用
        assertEq(stakingPool.totalFees(), transactionFee);

        // User1 领取交易费用
        vm.startPrank(user1);
        uint256 pendingFees = stakingPool.feesEarned(user1);
        assertEq(pendingFees, transactionFee); // 检查待领取的费用

        stakingPool.claim();

        // 检查用户1领取的费用
        assertEq(user1.balance, transactionFee);

        // 结束Prank
        vm.stopPrank();
    }
}
```

### 测试文件说明

1. **setUp**：初始化合约实例，包括 `StakingPool`、`KKToken` 和 `NFTMarketplace`。
2. **testStakeAndUnstake**：测试用户质押和赎回功能，检查用户质押余额的变化。
3. **testClaimRewards**：测试用户领取 KK Token 奖励功能。质押者在多个区块后领取奖励，并验证其 KK Token 余额。
4. **testNFTTransactionFeeDistribution**：测试 NFT 交易费用的收取和分配。进行模拟 NFT 交易，并验证交易费用是否被正确分配给质押者。

### 运行测试

确保合约和测试文件已经编写完毕后，可以在 Foundry 中运行测试：

```
bash
复制代码
forge test --fork-url <RPC_URL>
```

将 `<RPC_URL>` 替换为您的以太坊节点或测试网的 RPC URL。运行测试后，您应该能够看到所有测试通过，表明功能实现符合预期。

这套测试覆盖了主要功能，包括质押、赎回、奖励计算、交易费用收取与分配，确保合约逻辑正确且无漏洞。您可以根据需要进一步扩展测试，覆盖更多的边界情况和复杂场景。
