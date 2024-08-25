

签名 NFT 上架信息

使用离线签名和验证存储NFT上架，展示最新的 NFT上架清单 

完善 NFTMarket合约，使用ETH买入NFT 

在TheGraph中记录NFT记录，并在网页中展示NFT交易动态

#### 1. 使用 Foundry 部署合约

请参考官网的官方文档：[https://getfoundry.sh](https://getfoundry.sh/)

创建一个新的 Foundry 项目：

```
forge init NFTMarketProject
cd NFTMarketProject
```

**目标**：使用 Foundry 部署更新后的合约。

1.1 修改合约文件 `src/NFTMarket.sol`，添加以下函数：

```
function buyWithETH(bytes32 orderId) public payable {
    SellOrder memory order = listingOrders[orderId];
    require(order.seller != address(0), "MKT: order not listed");
    require(order.deadline > block.timestamp, "MKT: order expired");
    require(order.payToken == ETH_FLAG, "MKT: only ETH payments allowed");

    delete listingOrders[orderId];
    IERC721(order.nft).safeTransferFrom(order.seller, msg.sender, order.tokenId);

    uint256 fee = order.price * feeBP / 10000;
    require(msg.value == order.price, "MKT: wrong eth value");

    payable(order.seller).transfer(order.price - fee);
    if (fee > 0) {
        payable(feeTo).transfer(fee);
    }
    emit Sold(orderId, msg.sender, fee);
}
```

在智能合约中增加验证签名的函数：

```
function verifySignature(SellOrder memory order, bytes memory signature) public view returns (bool) {
    bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
        keccak256("SellOrder(address seller,address nft,uint256 tokenId,address payToken,uint256 price,uint256 deadline)"),
        order.seller,
        order.nft,
        order.tokenId,
        order.payToken,
        order.price,
        order.deadline
    )));
    return ECDSA.recover(digest, signature) == order.seller;
}
```

#### 

1.2 编译合约：

```
forge build
```

1.3 部署合约： 创建一个新的脚本文件 `script/Deploy.s.sol`：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        vm.startBroadcast();

        NFTMarket market = new NFTMarket();
        market.setFeeTo(msg.sender);
        market.setWhiteListSigner(msg.sender);

        vm.stopBroadcast();
    }
}
```

新建一个.env文件

```
export PRIVATE_KEY=your_PRIVATE_KEY
export RPC_URL=your_RPC_URL
```

运行部署脚本：

`forge` 中的 `--gas-price` 参数期望的是一个整数值，而不是带有单位的字符串。因此，你需要以 wei 为单位来指定 gas 价格。你可以计算你想要的 gwei 值，然后将其转换为 wei。例如，100 gwei = 100 * 10^9 wei = 100000000000 wei。

```
forge script script/DeployNFTMarket.s.sol --rpc-url ${RPC_URL}  --broadcast --verify -vvvv --private-key ${PRIVATE_KEY} --gas-price 100000000000
```

输出结果为：

```
hb@yhbdeMacBook-Air MyNFTMarketProject % forge script script/DeployNFTMarket.s.sol --rpc-url ${RPC_URL}  --broadcast --verify -vvvv --private-key ${PRIVATE_KEY} --gas-price 100000000000
[⠊] Compiling...
No files changed, compilation skipped
Traces:
  [1732638] DeployNFTMarket::run()
    ├─ [0] VM::startBroadcast()
    │   └─ ← [Return] 
    ├─ [1643085] → new NFTMarket@0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   └─ ← [Return] 8082 bytes of code
    ├─ [23929] NFTMarket::setFeeTo(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   ├─ emit SetFeeTo(to: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   └─ ← [Stop] 
    ├─ [23932] NFTMarket::setWhiteListSigner(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   ├─ emit SetWhiteListSigner(signer: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   └─ ← [Stop] 
    ├─ [0] console::log("NFTMarket deployed to:", NFTMarket: [0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3]) [staticcall]
    │   └─ ← [Stop] 
    ├─ [0] VM::stopBroadcast()
    │   └─ ← [Return] 
    └─ ← [Stop] 


Script ran successfully.

== Logs ==
  NFTMarket deployed to: 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3

## Setting up 1 EVM.
==========================
Simulated On-chain Traces:

  [1643085] → new NFTMarket@0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3
    ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    └─ ← [Return] 8082 bytes of code

  [25929] NFTMarket::setFeeTo(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    ├─ emit SetFeeTo(to: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    └─ ← [Stop] 

  [25932] NFTMarket::setWhiteListSigner(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    ├─ emit SetWhiteListSigner(signer: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    └─ ← [Stop] 


==========================

Chain 11155111

Estimated gas price: 40.218606906 gwei

Estimated total gas used for script: 2525239

Estimated amount required: 0.101561594684700534 ETH

==========================

##### sepolia
✅  [Success]Hash: 0xe90b59d66f3157d6660fb82218078cdc4c3f0815577410ce68391de7dc25e65f
Contract Address: 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3
Block: 6356400
Paid: 0.039896897473517196 ETH (1838887 gas * 21.696220308 gwei)


##### sepolia
✅  [Success]Hash: 0xb6a47b6b470e7972fb0e60b6afcbf2f16bfd27d668583b3b0492d3a4b0ccd46e
Block: 6356400
Paid: 0.001027619778668112 ETH (47364 gas * 21.696220308 gwei)


##### sepolia
✅  [Success]Hash: 0x84d0deda8e96cc184d7c214f7e8f831459532c6f7e4b2e1397a8f15ff5d0f898
Block: 6356400
Paid: 0.001027554690007188 ETH (47361 gas * 21.696220308 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.041952071942192496 ETH (1933612 gas * avg 21.696220308 gwei)
                                                                           

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (1) contracts
Start verifying contract `0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3` deployed on sepolia

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3.
Submitted contract for verification:
        Response: `OK`
        GUID: `ftyyrhw69gjdcgffweguqvsmevbmzavnhwgs32cqwgbctyaqjy`
        URL: https://sepolia.etherscan.io/address/0x1e97e3530ad9e8bb99b4b8c9028164a71b1e44e3
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified
All (1) contracts were verified!

Transactions saved to: /Users/yhb/MyNFTMarketProject/broadcast/DeployNFTMarket.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/yhb/MyNFTMarketProject/cache/DeployNFTMarket.s.sol/11155111/run-latest.json

```



#### 2. 使用离线签名和验证机制存储 NFT 上架信息

**目标**：使用离线签名和验证机制来存储 NFT 上架信息。

2.1 安装 `ethers` 和 `viem` 库：

```
pnpm install ethers viem
```

你可以尝试使用其他的 NPM 镜像源来进行安装。这里是如何更换为 Taobao 镜像源的示例：

```
pnpm config set registry https://registry.npmmirror.com
```

然后再尝试安装：

```
pnpm install ethers viem
```

或者通过以下命令清除 DNS 缓存（在 macOS 上）：

```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

2.2 在你的项目根目录中创建 `scripts` 文件夹并在其中创建一个新文件 `sign.js`

```
mkdir scripts
vim scripts/sign.js
```

将你提供的离线签名代码添加到 `scripts/sign.mjs` 文件：

```
import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const provider = new ethers.JsonRpcProvider("https://eth-sepolia.g.alchemy.com/v2/qsGrQqFAXo8e1H5ohOANklPooZ1oXdLy");
const wallet = new ethers.Wallet("f8790d72c5ffb941d02b8ed2ef8bdf39600c49b41272f4ddd4cd5eb6ee40e57e", provider);

const domain = {
  name: "NFTMarket",
  version: "1",
  chainId: 11155111, 
  verifyingContract: "0x1e97e3530aD9e8Bb99b4B8c9028164A71B1E44E3" // 实际的合约地址
};

const types = {
  SellOrder: [
    { name: "seller", type: "address" },
    { name: "nft", type: "address" },
    { name: "tokenId", type: "uint256" },
    { name: "payToken", type: "address" },
    { name: "price", type: "uint256" },
    { name: "deadline", type: "uint256" }
  ]
};

const order = {
  seller: "0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69", // 替换为实际的卖家地址
  nft: "0xA98287D39fD81d9F9c384981d8fbb7563C7b7780", // 替换为实际的 NFT 合约地址
  tokenId: 0, // 替换为实际的 tokenId
  payToken: "0x0000000000000000000000000000000000000000", // 替换为实际的支付代币地址
  price: ethers.parseUnits("1", "ether"), // 确保 ethers 正确使用
  deadline: Math.floor(Date.now() / 1000) + 60 * 60 // 1小时后
};

async function signOrder() {
  try {
    // 使用 wallet.signTypedData 方法签名数据
    const signature = await wallet.signTypedData(domain, types, order);
    console.log("Signature: ", signature);
  } catch (error) {
    console.error("Error signing order:", error);
  }
}

signOrder();

```

运行命令签名：

```
node sign.mjs
```

输出结果为：

```

Signature:  0x12f3828b91f03327eee711bc4bd9583750013b21736a137db98a80ce624975e90ee6427d6e35a0e7b2afb794c6f158cccb09fa93766805c1232f97237e5732de1b
```



#### 3. 使用 viem 在前端展示 NFT 上架清单和成交记录

**目标**：在前端项目中使用 viem 完成与合约的交互，并展示 NFT 上架清单和成交记录。

创建一个前端项目

```
npx create-react-app my-nft-app
cd my-nft-app
```

3.1 在前端项目中，创建一个文件 `App.js`：

```
import React, { useEffect, useState } from 'react';
import { createPublicClient, createWalletClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { ethers } from 'ethers';
import { useSignTypedData } from 'viem/hooks';

const client = createPublicClient({ chain: mainnet, transport: http() });

const domain = {
  name: "OpenSpaceNFTMarket",
  version: "1",
  chainId: 1, // 替换为实际的链 ID
  verifyingContract: "合约地址"
};

const types = {
  SellOrder: [
    { name: "seller", type: "address" },
    { name: "nft", type: "address" },
    { name: "tokenId", type: "uint256" },
    { name: "payToken", type: "address" },
    { name: "price", type: "uint256" },
    { name: "deadline", type: "uint256" }
  ]
};

const order = {
  seller: "卖家地址",
  nft: "NFT合约地址",
  tokenId: 1, // 替换为实际的 tokenId
  payToken: "支付代币地址",
  price: ethers.utils.parseUnits("1", "ether"),
  deadline: Math.floor(Date.now() / 1000) + 60 * 60 // 1小时后
};

const App = () => {
  const [signature, setSignature] = useState('');
  const [listings, setListings] = useState([]);
  const [sales, setSales] = useState([]);
  
  const { signTypedDataAsync } = useSignTypedData();

  useEffect(() => {
    async function fetchData() {
      // Fetch listings and sales data from TheGraph
      // 此处需要替换为实际的 GraphQL 查询和地址
      const listingsResponse = await fetch('https://api.thegraph.com/subgraphs/name/你的子图', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          query: `
            {
              lists(first: 5) {
                id
                nft
                tokenId
                seller
                payToken
                price
                deadline
              }
              solds(first: 5) {
                id
                buyer
                fee
              }
            }
          `
        })
      });
      const listingsData = await listingsResponse.json();
      setListings(listingsData.data.lists);
      setSales(listingsData.data.solds);
    }

    fetchData();
  }, []);

  const signOrder = async () => {
    const signature = await signTypedDataAsync({ domain, types, value: order });
    setSignature(signature);
  };

  return (
    <div>
      <button onClick={signOrder}>Sign Order</button>
      <p>Signature: {signature}</p>
      <h1>NFT 上架清单</h1>
      {listings.map((list) => (
        <div key={list.id}>
          <p>Token ID: {list.tokenId}</p>
          <p>价格: {ethers.utils.formatUnits(list.price, 'ether')} ETH</p>
          <p>卖家: {list.seller}</p>
        </div>
      ))}
      <h1>NFT 成交记录</h1>
      {sales.map((sold) => (
        <div key={sold.id}>
          <p>购买者: {sold.buyer}</p>
          <p>手续费: {ethers.utils.formatUnits(sold.fee, 'ether')} ETH</p>
        </div>
      ))}
    </div>
  );
};

export default App;
```

通过以上步骤，你可以使用 Foundry 部署合约，使用离线签名和验证机制存储 NFT 上架信息，使用 viem 在前端项目中展示 NFT 上架清单和成交记录。



https://subgraph.satsuma-prod.com/hongbins-team--360746/nftmarket/playground