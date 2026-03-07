我们来创建一个简单的 DApp，允许用户存储和检索一个消息。我们将使用 Foundry 作为智能合约框架，并用 viem.sh连接到以太坊网络。

### 第一步：安装和设置 Foundry

1. **安装 Foundry**：

   - 在终端中运行以下命令来安装 Foundry：

     ```
     curl -L https://foundry.paradigm.xyz | bash
     foundryup
     ```

2. **创建新的 Foundry 项目**：

   - 运行以下命令来创建一个新的项目：

     ```
     forge init mydapp
     cd mydapp
     ```

![image-20240713165621948](/Users/yhb/Library/Application Support/typora-user-images/image-20240713165621948.png)

### 第二步：编写和部署智能合约

1. **编写智能合约**：

   - 在 `src` 文件夹中创建一个名为 `Message.sol` 的文件，并添加以下代码：

     ```
     // SPDX-License-Identifier: UNLICENSED
     pragma solidity ^0.8.20;
     
     contract Message {
         string private message;
     
         constructor() {
             message = "0";
         }
     
         function setMessage(string calldata newMessage) external {
             message = newMessage;
         }
     
         function getMessage() external view returns (string memory) {
             return message;
         }
     }
     ```

   在`foundry.toml` 文件中增加内容

   ```
   [profile.default]
   src = "src"
   out = "out"
   libs = ["lib"]
   solc = "0.8.20"
   
   # See more config options https://github.com/foundry-rs/foundry/blob/master/crates/config/README.md#all-options
   
   ```

   使用`forge build`编译合约：

   ```
   export FOUNDRY_SOLC_VERSION=0.8.20 
   forge build
   ```

   结果如下：

   ![image-20240706144611237](/Users/yhb/Library/Application Support/typora-user-images/image-20240706144611237.png)

2. **编写测试**：

   - 在 test 文件夹中创建一个名为 Message.t.sol的文件，并添加以下代码：

     ```
     // SPDX-License-Identifier: UNLICENSED
     pragma solidity ^0.8.20;
     
     import "../lib/forge-std/src/Test.sol";
     import "../src/Message.sol";
     
     contract MessageTest is Test {
         Message messageContract;
     
         function setUp() public {
             messageContract = new Message();
         }
     
         function testSetMessage() public {
             messageContract.setMessage("hello,world!");
             assertEq(messageContract.getMessage(), "hello,world!");
         }
     }
     
     ```

3. **运行测试**：

   - 在终端中运行以下命令来测试合约：

     ```
     forge test
     ```

   结果如下：

   ```
   [⠊] Compiling...
   [⠢] Compiling 1 files with Solc 0.8.20
   [⠆] Solc 0.8.20 finished in 1.12s
   Compiler run successful!
   
   Ran 1 test for test/Message.t.sol:MessageTest
   [PASS] testSetMessage() (gas: 16639)
   Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.57ms (1.83ms CPU time)
   
   Ran 2 tests for test/Counter.t.sol:CounterTest
   [PASS] testFuzz_SetNumber(uint256) (runs: 256, μ: 31054, ~: 31288)
   [PASS] test_Increment() (gas: 31303)
   Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 12.35ms (7.52ms CPU time)
   
   Ran 2 test suites in 168.95ms (19.92ms CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)
   ```

   

4. **部署智能合约**：

   部署合约到区块链，需要先准备有币的账号及区块链节点的 RPC URL。

   #### 安装`dotenv`并创建`env`文件

   安装支持读取env文件的依赖，并在项目跟目录创建env文件

   ```
   npm i dotenv -D
   ```

   为此我们需要稍微配置 Foundry ，通常我们会创建一个 `.env` 保存私密信息，`.env` 中记录自己的助记词及RPC URL。

   ```
   vim .env 
   ```

   文件格式如下：

   ```
   GOERLI_RPC_URL=
   MNEMONIC=
   PRIVATE_KEY=
   ETHERSCAN_API_KEY=
   ETH_SEPOILA_URL=
   ```

   运行命令加载环境变量：

   ```
   source .env
   ```

   还需要准备一个以太坊浏览器的 **API Key Token**

   ![image-20240706151029415](/Users/yhb/Library/Application Support/typora-user-images/image-20240706151029415.png)

   创建成功后就可以看到一个mydapp的**API Key Token**了

   这将为 sepolia 测试网创建一个 [RPC 别名](https://learnblockchain.cn/docs/foundry/i18n/zh/cheatcodes/rpc.html) 并加载 Etherscan 的 API 密钥。

   接下来，我们必须创建一个文件夹并将其命名为 `script`，并在其中创建一个名为 `Message.s.sol` 的文件。 这是我们将创建部署脚本本身的地方。`Message.s.sol` 的内容应该是这样的：

   ```
   // SPDX-License-Identifier: UNLICENSED
   pragma solidity ^0.8.20;
   
   import "forge-std/Script.sol";
   import "../src/Message.sol";
   
   contract DeployMessage is Script {
       function run() external {
           vm.startBroadcast();
           
           // 部署 Message 合约
           Message message = new Message();
   
           // 输出合约地址
           console.log("Message contract deployed at:", address(message));
   
           vm.stopBroadcast();
       }
   }
   
   ```
   
   
   
   - 使用 Foundry 生成部署脚本（这里假设你已经设置好 Foundry 的配置），这里使用sepolia作为测试部署。使用[forge create](https://book.getfoundry.sh/reference/forge/forge-create.html)命令。这里的`--rpc-url`填入sepolia的rpc，可以使用公共的[rpc节点](https://chainlist.org/chain/11155111)，`--private-key`就是你的钱包私钥，`--etherscan-api-key`用于验证合约用，这个api-key可以去https://etherscan.io/login注册账号获，`ETH_SEPOILA_URL`为刚才我们复制的节点URL
   
     使用环境变量配置，并运行以下命令
   
     ```
     forge script script/Message.s.sol:DeployMessage --rpc-url ${ETH_SEPOILA_URL} --private-key ${PRIVATE_KEY} --broadcast --verify -vvvv
     ```

可以看到成功部署且合约得到验证，输出结果为：

```
yhb@yhbdeMacBook-Air mydapp % forge script script/Message.s.sol:DeployMessage --rpc-url ${ETH_SEPOILA_URL} --private-key ${PRIVATE_KEY} --broadcast --verify -vvvv
[⠊] Compiling...
[⠊] Compiling 1 files with Solc 0.8.20
[⠒] Solc 0.8.20 finished in 922.31ms
Compiler run successful!
Traces:
  [235866] DeployMessage::run()
    ├─ [0] VM::startBroadcast()
    │   └─ ← [Return] 
    ├─ [196995] → new Message@0x370FB46A48d45Ed8E18c66F8590549522c2aAecC
    │   └─ ← [Return] 871 bytes of code
    ├─ [0] console::log("Message contract deployed at:", Message: [0x370FB46A48d45Ed8E18c66F8590549522c2aAecC]) [staticcall]
    │   └─ ← [Stop] 
    ├─ [0] VM::stopBroadcast()
    │   └─ ← [Return] 
    └─ ← [Stop] 


Script ran successfully.

== Logs ==
  Message contract deployed at: 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC

## Setting up 1 EVM.
==========================
Simulated On-chain Traces:

  [196995] → new Message@0x370FB46A48d45Ed8E18c66F8590549522c2aAecC
    └─ ← [Return] 871 bytes of code


==========================

Chain 11155111

Estimated gas price: 20.432400129 gwei

Estimated total gas used for script: 350795

Estimated amount required: 0.007167583803252555 ETH

==========================

##### sepolia
✅  [Success]Hash: 0x0f1fc910ddfd43b85fc39cb8851ddadfb7cad1b78c275564888438284ab19cd3
Contract Address: 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC
Block: 6301905
Paid: 0.002691406715585475 ETH (269925 gas * 9.970942727 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.002691406715585475 ETH (269925 gas * avg 9.970942727 gwei)
                                                                                             

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (1) contracts
Start verifying contract `0x370FB46A48d45Ed8E18c66F8590549522c2aAecC` deployed on sepolia

Submitting verification for [src/Message.sol:Message] 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC.

Submitting verification for [src/Message.sol:Message] 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC.

Submitting verification for [src/Message.sol:Message] 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC.

Submitting verification for [src/Message.sol:Message] 0x370FB46A48d45Ed8E18c66F8590549522c2aAecC.
Submitted contract for verification:
        Response: `OK`
        GUID: `7bezc236tlhmpycjwsiqbcrc3xjje45pduzxmuwpvmkansdgbt`
        URL: https://sepolia.etherscan.io/address/0x370fb46a48d45ed8e18c66f8590549522c2aaecc
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified
All (1) contracts were verified!

Transactions saved to: /Users/yhb/mydapp/broadcast/Message.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/yhb/mydapp/cache/Message.s.sol/11155111/run-latest.json

yhb@yhbdeMacBook-Air mydapp % 
```

打开https://sepolia.etherscan.io/网站可以查寻看到部署成功的合约如下：

![image-20240713172004921](/Users/yhb/Library/Application Support/typora-user-images/image-20240713172004921.png)




### 第三步：设置 React 项目

1. **创建新的 React 项目**：

   - 在终端中运行以下命令：

     ```
     npx create-react-app myweb3dapp
     ```

2. **安装 viem.js**：

   - 在 React 项目中安装 viem.js，使用 Viem 与合约交互：

     ```
     cd myweb3dapp
     mkdir viem-scripts && cd viem-scripts
     pnpm init
     pnpm install dotenv viem
     pnpm install -D typescript ts-node @types/node
     ```

   - 在项目中初始化 TypeScript 的配置文件：

     ```
     npx tsc --init
     ```

   - 新建一个 `index.ts` 文件，并添加以下内容：

     ```
     import { createPublicClient, http } from "viem";
     import { sepolia } from "viem/chains";
     
     const client = createPublicClient({
       chain: sepolia,
       transport: http(),
     });
     
     async function main() {
       const blockNumber = await client.getBlockNumber();
       console.log(blockNumber);
     }
     
     main();
     ```

   - 在 `package.json` 中添加 `start` 脚本：

     ```
     "scripts": {
       "start": "ts-node index.ts",
     },
     ```

   - 运行以下命令启动：

     ```
     pnpm start
     ```

   输出结果为：

   ```
   
   > viem-scripts@1.0.0 start /Users/yhb/mydapp/myweb3dapp/viem-scripts
   > ts-node index.ts
   
   6303065n
   ```

   

3. **与合约交互**：

   - 在 `viem-scripts` 项目文件夹中，新建一个 `abi.ts` 文件，内容如下：

     ```
     export const abi = [{"type":"constructor","inputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"getMessage","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},{"type":"function","name":"setMessage","inputs":[{"name":"newMessage","type":"string","internalType":"string"}],"outputs":[],"stateMutability":"nonpayable"}];
     
     export const address = "0x370FB46A48d45Ed8E18c66F8590549522c2aAecC";
     ```

   - 修改 `index.ts` 文件，内容如下：

     ```
     import { createPublicClient, createWalletClient, http } from "viem";
     import { sepolia } from "viem/chains";
     import { privateKeyToAccount } from "viem/accounts";
     import { abi, address } from "./abi";
     import dotenv from "dotenv";
         
     dotenv.config();
     const privateKey = process.env.PRIVATE_KEY;
     if (!privateKey) {
       throw new Error("Missing PRIVATE_KEY in .env file");
     }
     const account = privateKeyToAccount(`0x${privateKey}`);
     const rpc = process.env.ETH_RPC_URL;
     console.log("Using RPC URL:", rpc);
     console.log("Using private key:", privateKey);
     const walletClient = createWalletClient({
       account,
       chain: sepolia,
       transport: http(rpc),
     });
     
     const client = createPublicClient({
       chain: sepolia,
       transport: http(rpc),
     });
     
     async function main() {
       const message = await client.readContract({
         address,
         abi,
         functionName: "getMessage",
       });
     
       console.log("Current message:", message);
     
       const hash = await walletClient.writeContract({
         address,
         abi,
         functionName: "setMessage",
         args: ["hello, world!"],
       });
     
       console.log("The hash is:", hash);
       const receipt = await client.waitForTransactionReceipt({ hash });
       console.log("Receipt info:", receipt);
     
       const updatedMessage = await client.readContract({
         address,
         abi,
         functionName: "getMessage",
       });
     
       console.log(updatedMessage);
     }
     
     main();
     ```

运行命令`pnpm start`，结果如下：

```

> viem-scripts@1.0.0 start /Users/yhb/mydapp/web/viem-scripts
> ts-node index.ts

Using RPC URL: https://sepolia.infura.io/v3/33115389a88b4072bd35df8d6cf7890e
Using private key: f8790d72c5ffb941d02b8ed2ef8bdf39600c49b41272f4ddd4cd5eb6ee40e57e
Current message: hello, world!
The hash is: 0x5974f104701ebd6c1e6d8537c3ece010ff1c61178c99c14592ff2be82e4db120
Receipt info: {
  blockHash: '0xfc8f106d9bff7433645467c15f74408c1ecf2f92fc3adc5868435937d8b4f22c',
  blockNumber: 6308920n,
  contractAddress: null,
  cumulativeGasUsed: 29564499n,
  effectiveGasPrice: 1983338413n,
  from: '0x531247bba4d32ed9d870bc3abe71a2b9ce911e69',
  gasUsed: 24591n,
  logs: [],
  logsBloom: '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  status: 'success',
  to: '0x370fb46a48d45ed8e18c66f8590549522c2aaecc',
  transactionHash: '0x5974f104701ebd6c1e6d8537c3ece010ff1c61178c99c14592ff2be82e4db120',
  transactionIndex: 127,
  type: 'eip1559'
}
hello, world!
```

### 第四步：编写 React 代码

1. **安装依赖**：

   ```
   npm install ethers@latest viem@latest --legacy-peer-deps
   ```

   如果上述方法不起作用，可以尝试使用 Yarn 包管理器来安装依赖。首先，全局安装 Yarn：

   ```
   npm install -g yarn
   ```

   然后使用 Yarn 安装依赖：

   ```
   yarn add ethers@latest viem@latest
   ```

   确保你使用的是兼容的 ethers 版本。例如，安装 ethers 库的最新版本

   ```
   npm install ethers@^5.0.0 --legacy-peer-deps
   ```

   安装 path-browserify、os-browserify 和 crypto-browserify：

   ```
   pnpm install path-browserify os-browserify crypto-browserify
   ```

   创建 webpack.config.js 文件以包含以下配置：

   ```
   const path = require('path');
   
   module.exports = {
     resolve: {
       fallback: {
         "path": require.resolve("path-browserify"),
         "os": require.resolve("os-browserify/browser"),
         "crypto": require.resolve("crypto-browserify")
       }
     }
   };
   ```

   

2. **设置 viem.js**：

   - 在 `src` 文件夹中创建一个名为 `viem.js` 的文件，`YOUR_INFURA_PROJECT_ID`改为`infura`上面注册的`ID`，并添加以下代码：


   ```
   import { createPublicClient, createWalletClient, http } from 'viem';
   import { sepolia } from 'viem/chains';
   import { privateKeyToAccount } from 'viem/accounts';
   import { ethers } from 'ethers';
   
   
   const rpcUrl = `https://sepolia.infura.io/v3/33115389a88b4072bd35df8d6cf7890e`;
   const privateKey = "0xf8790d72c5ffb941d02b8ed2ef8bdf39600c49b41272f4ddd4cd5eb6ee40e57e";
   const account = privateKeyToAccount(privateKey);
   const publicClient = createPublicClient({
     chain: sepolia,
     transport: http(rpcUrl),
   });
   
   const walletClient = createWalletClient({
     account,
     chain: sepolia,
     transport: http(rpcUrl),
   });
   
   const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
   const wallet = new ethers.Wallet(privateKey, provider);
   export { publicClient, walletClient, wallet };
   ```

   

3. **创建组件**：

   - 在 `src` 文件夹中创建一个名为 `MessageComponent.js` 的文件，并添加以下代码：

     ```
     import React, { useState } from 'react';
     import { Contract } from 'ethers';
     import { publicClient, wallet } from './viem';
     
     const contractAddress = '0x370FB46A48d45Ed8E18c66F8590549522c2aAecC';
     const abi = [{"type":"constructor","inputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"getMessage","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},{"type":"function","name":"setMessage","inputs":[{"name":"newMessage","type":"string","internalType":"string"}],"outputs":[],"stateMutability":"nonpayable"}];
     
     function MessageComponent() {
       const [message, setMessage] = useState('');
       const [newMessage, setNewMessage] = useState('');
     
       const fetchMessage = async () => {
         const result = await publicClient.readContract({
           address: contractAddress,
           abi,
           functionName: 'getMessage',
         });
         setMessage(result);
       };
     
       const updateMessage = async () => {
         const contract = new Contract(contractAddress, abi, wallet);
         const tx = await contract.setMessage(newMessage);
         await tx.wait(); // 等待交易完成
         fetchMessage();
       };
     
       return (
         <div>
           <h1>Message DApp</h1>
           <div>
             <button onClick={fetchMessage}>Get Message</button>
             <p>{message}</p>
           </div>
           <div>
             <input
               type="text"
               value={newMessage}
               onChange={(e) => setNewMessage(e.target.value)}
             />
             <button onClick={updateMessage}>Set Message</button>
           </div>
         </div>
       );
     }
     
     export default MessageComponent;
     ```

   

4. **在 App 组件中使用 MessageComponent**：

   - 修改 `src/App.js`，内容如下：

     ```
     import React from 'react';
     import MessageComponent from './MessageComponent';
     
     function App() {
       return (
         <div className="App">
           <MessageComponent />
         </div>
       );
     }
     
     export default App;
     ```

### 启动应用程序

运行以下命令来启动应用程序：

```
npm start
```

这将启动你的 React 应用程序，并且你现在可以在浏览器中看到并与智能合约进行交互的前端界面。

**解决 ESLint 插件冲突**

如果遇到 ESLint 插件冲突错误，请尝试以下步骤：

	rm -rf node_modules package-lock.json
	npm install
	npm install eslint@^7.11.0 eslint-config-react-app@latest --legacy-peer-deps

重新启动你的应用程序：`npm start`，应该能够解决依赖冲突问题，并让 MessageComponent 正常工作。

![image-20240714215928854](/Users/yhb/Library/Application Support/typora-user-images/image-20240714215928854.png)

输入其他的信息可以看到信息的更新：歪脖山徒步🦐，哈哈哈！

![image-20240714220330378](/Users/yhb/Library/Application Support/typora-user-images/image-20240714220330378.png)
