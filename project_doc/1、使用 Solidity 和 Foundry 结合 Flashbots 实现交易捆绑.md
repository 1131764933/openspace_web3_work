在 Sepolia 测试网上利用Foundry和Flashbots实现交易捆绑并获取交易状态信息

在以太坊上使用 Solidity 和 Foundry 结合 Flashbots 实现交易捆绑，可以通过以下步骤来完成。这里我们假设你已经在 Sepolia 测试网上部署了 OpenspaceNFT 合约，并且想要使用 Flashbots 捆绑开启预售和参与预售的交易。以下是实现这一目标的思路和具体操作步骤：

### 总体思路

1. **设置开发环境**：配置 Solidity 合约和 Foundry 测试环境。
2. **部署合约**：在 Sepolia 测试网上部署 OpenspaceNFT 合约。
3. **准备交易**：使用 Foundry 生成开启预售和参与预售的交易。
4. **捆绑交易**：利用 Flashbots 的 `eth_sendBundle` 方法捆绑交易。
5. **发送和查询交易状态**：使用 `flashbots_getBundleStats` 查询交易状态，并打印交易哈希和统计信息。

### 具体操作步骤

#### 1. 设置开发环境

- 确保已安装以下工具：
  - Node.js 和 npm
  - Foundry（包括 `forge` 和 `cast` 命令）
  - Flashbots Provider 库（用于与 Flashbots 通信）

```
forge init nft_Flashbots
cd nft_Flashbots
forge install OpenZeppelin/openzeppelin-contracts
npm install flashbots
```

#### 2. 编写和部署 OpenspaceNFT 合约

在src中编写 OpenspaceNFT.sol 合约，并使用 Foundry 部署到 Sepolia 网络。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
contract OpenspaceNFT {
    bool public presaleActive = false;
    address public owner;
    mapping(address => bool) public presaleWhitelist;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function startPresale() external onlyOwner {
        presaleActive = true;
    }

    function participateInPresale() external  view{
        require(presaleActive, "Presale is not active");
        require(presaleWhitelist[msg.sender], "Not whitelisted");
        // Logic for participating in presale
    }

    function addToWhitelist(address _address) external onlyOwner {
        presaleWhitelist[_address] = true;
    }
}
```

编译合约

```
forge build src/OpenspaceNFT.sol
```

输出结果为：

```
hb@yhbdeMacBook-Air nft_Flashbots % forge build src/OpenspaceNFT.sol
[⠊] Compiling...
[⠒] Compiling 1 files with Solc 0.8.25
[⠢] Solc 0.8.25 finished in 75.77ms
Compiler run successful!
```

创建.env文件，输入需要的关键信息

在 `script` 目录下创建一个新的部署脚本文件 `DeployOpenspaceNFT.s.sol`。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/OpenspaceNFT.sol";

contract DeployOpenspaceNFT is Script {
    function run() external {
        vm.startBroadcast();
        
        // 部署合约
        OpenspaceNFT nft = new OpenspaceNFT();
        
        // 打印合约地址
        console.log("OpenspaceNFT deployed to:", address(nft));
        
        vm.stopBroadcast();
    }
}
```

使用 Foundry 部署合约：

```
source .env

forge script script/DeployOpenspaceNFT.s.sol --rpc-url ${RPC_URL} --broadcast --private-key ${PRIVATE_KEY} 
```

输出结果为：

```
yhb@yhbdeMacBook-Air nft_Flashbots % forge script script/DeployOpenspaceNFT.s.sol --rpc-url ${RPC_URL} --broadcast --private-key ${PRIVATE_KEY}
[⠊] Compiling...
[⠊] Compiling 21 files with Solc 0.8.25
[⠒] Solc 0.8.25 finished in 977.15ms
Compiler run successful!
Script ran successfully.

== Logs ==
  OpenspaceNFT deployed to: 0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 24.587984728 gwei

Estimated total gas used for script: 302459

Estimated amount required: 0.007436857272846152 ETH

==========================

##### sepolia
✅  [Success]Hash: 0x3bb329e5e6bbb73016e2847a8e0333328a83c29528ec597479d06d4938d980d6
Contract Address: 0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339
Block: 6441651
Paid: 0.002954091020198638 ETH (232711 gas * 12.694247458 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.002954091020198638 ETH (232711 gas * avg 12.694247458 gwei)
                                                                                              

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/yhb/nft_Flashbots/broadcast/DeployOpenspaceNFT.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/yhb/nft_Flashbots/cache/DeployOpenspaceNFT.s.sol/11155111/run-latest.json

```



#### 3. 准备交易

新建scripts/flashbots.js使用 Foundry 和 Flashbots 结合脚本准备和发送交易。

要获得 `FLASHBOTS_RELAY_SIGNING_KEY`，你需要以太坊钱包地址和私钥，并将私钥用作 Flashbots 签名密钥。

下载内容

```
npm install dotenv
npm install @flashbots/ethers-provider-bundle --legacy-peer-deps
npm install @ethersproject/providers  --legacy-peer-deps
npm install ethers@6.7.1 --legacy-peer-deps
```

文件编辑：

```
require("dotenv").config();

const { ethers } = require("ethers");
const { FlashbotsBundleProvider } = require("@flashbots/ethers-provider-bundle");

const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const FLASHBOTS_RELAY_SIGNING_KEY = process.env.FLASHBOTS_RELAY_SIGNING_KEY;

async function createProvider() {
  const providers = [
    `https://sepolia.infura.io/v3/${INFURA_PROJECT_ID}`,
    "https://rpc.ankr.com/eth_sepolia",
    "https://rpc2.sepolia.org",
  ];

  for (const url of providers) {
    try {
      const provider = new ethers.JsonRpcProvider(url);
      await provider.getNetwork();
      console.log("Connected to provider:", url);
      return provider;
    } catch (error) {
      console.error("Failed to connect to provider:", url, error.message);
    }
  }
  throw new Error("Failed to connect to any provider");
}

async function main() {
  try {
    const provider = await createProvider();
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    const flashbotsProvider = await FlashbotsBundleProvider.create(
      provider,
      new ethers.Wallet(FLASHBOTS_RELAY_SIGNING_KEY),
      "https://relay-sepolia.flashbots.net"
    );

    const openspaceNFTAddress = "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339";
    const abi = [
      {
        type: "function",
        name: "startPresale",
        inputs: [],
        outputs: [],
        stateMutability: "nonpayable",
      },
      {
        type: "function",
        name: "participateInPresale",
        inputs: [],
        outputs: [],
        stateMutability: "nonpayable",
      },
    ];

    const openspaceNFT = new ethers.Contract(openspaceNFTAddress, abi, wallet);

    const blockNumber = await provider.getBlockNumber();
    console.log(`Current block number: ${blockNumber}`);

    const walletAddress = await wallet.getAddress();
    console.log(`Wallet address: ${walletAddress}`);

    const bundleTransactions = [
      {
        signer: wallet,
        transaction: {
          to: openspaceNFTAddress,
          data: openspaceNFT.interface.encodeFunctionData("startPresale"),
          chainId: 11155111,
          gasLimit: 100000,
          maxFeePerGas: ethers.parseUnits("10", "gwei"),
          maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
          type: 2, // EIP-1559 transaction
        },
      },
      {
        signer: wallet,
        transaction: {
          to: openspaceNFTAddress,
          data: openspaceNFT.interface.encodeFunctionData("participateInPresale"),
          chainId: 11155111,
          gasLimit: 100000,
          maxFeePerGas: ethers.parseUnits("10", "gwei"),
          maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
          type: 2, // EIP-1559 transaction
        },
      },
    ];

    // Helper function to convert BigNumbers to string
    const bigNumberToString = (key, value) =>
      typeof value === "bigint" ? value.toString() : value;

    console.log(
      "Bundle transactions:",
      JSON.stringify(bundleTransactions, bigNumberToString, 2)
    );

    const signedBundle = await flashbotsProvider.signBundle(bundleTransactions);

    const simulation = await flashbotsProvider.simulate(
      signedBundle,
      blockNumber + 1
    );
    if ("error" in simulation) {
      console.error("Simulation error:", simulation.error);
    } else {
      console.log(
        "Simulation results:",
        JSON.stringify(simulation, bigNumberToString, 2)
      );
    }

    const bundleResponse = await flashbotsProvider.sendBundle(
      bundleTransactions,
      blockNumber + 1
    );

    if ("error" in bundleResponse) {
      console.error("Error sending bundle:", bundleResponse.error);
      return;
    }

    console.log(
      "Bundle response:",
      JSON.stringify(bundleResponse, bigNumberToString, 2)
    );

    const bundleReceipt = await bundleResponse.wait();
    if (bundleReceipt === 1) {
      console.log("Bundle included in block");
    } else {
      console.log("Bundle not included");
    }

    const bundleStats = await flashbotsProvider.getBundleStats(
      bundleResponse.bundleHash,
      blockNumber + 1
    );
    console.log("Bundle stats:", JSON.stringify(bundleStats, bigNumberToString, 2));
  } catch (error) {
    console.error("Error during transaction processing:", error);
  }
}

main().catch((error) => {
  console.error("Main function error:", error);
  process.exit(1);
});

```

输出结果为：

```
hb@yhbdeMacBook-Air nft_Flashbots % node script/flashbots.js
Connected to provider: https://sepolia.infura.io/v3/33115389a88b4072bd35df8d6cf7890e
Current block number: 6446623
Wallet address: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69
Bundle transactions: [
  {
    "signer": {
      "provider": {},
      "address": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69"
    },
    "transaction": {
      "to": "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339",
      "data": "0x04c98b2b",
      "chainId": 11155111,
      "gasLimit": 100000,
      "maxFeePerGas": "10000000000",
      "maxPriorityFeePerGas": "2000000000",
      "type": 2
    }
  },
  {
    "signer": {
      "provider": {},
      "address": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69"
    },
    "transaction": {
      "to": "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339",
      "data": "0xcaa07a0c",
      "chainId": 11155111,
      "gasLimit": 100000,
      "maxFeePerGas": "10000000000",
      "maxPriorityFeePerGas": "2000000000",
      "type": 2
    }
  }
]
Simulation results: {
  "bundleGasPrice": "2000000000",
  "bundleHash": "0x0dc10c2a879b089d8c4e2a2e51b910be16306c7ad30a2461684e5334af806e27",
  "coinbaseDiff": "104080000000000",
  "ethSentToCoinbase": "0",
  "gasFees": "104080000000000",
  "results": [
    {
      "txHash": "0x5edea50aa224eda430deb3a539a6b7513660e536fbe80ab6e56a5309ee0ded79",
      "gasUsed": 26361,
      "gasPrice": "2000000000",
      "gasFees": "52722000000000",
      "fromAddress": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69",
      "toAddress": "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339",
      "coinbaseDiff": "52722000000000",
      "ethSentToCoinbase": "0",
      "value": "0x"
    },
    {
      "txHash": "0xb79220825623d664870e7a4537d5de8a3005371d1f8e7adacff6098f6eb31644",
      "gasUsed": 25679,
      "gasPrice": "2000000000",
      "gasFees": "51358000000000",
      "fromAddress": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69",
      "toAddress": "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339",
      "coinbaseDiff": "51358000000000",
      "ethSentToCoinbase": "0",
      "error": "execution reverted",
      "revert": "\b�y�\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000 \u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u000fNot whitelisted\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000",
      "value": null
    }
  ],
  "stateBlockNumber": 6446623,
  "totalGasUsed": 52040,
  "firstRevert": {
    "txHash": "0xb79220825623d664870e7a4537d5de8a3005371d1f8e7adacff6098f6eb31644",
    "gasUsed": 25679,
    "gasPrice": "2000000000",
    "gasFees": "51358000000000",
    "fromAddress": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69",
    "toAddress": "0xDcd5EE3A6E6237f617Fdd4FFe781530f11562339",
    "coinbaseDiff": "51358000000000",
    "ethSentToCoinbase": "0",
    "error": "execution reverted",
    "revert": "\b�y�\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000 \u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u000fNot whitelisted\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000",
    "value": null
  }
}
Bundle response: {
  "bundleTransactions": [
    {
      "signedTransaction": "0x02f87383aa36a75a84773594008502540be400830186a094dcd5ee3a6e6237f617fdd4ffe781530f11562339808404c98b2bc001a0cd864186ef37e32f0994d555a2efe9c274351f5250a7f085c6c6d3148cc287d6a04b3dd481cff60ceaa661b105eb280023ad87d38c9fd7a37b0fde866261fd0f5e",
      "hash": "0x5edea50aa224eda430deb3a539a6b7513660e536fbe80ab6e56a5309ee0ded79",
      "account": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69",
      "nonce": 90
    },
    {
      "signedTransaction": "0x02f87383aa36a75b84773594008502540be400830186a094dcd5ee3a6e6237f617fdd4ffe781530f115623398084caa07a0cc080a039c6b4331358a41006c98b2fa20fc6a12883ad4085ac03d3336ec818bccac347a031a229877e71778a48b3a3c4ce6801b8fd84d641239de4f21e2461a89bcfa2ef",
      "hash": "0xb79220825623d664870e7a4537d5de8a3005371d1f8e7adacff6098f6eb31644",
      "account": "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69",
      "nonce": 91
    }
  ],
  "bundleHash": "0x0dc10c2a879b089d8c4e2a2e51b910be16306c7ad30a2461684e5334af806e27"
}
Bundle included in block
Bundle stats: {
  "isHighPriority": true,
  "isSentToMiners": false,
  "isSimulated": true,
  "simulatedAt": "2024-08-06T07:23:35.909Z",
  "submittedAt": "2024-08-06T07:23:35.899Z"
}
```

#### 4. 运行脚本

确保所有变量都已正确配置（如 `PRIVATE_KEY` 和 `INFURA_PROJECT_ID`），然后运行脚本以发送和查询交易。

```
source .env
node script/flashbots.js
```

### 解释与注意事项

- **交易捆绑**：通过 Flashbots，将多个交易打包在一起，以确保它们按顺序执行。
- **安全性**：切勿在公共存储库或脚本中公开您的私钥。
- **费用与模拟**：在捆绑交易前模拟交易，以确认它们将成功执行。
- **Flashbots 费用**：通过 Flashbots 提交交易通常需要支付矿工费用以激励矿工将其包含在区块中。

通过以上步骤，您可以在 Sepolia 测试网上利用 Flashbots 技术实现交易捆绑，并获取相关交易状态信息。这是通过 Flashbots 提供的 API 和工具，将特定交易集按预期顺序执行的有效方式。
