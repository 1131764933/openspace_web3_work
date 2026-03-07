基于第三方服务实现合约自动化调用



先实现一个 Bank 合约， 用户可以通过 `deposit()` 存款， 然后使用 ChainLink Automation 、Gelato 或 OpenZepplin Defender Action 实现一个自动化任务， 自动化任务实现：当 Bank 合约的存款超过 x (可自定义数量)时， 转移一半的存款到指定的地址（如 Owner）。



### 1. 创建 Bank 合约

我们先创建一个简单的 Bank 合约，允许用户存款，并具有一个用于转移存款的功能。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    address public owner;
    uint256 public depositThreshold;

    event Deposit(address indexed depositor, uint256 amount);
    event TransferToOwner(uint256 amount);

    constructor(uint256 _depositThreshold) {
        owner = msg.sender;
        depositThreshold = _depositThreshold;
    }

    // 用户存款
    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);

        // 检查存款是否超过阈值，如果是，调用 _transferToOwner()
        if (address(this).balance >= depositThreshold) {
            _transferToOwner();
        }
    }

    // 内部函数，用于将一半的存款转移到 owner
    function _transferToOwner() internal {
        uint256 transferAmount = address(this).balance / 2;
        (bool success, ) = owner.call{value: transferAmount}("");
        require(success, "Transfer failed");

        emit TransferToOwner(transferAmount);
    }

    // 设置新的存款阈值
    function setDepositThreshold(uint256 _newThreshold) external {
        require(msg.sender == owner, "Only owner can set threshold");
        depositThreshold = _newThreshold;
    }
}
```

### 2. 部署合约

可以使用 Remix 或 Foundry 等工具将合约部署到sepolia测试网或主网。

![image-20240809154921851](/Users/yhb/Library/Application Support/typora-user-images/image-20240809154921851.png)

部署后合约地址：0x13d08bc532634b06f266c4822e734c60fc05f37b

### 3. 配置 OpenZeppelin Defender

OpenZeppelin Defender 是一个用于管理和保护智能合约的工具，其中包括自动化任务（Defender Autotasks）功能。

#### 步骤：

1. **创建 OpenZeppelin Defender 账号**: 访问 OpenZeppelin Defender 并注册一个账号。

2. **设置 Autotask**:

   - 登录到 Defender 后，点击 “Actions” 并创建一个新的 Create action。
   - 在 Autotask 中编写一个脚本，用于监听 Bank 合约中的存款事件，并在满足条件时调用 `_transferToOwner`。

3. #### 使用 Monitor 设置步骤：

   1. **创建一个新 Monitor**：
      - 在 OpenZeppelin Defender 中，导航到 Monitors。
      - 设置一个新的监视器来监听 Bank 合约的 `Deposit` 事件。
   2. **绑定 Monitor 到 Action**：
      - 在创建 Action 时，选择 Monitor 作为触发条件，并选择你刚刚设置的监视器。

### 4. 编写 脚本

根据出现的脚本重新编辑一个脚本

```
const ethers = require('ethers');

exports.handler = async function (payload) {
  const conditionRequest = payload.request.body;
  const matches = [];
  const events = conditionRequest.events;

  const bankAddress = '0x13d08bc532634b06f266c4822e734c60fc05f37b';
  const bankAbi = [
    'function depositThreshold() view returns (uint256)',
    'event Deposit(address indexed depositor, uint256 amount)',
  ];

  const provider = new ethers.providers.JsonRpcProvider('https://sepolia.infura.io/v3/33115389a88b4072bd35df8d6cf7890e');
  const bankContract = new ethers.Contract(bankAddress, bankAbi, provider);

  for (const evt of events) {
    if (evt.event === 'Deposit' && evt.address === bankAddress) {
      const balance = await provider.getBalance(bankAddress);
      const depositThreshold = await bankContract.depositThreshold();

      if (balance.gte(depositThreshold)) {
        matches.push({
          hash: evt.transactionHash,
          metadata: {
            depositor: evt.args.depositor,
            amount: evt.args.amount.toString(),
            balance: balance.toString(),
            timestamp: evt.args.timestamp,
          },
        });
      }
    }
  }

  return { matches };
};

```

以下是一个简单的 Autotask 脚本示例：

```
const { ethers } = require("ethers");
const { DefenderRelayProvider, DefenderRelaySigner } = require("defender-relay-client/lib/ethers");

async function handler(event) {
  const credentials = { apiKey: event.secrets.apiKey, apiSecret: event.secrets.apiSecret };
  const provider = new DefenderRelayProvider(credentials);
  const signer = new DefenderRelaySigner(credentials, provider, { speed: "fast" });

  const bankAddress = "0x13d08bc532634b06f266c4822e734c60fc05f37b";

  const bankAbi = [
    "function _transferToOwner() external",
    "event Deposit(address indexed depositor, uint256 amount)",
  ];

  const bankContract = new ethers.Contract(bankAddress, bankAbi, signer);

  bankContract.on("Deposit", async (depositor, amount) => {
    const balance = await provider.getBalance(bankAddress);
    const threshold = await bankContract.depositThreshold();

    if (balance.gte(threshold)) {
      const tx = await bankContract._transferToOwner();
      await tx.wait();
      console.log("Transferred half of the balance to owner.");
    }
  });
}

exports.handler = handler;
```

### 5. 部署并运行 Autotask

- 在 Defender 中配置好 Autotask 之后，设置它为自动运行。
- 确保将合约地址、API 密钥等配置正确。

通过上述步骤，你将拥有一个 Bank 合约，能够在存款超过指定阈值时自动将一半的存款转移到指定地址（Owner）。





