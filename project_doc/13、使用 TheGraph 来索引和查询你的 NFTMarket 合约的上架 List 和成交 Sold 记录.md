

# 使用 TheGraph 来索引和查询你的 NFTMarket 合约的上架 List 和成交 Sold 记录

用foundry部署开源 NFTMarket 合约， 使用 TheGraph 索引 NFTMarket 的上架List和成交Sold记录

### 1. 安装 Foundry

首先，确保你已经安装了 Foundry，工具的安装使用，请参考官网的官方文档：[https://getfoundry.sh](https://getfoundry.sh/)

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 创建项目

创建一个新的 Foundry 项目：

```
forge init NFTMarketProject
cd NFTMarketProject
```

### 3. 添加依赖

如果需要使用 OpenZeppelin 库，可以添加依赖：

```
forge install OpenZeppelin/openzeppelin-contracts
```

在项目的 `foundry.toml` 文件中，添加如下内容：

```
[profile.default]
src = 'src'
out = 'out'
libs = ['lib']
solc_version = "0.8.25"
evm_version = "cancun"

# [etherscan]
# api_key = "VI5RRN7QQ2T5TFA28HD7WAUE37TI2WDBSC"

remappings = [
    '@openzeppelin/=lib/openzeppelin-contracts/',
    'forge-std/=lib/forge-std/src/',
    '@openzeppelin/contracts/=/Users/yhb/MyNFTMarketProject/lib/openzeppelin-contracts/contracts/',
    'ds-test/=/Users/yhb/MyNFTMarketProject/lib/openzeppelin-contracts/lib/forge-std/lib/ds-test/src/',
    'erc4626-tests/=/Users/yhb/MyNFTMarketProject/lib/openzeppelin-contracts/lib/erc4626-tests/',
    'halmos-cheatcodes/=/Users/yhb/MyNFTMarketProject/lib/openzeppelin-contracts/lib/halmos-cheatcodes/src/',
    'openzeppelin-contracts/=/Users/yhb/MyNFTMarketProject/lib/openzeppelin-contracts/',
]

```



### 4. 编写合约

在 `src` 目录下创建合约文件 `NFTMarket.sol` 并编写合约代码：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract NFTMarket is Ownable(msg.sender), EIP712("OpenSpaceNFTMarket", "1") {
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 public constant feeBP = 30; // 30/10000 = 0.3%
    address public whiteListSigner;
    address public feeTo; 
    mapping(bytes32 => SellOrder) public listingOrders; 
    mapping(address => mapping(uint256 => bytes32)) private _lastIds; 
    struct SellOrder {
        address seller;  
        address nft;     
        uint256 tokenId; 
        address payToken;
        uint256 price;   
        uint256 deadline; 
    }
    function listing(address nft, uint256 tokenId) external view returns (bytes32) {
        bytes32 id = _lastIds[nft][tokenId];
        return listingOrders[id].seller == address(0) ? bytes32(0x00) : id;
    }
    function list(address nft, uint256 tokenId, address payToken, uint256 price, uint256 deadline) external {
        require(deadline > block.timestamp, "MKT: deadline is in the past");
        require(price > 0, "MKT: price is zero");
        require(payToken == address(0) || IERC20(payToken).totalSupply() > 0, "MKT: payToken is not valid");

        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "MKT: not owner");
        require(
            IERC721(nft).getApproved(tokenId) == address(this)
                || IERC721(nft).isApprovedForAll(msg.sender, address(this)),
            "MKT: not approved"
        );
        SellOrder memory order = SellOrder({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            payToken: payToken,
            price: price,
            deadline: deadline
        });
        bytes32 orderId = keccak256(abi.encode(order));
        require(listingOrders[orderId].seller == address(0), "MKT: order already listed");
        listingOrders[orderId] = order;
        _lastIds[nft][tokenId] = orderId; 
        emit List(nft, tokenId, orderId, msg.sender, payToken, price, deadline);
    }
    function cancel(bytes32 orderId) external {
        address seller = listingOrders[orderId].seller;
        require(seller != address(0), "MKT: order not listed");
        require(seller == msg.sender, "MKT: only seller can cancel");
        delete listingOrders[orderId];
        emit Cancel(orderId);
    }
    function buy(bytes32 orderId) public payable {
        _buy(orderId, feeTo);
    }
    function buy(bytes32 orderId, bytes calldata signatureForWL) external payable {
        _checkWL(signatureForWL);
        _buy(orderId, address(0));
    }
    function _buy(bytes32 orderId, address feeReceiver) private {
        SellOrder memory order = listingOrders[orderId];
        require(order.seller != address(0), "MKT: order not listed");
        require(order.deadline > block.timestamp, "MKT: order expired");

        delete listingOrders[orderId];
        IERC721(order.nft).safeTransferFrom(order.seller, msg.sender, order.tokenId);

        uint256 fee = feeReceiver == address(0) ? 0 : order.price * feeBP / 10000;
        if (order.payToken == ETH_FLAG) {
            require(msg.value == order.price, "MKT: wrong eth value");
        } else {
            require(msg.value == 0, "MKT: wrong eth value");
        }
        _transferOut(order.payToken, order.seller, order.price - fee);
        if (fee > 0) _transferOut(order.payToken, feeReceiver, fee);
        emit Sold(orderId, msg.sender, fee);
    }
    function _transferOut(address token, address to, uint256 amount) private {
        if (token == ETH_FLAG) {
            (bool success,) = to.call{value: amount}("");
            require(success, "MKT: transfer failed");
        } else {
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, to, amount);
        }
    }
    bytes32 constant WL_TYPEHASH = keccak256("IsWhiteList(address user)");
    function _checkWL(bytes calldata signature) private view {
        bytes32 wlHash = _hashTypedDataV4(keccak256(abi.encode(WL_TYPEHASH, msg.sender)));
        address signer = ECDSA.recover(wlHash, signature);
        require(signer == whiteListSigner, "MKT: not whiteListSigner");
    }

    function setWhiteListSigner(address signer) external onlyOwner {
        require(signer != address(0), "MKT: zero address");
        require(whiteListSigner != signer, "MKT:repeat set");
        whiteListSigner = signer;
        emit SetWhiteListSigner(signer);
    }
    function setFeeTo(address to) external onlyOwner {
        require(feeTo != to, "MKT:repeat set");
        feeTo = to;
        emit SetFeeTo(to);
    }
    event List(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 orderId,
        address seller,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    event Cancel(bytes32 orderId);
    event Sold(bytes32 orderId, address buyer, uint256 fee);
    event SetFeeTo(address to);
    event SetWhiteListSigner(address signer);
}
```

下面是合约代码的解释：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//NFTMarket 合约继承了 Ownable 和 EIP712 合约。Ownable 合约用于管理合约的所有权，构造函数中 msg.sender 作为初始所有者，EIP712 用于定义结构化数据的标准化签名。
contract NFTMarket is Ownable(msg.sender), EIP712("OpenSpaceNFTMarket", "1") {
    //用作以太坊生态系统中的 ETH 标识符
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    //定义手续费设置为千三
    uint256 public constant feeBP = 30; // 30/10000 = 0.3%
    //定义白名单签名者地址
    address public whiteListSigner;
    //定义手续费接收地址
    address public feeTo; 
    //挂单的所有订单簿信息// listingOrders[orderId]=SellOrder 
    mapping(bytes32 => SellOrder) public listingOrders; 
    //为了方便进行订单检索，反向关联 nft id 最后一个挂单,_lastIds[nft][tokenId] = orderId; 
    mapping(address => mapping(uint256 => bytes32)) private _lastIds; //  nft -> lastOrderId
    //出售订单的结构体
    struct SellOrder {
        address seller;  //出售者
        address nft;     //出售的nft
        uint256 tokenId; //nft的编号
        address payToken; //要支付的token
        uint256 price;   //价格
        uint256 deadline; //截止日期
    }
    // 用于查询指定 NFT（通过其合约地址 nft 和 Token ID tokenId 唯一标识）的最新挂牌订单
    function listing(address nft, uint256 tokenId) external view returns (bytes32) {
        //从 _lastIds 映射中获取指定 nft 地址和 tokenId 对应的最后一个 ID
        bytes32 id = _lastIds[nft][tokenId];
        //三元运算符 ? :：检查 listingOrders[id].seller 是否为空地址。如果是空地址，返回 bytes32(0x00)；否则返回订单 ID id。
        return listingOrders[id].seller == address(0) ? bytes32(0x00) : id;
    }
    //上架nft
    function list(address nft, uint256 tokenId, address payToken, uint256 price, uint256 deadline) external {
        //验证是否过期
        require(deadline > block.timestamp, "MKT: deadline is in the past");
        //价格要大于0
        require(price > 0, "MKT: price is zero");
        //验证支付的币为合法的
        require(payToken == address(0) || IERC20(payToken).totalSupply() > 0, "MKT: payToken is not valid");

        // 安全检查，nft的拥有者是交易的发起人
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "MKT: not owner");
        //单个或者全部的nft授权给合约地址
        require(
            IERC721(nft).getApproved(tokenId) == address(this)
                || IERC721(nft).isApprovedForAll(msg.sender, address(this)),
            "MKT: not approved"
        );
        //创建挂单订单，memory在函数接下来要用到
        SellOrder memory order = SellOrder({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            payToken: payToken,
            price: price,
            deadline: deadline
        });
        //将订单进行哈希，拿到orderId
        bytes32 orderId = keccak256(abi.encode(order));
        // 安全检查看用户是否重复上架
        require(listingOrders[orderId].seller == address(0), "MKT: order already listed");
        //上架
        listingOrders[orderId] = order;
        //上架后进行一个反向绑定，方便检索订单
        _lastIds[nft][tokenId] = orderId; 
        //触发事件
        emit List(nft, tokenId, orderId, msg.sender, payToken, price, deadline);
    }
    //取消订单
    function cancel(bytes32 orderId) external {
        //给一个orderId查出seller
        address seller = listingOrders[orderId].seller;
        // 检查seller是否空地址，是否拥有者
        require(seller != address(0), "MKT: order not listed");
        require(seller == msg.sender, "MKT: only seller can cancel");
        //删除订单
        delete listingOrders[orderId];
        //记录删除事件
        emit Cancel(orderId);
    }
    //普通用户根据id买，需要收费地址
    function buy(bytes32 orderId) public payable {
        _buy(orderId, feeTo);
    }
    //白名单用户根据ID买，不需要收费地址
    function buy(bytes32 orderId, bytes calldata signatureForWL) external payable {
        //验证白名单，需要白名单用户的signatureForWL
        _checkWL(signatureForWL);
        // 交易的手续费为0
        _buy(orderId, address(0));
    }
    //用户买的实现
    function _buy(bytes32 orderId, address feeReceiver) private {
        // 0. 检查读取交易的订单
        SellOrder memory order = listingOrders[orderId];

        // 1. 看订单是否存在？
        require(order.seller != address(0), "MKT: order not listed");
        require(order.deadline > block.timestamp, "MKT: order expired");

        // 2. 删除订单信息 防止重入攻击
        delete listingOrders[orderId];
        // 3.  NFT 交货
        IERC721(order.nft).safeTransferFrom(order.seller, msg.sender, order.tokenId);

        // 4.  token 交钱
        // fee 0.3% or 0 设置fee用的情况，三元函数计算交易的手续费
        uint256 fee = feeReceiver == address(0) ? 0 : order.price * feeBP / 10000;
        // 用户发送的以太币（ETH）数量是否正确
        if (order.payToken == ETH_FLAG) {
            //确保用户发送的 ETH 数量与订单价格一致
            require(msg.value == order.price, "MKT: wrong eth value");
        } else {
            //订单中指定的支付代币不是 ETH，要求用户在调用此函数时不能发送 ETH
            require(msg.value == 0, "MKT: wrong eth value");
        }
        // 5. 支付卖家
        _transferOut(order.payToken, order.seller, order.price - fee);
        // 6. 订单完成，如果费用大于0，将费用从订单中指定的支付代币转移给接收者
        if (fee > 0) _transferOut(order.payToken, feeReceiver, fee);
        //触发 Sold 事件，记录订单ID、买家地址和交易费用。
        emit Sold(orderId, msg.sender, fee);
    }
    //执行转账
    function _transferOut(address token, address to, uint256 amount) private {
        if (token == ETH_FLAG) {
            // 如果是eth，使用call执行转账并检查成功
            (bool success,) = to.call{value: amount}("");
            require(success, "MKT: transfer failed");
        } else {
            //如果是erc20代币，使用safeerc20转账
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, to, amount);
        }
    }
    // 定义一个白名单的哈希，这个白名单是线下就做好的
    bytes32 constant WL_TYPEHASH = keccak256("IsWhiteList(address user)");
    // 做一个白名单验证
    function _checkWL(bytes calldata signature) private view {
        // 调用合约的账户地址（买家）msg.sender和WL_TYPEHASH编码，对编码后的数据进行哈希运算，使其符合 EIP-712 规范
        bytes32 wlHash = _hashTypedDataV4(keccak256(abi.encode(WL_TYPEHASH, msg.sender)));
        //使用 ECDSA 算法恢复签名者的地址
        address signer = ECDSA.recover(wlHash, signature);
        //检查签名者是否为白名单签名者
        require(signer == whiteListSigner, "MKT: not whiteListSigner");
    }

    // 主要作用是设置或更改白名单签名者的地址
    function setWhiteListSigner(address signer) external onlyOwner {
        //检查传入的 signer 地址是否为零地址（address(0)）
        require(signer != address(0), "MKT: zero address");
        //检查传入的 signer 地址是否与当前的 whiteListSigner 相同
        require(whiteListSigner != signer, "MKT:repeat set");
        // signer：新设置的白名单签名者的地址，将 whiteListSigner 更新为新的 signer 地址
        whiteListSigner = signer;
        //触发 SetWhiteListSigner 事件，记录新的白名单签名者地址
        emit SetWhiteListSigner(signer);
    }
    //用于设置或更改费用接收者的地址
    function setFeeTo(address to) external onlyOwner {
        //检查传入的 to 地址是否与当前的 feeTo 地址相同
        require(feeTo != to, "MKT:repeat set");
        //将 feeTo 更新为新的 to 地址
        feeTo = to;
        //触发 SetFeeTo 事件，记录新的费用接收者地址
        emit SetFeeTo(to);
    }
    //事件记录了 NFT 的挂牌信息
    event List(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 orderId,
        address seller,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    //事件记录了订单的取消信息
    event Cancel(bytes32 orderId);
    //事件记录了 NFT 的售出信息及相关费用
    event Sold(bytes32 orderId, address buyer, uint256 fee);
    //事件记录了费用接收者地址的变更
    event SetFeeTo(address to);
    //事件记录了白名单签名者地址的变更
    event SetWhiteListSigner(address signer);
}
```

### 5. 编写部署脚本

在 `script` 目录下创建部署脚本 `DeployNFTMarket.s.sol`：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        address feeTo = 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69; 
        address whiteListSigner = 0x65034a9364DF72534d98Acb96658450f9254ff59; 

        vm.startBroadcast();
        
        NFTMarket nftMarket = new NFTMarket();
        
        nftMarket.setFeeTo(feeTo);

        nftMarket.setWhiteListSigner(whiteListSigner);
        
        console.log("NFTMarket deployed to:", address(nftMarket));
        
        vm.stopBroadcast();
    }
}
```

### 6. 编译合约

编译合约代码：

```
forge build
```

输出结果为：

```
yhb@yhbdeMacBook-Air MyNFTMarketProject % forge clean
forge build

[⠊] Compiling...
[⠔] Compiling 50 files with Solc 0.8.25
[⠒] Solc 0.8.25 finished in 1.48s
Compiler run successful!
```

### 

### 7. 部署合约

使用 Foundry 的 `forge script` 命令部署合约。首先，确保你有一个钱包私钥并导出到环境变量：

```
export PRIVATE_KEY=your_PRIVATE_KEY
export RPC_URL=your_RPC_URL
```

然后运行部署脚本：

```
forge script script/DeployNFTMarket.s.sol --rpc-url ${RPC_URL}  --broadcast --verify -vvvv --private-key ${PRIVATE_KEY}
```

输出结果为：

```
yhb@yhbdeMacBook-Air MyNFTMarketProject % forge script script/DeployNFTMarket.s.sol --rpc-url ${RPC_URL} --broadcast --verify -vvvv --private-key ${PRIVATE_KEY}

[⠊] Compiling...
No files changed, compilation skipped
Traces:
  [1462158] DeployNFTMarket::run()
    ├─ [0] VM::startBroadcast()
    │   └─ ← [Return] 
    ├─ [1372994] → new NFTMarket@0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   └─ ← [Return] 6733 bytes of code
    ├─ [23907] NFTMarket::setFeeTo(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   ├─ emit SetFeeTo(to: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    │   └─ ← [Stop] 
    ├─ [23910] NFTMarket::setWhiteListSigner(0x65034a9364DF72534d98Acb96658450f9254ff59)
    │   ├─ emit SetWhiteListSigner(signer: 0x65034a9364DF72534d98Acb96658450f9254ff59)
    │   └─ ← [Stop] 
    ├─ [0] console::log("NFTMarket deployed to:", NFTMarket: [0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99]) [staticcall]
    │   └─ ← [Stop] 
    ├─ [0] VM::stopBroadcast()
    │   └─ ← [Return] 
    └─ ← [Stop] 


Script ran successfully.

== Logs ==
  NFTMarket deployed to: 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99

## Setting up 1 EVM.
==========================
Simulated On-chain Traces:

  [1372994] → new NFTMarket@0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99
    ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    └─ ← [Return] 6733 bytes of code

  [25907] NFTMarket::setFeeTo(0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    ├─ emit SetFeeTo(to: 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69)
    └─ ← [Stop] 

  [25910] NFTMarket::setWhiteListSigner(0x65034a9364DF72534d98Acb96658450f9254ff59)
    ├─ emit SetWhiteListSigner(signer: 0x65034a9364DF72534d98Acb96658450f9254ff59)
    └─ ← [Stop] 


==========================

Chain 11155111

Estimated gas price: 12.282704523 gwei

Estimated total gas used for script: 2145763

Estimated amount required: 0.026355772905386049 ETH

==========================

##### sepolia
✅  [Success]Hash: 0xfef111d53d0a9c3e3304a7f40f56cab3bb21cd22e2b8156196950bcef7df4c64
Contract Address: 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99
Block: 6344838
Paid: 0.00948078701950216 ETH (1547032 gas * 6.12837163 gwei)


##### sepolia
✅  [Success]Hash: 0x5bb84c32803b8f510e67627f68e797721fc02eb0b728ba5c558f98ae50f4d20d
Block: 6344838
Paid: 0.00029011098459257 ETH (47339 gas * 6.12837163 gwei)


##### sepolia
✅  [Success]Hash: 0x195615ec2d73f64441a773824684292f5b477d2cf89ac6a3d69f323ee73547e3
Block: 6344838
Paid: 0.00029012936970746 ETH (47342 gas * 6.12837163 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.01006102737380219 ETH (1641713 gas * avg 6.12837163 gwei)
                                                                                                                                                                  

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (1) contracts
Start verifying contract `0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99` deployed on sepolia

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99.

Submitting verification for [src/NFTMarket.sol:NFTMarket] 0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99.
Submitted contract for verification:
        Response: `OK`
        GUID: `mv4uvpt29eawjruhy91egtzj1y1f5su1xyrwrwnemk8ps8kwbv`
        URL: https://sepolia.etherscan.io/address/0x23225a72386c4cbcd5cb08c2e36f4fae56b40e99
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

好现在合约开源了合约地址是0x23225A72386c4CbcD5CB08c2E36f4FaE56B40E99， 使用 TheGraph 索引 NFTMarket 的上架List和成交Sold记录

### 8.登录官网创建子图

登录官网：https://thegraph.com/studio/，连接钱包，进行邮件验证。验证成功后，点击创建一个子图。

![image-20240720205601356](/Users/yhb/Library/Application Support/typora-user-images/image-20240720205601356.png)

创建成功后

![image-20240720210013403](/Users/yhb/Library/Application Support/typora-user-images/image-20240720210013403.png)

### 9. 安装 The Graph CLI

首先，你需要安装 The Graph 的命令行工具：

```
npm install -g @graphprotocol/graph-cli
```

网络不好运行，换一个命令：`yarn global add @graphprotocol/graph-cli`

### 10. 初始化子图

在你的项目目录中，使用 `graph init` 命令初始化一个新的子图：

```
graph init --studio yhbnftmarket
```

输出结果为：

```
hb@yhbdeMacBook-Air MyNFTMarketProject % graph init --studio yhbnftmarket
 ›   Warning: In next major version, this flag will be removed. By default we 
 ›   will deploy to the Graph Studio. Learn more about Sunrise of Decentralized
 ›    Data 
 ›   https://thegraph.com/blog/unveiling-updated-sunrise-decentralized-data/
 ›   Warning: In next major version, this flag will be removed. By default we 
 ›   will deploy to the Graph Studio. Learn more about Sunrise of Decentralized
 ›    Data 
 ›   https://thegraph.com/blog/unveiling-updated-sunrise-decentralized-data/
 ›   Warning: In next major version, this flag will be removed. By default we 
 ›   will stop initializing a Git repository.
✔ Protocol · ethereum
✔ Subgraph slug · yhbnftmarket
✔ Directory to create the subgraph in · yhbnftmarket
✔ Ethereum network · sepolia
✔ Contract address · 0x23225a72386c4cbcd5cb08c2e36f4fae56b40e99
✔ Fetching ABI from Etherscan
✖ Failed to fetch Start Block: Failed to fetch contract creation transaction hash
✔ Do you want to retry? (Y/n) · true
✖ Failed to fetch Start Block: Failed to fetch contract creation transaction hash
✔ Do you want to retry? (Y/n) · true
✔ Fetching Start Block
✖ Failed to fetch Contract Name: Failed to fetch contract source code
✔ Do you want to retry? (Y/n) · true
✖ Failed to fetch Contract Name: Failed to fetch contract source code
✔ Do you want to retry? (Y/n) · true
✖ Failed to fetch Contract Name: Failed to fetch contract source code
✔ Do you want to retry? (Y/n) · true
✖ Failed to fetch Contract Name: Failed to fetch contract source code
✔ Do you want to retry? (Y/n) · true
✔ Fetching Contract Name
✔ Start Block · 6344838
✔ Contract Name · NFTMarket
✔ Index contract events as entities (Y/n) · true
  Generate subgraph
  Write subgraph to directory
✔ Create subgraph scaffold
✔ Initialize networks config
✔ Initialize subgraph repository
✔ Install dependencies with yarn
✔ Generate ABI and schema types with yarn codegen
Add another contract? (y/n): 
Subgraph yhbnftmarket created in yhbnftmarket

Next steps:

  1. Run `graph auth` to authenticate with your deploy key.

  2. Type `cd yhbnftmarket` to enter the subgraph.

  3. Run `yarn deploy` to deploy the subgraph.

Make sure to visit the documentation on https://thegraph.com/docs/ for further information.
```

初始化子图会做以下的工作

#### 1. 配置 `subgraph.yaml`

会生成 `subgraph.yaml` 文件，配置你的子图的程序结构。`subgraph.yaml` 文件示例：

```
specVersion: 1.0.0
indexerHints:
  prune: auto
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: NFTMarket
    network: sepolia
    source:
      address: "0x23225a72386c4cbcd5cb08c2e36f4fae56b40e99"
      abi: NFTMarket
      startBlock: 6344838
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Cancel
        - EIP712DomainChanged
        - List
        - OwnershipTransferred
        - SetFeeTo
        - SetWhiteListSigner
        - Sold
      abis:
        - name: NFTMarket
          file: ./abis/NFTMarket.json
      eventHandlers:
        - event: Cancel(bytes32)
          handler: handleCancel
        - event: EIP712DomainChanged()
          handler: handleEIP712DomainChanged
        - event: List(indexed address,indexed uint256,bytes32,address,address,uint256,uint256)
          handler: handleList
        - event: OwnershipTransferred(indexed address,indexed address)
          handler: handleOwnershipTransferred
        - event: SetFeeTo(address)
          handler: handleSetFeeTo
        - event: SetWhiteListSigner(address)
          handler: handleSetWhiteListSigner
        - event: Sold(bytes32,address,uint256)
          handler: handleSold
      file: ./src/nft-market.ts

```

#### 2. 定义 GraphQL 模式 (`schema.graphql`)

创建或编辑 `schema.graphql` 文件，定义你的数据模型：

```
type Cancel @entity(immutable: true) {
  id: Bytes!
  orderId: Bytes! # bytes32
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type EIP712DomainChanged @entity(immutable: true) {
  id: Bytes!

  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type List @entity(immutable: true) {
  id: Bytes!
  nft: Bytes! # address
  tokenId: BigInt! # uint256
  orderId: Bytes! # bytes32
  seller: Bytes! # address
  payToken: Bytes! # address
  price: BigInt! # uint256
  deadline: BigInt! # uint256
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type OwnershipTransferred @entity(immutable: true) {
  id: Bytes!
  previousOwner: Bytes! # address
  newOwner: Bytes! # address
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type SetFeeTo @entity(immutable: true) {
  id: Bytes!
  to: Bytes! # address
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type SetWhiteListSigner @entity(immutable: true) {
  id: Bytes!
  signer: Bytes! # address
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

type Sold @entity(immutable: true) {
  id: Bytes!
  orderId: Bytes! # bytes32
  buyer: Bytes! # address
  fee: BigInt! # uint256
  blockNumber: BigInt!
  blockTimestamp: BigInt!
  transactionHash: Bytes!
}

```

#### 3. 创建映射文件 (`mapping.ts`)

在 `src` 目录中创建或编辑 `mapping.ts` 文件，处理 `Listed` 和 `Sold` 等等事件的逻辑：

```
import {
  Cancel as CancelEvent,
  EIP712DomainChanged as EIP712DomainChangedEvent,
  List as ListEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  SetFeeTo as SetFeeToEvent,
  SetWhiteListSigner as SetWhiteListSignerEvent,
  Sold as SoldEvent
} from "../generated/NFTMarket/NFTMarket"
import {
  Cancel,
  EIP712DomainChanged,
  List,
  OwnershipTransferred,
  SetFeeTo,
  SetWhiteListSigner,
  Sold
} from "../generated/schema"

export function handleCancel(event: CancelEvent): void {
  let entity = new Cancel(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.orderId = event.params.orderId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleEIP712DomainChanged(
  event: EIP712DomainChangedEvent
): void {
  let entity = new EIP712DomainChanged(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleList(event: ListEvent): void {
  let entity = new List(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.nft = event.params.nft
  entity.tokenId = event.params.tokenId
  entity.orderId = event.params.orderId
  entity.seller = event.params.seller
  entity.payToken = event.params.payToken
  entity.price = event.params.price
  entity.deadline = event.params.deadline

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSetFeeTo(event: SetFeeToEvent): void {
  let entity = new SetFeeTo(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.to = event.params.to

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSetWhiteListSigner(event: SetWhiteListSignerEvent): void {
  let entity = new SetWhiteListSigner(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.signer = event.params.signer

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSold(event: SoldEvent): void {
  let entity = new Sold(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.orderId = event.params.orderId
  entity.buyer = event.params.buyer
  entity.fee = event.params.fee

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

```

#### 4. 生成 ABI 文件

这里如果是合约开源，就在下面部署的时候会自动拉取，省去这个步骤。如果不是开源那就需要准备 ABI。你可以从编译后的合约 JSON 文件中提取 ABI放到一个目录中，比如：/Users/yhb/MyNFTMarketProject/yhbnftmarket/abis/NFTMarket.json

```
[
  { "inputs": [], "name": "ECDSAInvalidSignature", "type": "error" },
  {
    "inputs": [
      { "internalType": "uint256", "name": "length", "type": "uint256" }
    ],
    "name": "ECDSAInvalidSignatureLength",
    "type": "error"
  },
  {
    "inputs": [{ "internalType": "bytes32", "name": "s", "type": "bytes32" }],
    "name": "ECDSAInvalidSignatureS",
    "type": "error"
  },
  { "inputs": [], "name": "InvalidShortString", "type": "error" },
  {
    "inputs": [
      { "internalType": "address", "name": "owner", "type": "address" }
    ],
    "name": "OwnableInvalidOwner",
    "type": "error"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "account", "type": "address" }
    ],
    "name": "OwnableUnauthorizedAccount",
    "type": "error"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "token", "type": "address" }
    ],
    "name": "SafeERC20FailedOperation",
    "type": "error"
  },
  {
    "inputs": [{ "internalType": "string", "name": "str", "type": "string" }],
    "name": "StringTooLong",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "bytes32",
        "name": "orderId",
        "type": "bytes32"
      }
    ],
    "name": "Cancel",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [],
    "name": "EIP712DomainChanged",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "nft",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "tokenId",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "bytes32",
        "name": "orderId",
        "type": "bytes32"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "seller",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "payToken",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "price",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "deadline",
        "type": "uint256"
      }
    ],
    "name": "List",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "SetFeeTo",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "signer",
        "type": "address"
      }
    ],
    "name": "SetWhiteListSigner",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "bytes32",
        "name": "orderId",
        "type": "bytes32"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "buyer",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "fee",
        "type": "uint256"
      }
    ],
    "name": "Sold",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "ETH_FLAG",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "orderId", "type": "bytes32" },
      { "internalType": "bytes", "name": "signatureForWL", "type": "bytes" }
    ],
    "name": "buy",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "orderId", "type": "bytes32" }
    ],
    "name": "buy",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "orderId", "type": "bytes32" }
    ],
    "name": "cancel",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "eip712Domain",
    "outputs": [
      { "internalType": "bytes1", "name": "fields", "type": "bytes1" },
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "string", "name": "version", "type": "string" },
      { "internalType": "uint256", "name": "chainId", "type": "uint256" },
      {
        "internalType": "address",
        "name": "verifyingContract",
        "type": "address"
      },
      { "internalType": "bytes32", "name": "salt", "type": "bytes32" },
      { "internalType": "uint256[]", "name": "extensions", "type": "uint256[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "feeBP",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "feeTo",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "nft", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "address", "name": "payToken", "type": "address" },
      { "internalType": "uint256", "name": "price", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "name": "list",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "nft", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" }
    ],
    "name": "listing",
    "outputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }],
    "name": "listingOrders",
    "outputs": [
      { "internalType": "address", "name": "seller", "type": "address" },
      { "internalType": "address", "name": "nft", "type": "address" },
      { "internalType": "uint256", "name": "tokenId", "type": "uint256" },
      { "internalType": "address", "name": "payToken", "type": "address" },
      { "internalType": "uint256", "name": "price", "type": "uint256" },
      { "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "renounceOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "to", "type": "address" }],
    "name": "setFeeTo",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "signer", "type": "address" }
    ],
    "name": "setWhiteListSigner",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "newOwner", "type": "address" }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "whiteListSigner",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  }
]

```

### 11. 验证子图

对你的 Graph Studio 进行身份验证，使你能够部署和管理你的子图

```
graph auth --studio 34e2cd6682e3a4554310ec8fa19e9b92
```

输出结果为：

```
hb@yhbdeMacBook-Air MyNFTMarketProject % graph auth --studio 34e2cd6682e3a4554310ec8fa19e9b92
 ›   Warning: In next major version, this flag will be removed. By default we 
 ›   will deploy to the Graph Studio. Learn more about Sunrise of Decentralized
 ›    Data 
 ›   https://thegraph.com/blog/unveiling-updated-sunrise-decentralized-data/
Deploy key set for https://api.studio.thegraph.com/deploy/
```

进入文件夹，build项目，生成代码和构建子图项目是部署前的必要步骤

```
cd yhbnftmarket
graph codegen && graph build
```

输出结果为：

```
hb@yhbdeMacBook-Air yhbnftmarket % graph codegen && graph build
  Skip migration: Bump mapping apiVersion from 0.0.1 to 0.0.2
  Skip migration: Bump mapping apiVersion from 0.0.2 to 0.0.3
  Skip migration: Bump mapping apiVersion from 0.0.3 to 0.0.4
  Skip migration: Bump mapping apiVersion from 0.0.4 to 0.0.5
  Skip migration: Bump mapping apiVersion from 0.0.5 to 0.0.6
  Skip migration: Bump manifest specVersion from 0.0.1 to 0.0.2
  Skip migration: Bump manifest specVersion from 0.0.2 to 0.0.4
✔ Apply migrations
✔ Load subgraph from subgraph.yaml
  Load contract ABI from abis/NFTMarket.json
✔ Load contract ABIs
  Generate types for contract ABI: NFTMarket (abis/NFTMarket.json)
  Write types to generated/NFTMarket/NFTMarket.ts
✔ Generate types for contract ABIs
✔ Generate types for data source templates
✔ Load data source template ABIs
✔ Generate types for data source template ABIs
✔ Load GraphQL schema from schema.graphql
  Write types to generated/schema.ts
✔ Generate types for GraphQL schema

Types generated successfully

  Skip migration: Bump mapping apiVersion from 0.0.1 to 0.0.2
  Skip migration: Bump mapping apiVersion from 0.0.2 to 0.0.3
  Skip migration: Bump mapping apiVersion from 0.0.3 to 0.0.4
  Skip migration: Bump mapping apiVersion from 0.0.4 to 0.0.5
  Skip migration: Bump mapping apiVersion from 0.0.5 to 0.0.6
  Skip migration: Bump manifest specVersion from 0.0.1 to 0.0.2
  Skip migration: Bump manifest specVersion from 0.0.2 to 0.0.4
✔ Apply migrations
✔ Load subgraph from subgraph.yaml
  Compile data source: NFTMarket => build/NFTMarket/NFTMarket.wasm
✔ Compile subgraph
  Copy schema file build/schema.graphql
  Write subgraph file build/NFTMarket/abis/NFTMarket.json
  Write subgraph manifest build/subgraph.yaml
✔ Write compiled subgraph to build/

Build completed: build/subgraph.yaml
```

然后部署子图：

```
graph deploy --studio nftmarket-subgraph
```

这里就会遇见一个常见的 IPFS 上传错误，通常是由于网络连接问题或 IPFS 服务临时不可用导致的。有时，IPFS 服务会出现临时问题。稍等几分钟后重试部署命令：

```
graph deploy --studio yhbnftmarket
```

如果问题仍然存在，可以尝试使用本地 IPFS 节点。首先，安装 IPFS 并启动本地节点：

#### 安装 IPFS

根据你的操作系统，安装 IPFS：

- macOS：

```
brew install ipfs
```

- Ubuntu：

```
sudo apt-get install ipfs
```

#### 启动 IPFS 节点

安装完成后，启动 IPFS 节点：

```
ipfs init
ipfs daemon
```

#### 配置 The Graph 使用本地 IPFS 节点

在项目根目录下的 `subgraph.yaml` 文件中，添加或修改以下部分以指向本地 IPFS 节点：

```
ipfs:
  host: localhost
  port: 5001
  protocol: http
```

文件内容如下：

```
specVersion: 1.0.0
indexerHints:
  prune: auto
ipfs:
  host: localhost
  port: 5001
  protocol: http

schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: NFTMarket
    network: sepolia
    source:
      address: "0x23225a72386c4cbcd5cb08c2e36f4fae56b40e99"
      abi: NFTMarket
      startBlock: 6344838
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Cancel
        - EIP712DomainChanged
        - List
        - OwnershipTransferred
        - SetFeeTo
        - SetWhiteListSigner
        - Sold
      abis:
        - name: NFTMarket
          file: ./abis/NFTMarket.json
      eventHandlers:
        - event: Cancel(bytes32)
          handler: handleCancel
        - event: EIP712DomainChanged()
          handler: handleEIP712DomainChanged
        - event: List(indexed address,indexed uint256,bytes32,address,address,uint256,uint256)
          handler: handleList
        - event: OwnershipTransferred(indexed address,indexed address)
          handler: handleOwnershipTransferred
        - event: SetFeeTo(address)
          handler: handleSetFeeTo
        - event: SetWhiteListSigner(address)
          handler: handleSetWhiteListSigner
        - event: Sold(bytes32,address,uint256)
          handler: handleSold
      file: ./src/nft-market.ts

```

然后，重新尝试部署：

```
graph deploy --studio yhbnftmarket --ipfs http://localhost:5001
```

还有远程部署

```
graph deploy --studio yhbnftmarket --ipfs https://ipfs.infura.io:5001
```

还可以用到alchemy提供的部署服务进行部署。

```
  graph deploy yhbnftmarket \
  --version-label v0.0.1-new-version \
  --node https://subgraphs.alchemy.com/api/subgraphs/deploy \
  --deploy-key n61nhCdDwtnQA \
  --ipfs https://ipfs.satsuma.xyz
```

输出结果为：

```
b@yhbdeMacBook-Air yhbnftmarket %   graph deploy yhbnftmarket \
  --version-label v0.0.1-new-version \
  --node https://subgraphs.alchemy.com/api/subgraphs/deploy \
  --deploy-key n61nhCdDwtnQA \
  --ipfs https://ipfs.satsuma.xyz
  Skip migration: Bump mapping apiVersion from 0.0.1 to 0.0.2
  Skip migration: Bump mapping apiVersion from 0.0.2 to 0.0.3
  Skip migration: Bump mapping apiVersion from 0.0.3 to 0.0.4
  Skip migration: Bump mapping apiVersion from 0.0.4 to 0.0.5
  Skip migration: Bump mapping apiVersion from 0.0.5 to 0.0.6
  Skip migration: Bump manifest specVersion from 0.0.1 to 0.0.2
  Skip migration: Bump manifest specVersion from 0.0.2 to 0.0.4
✔ Apply migrations
✔ Load subgraph from subgraph.yaml
  Compile data source: NFTMarket => build/NFTMarket/NFTMarket.wasm
✔ Compile subgraph
  Copy schema file build/schema.graphql
  Write subgraph file build/NFTMarket/abis/NFTMarket.json
  Write subgraph manifest build/subgraph.yaml
✔ Write compiled subgraph to build/
  Add file to IPFS build/schema.graphql
                .. QmSj2ZesiRS6NqdD74sTywyfzCi4S2DQTri9VZDU6dqete
  Add file to IPFS build/NFTMarket/abis/NFTMarket.json
                .. QmZySeDjEzSo2c58rxjbBFTZpJWV7BDbSS1c3TR1f5z7ve
  Add file to IPFS build/NFTMarket/NFTMarket.wasm
                .. QmQYpHo72685u3ZEKVXJq3Nm2aGw6UfvnKYx2eZqfC2PfF
✔ Upload subgraph to IPFS

Build completed: QmUHomL5Um5WdDhr3pCLydhKqU8MnZYoPHRx7WbJZC8Hc8

Deployed to https://subgraphs.alchemy.com/subgraphs/6887/versions/23328

Subgraph endpoints:
Queries (HTTP):     https://subgraph.satsuma-prod.com/hongbins-team--360746/yhbnftmarket/version/v0.0.1-new-version/api

```

到这里就是显示部署成功了。

### 14. 查询数据

子图部署完成后，你可以在 https://subgraphs.alchemy.com/dashboard来查询数据。

![image-20240721074539664](/Users/yhb/Library/Application Support/typora-user-images/image-20240721074539664.png)

![image-20240721074701949](/Users/yhb/Library/Application Support/typora-user-images/image-20240721074701949.png)

打开查询界面https://subgraph.satsuma-prod.com/hongbins-team--360746/yhbnftmarket/playground，例如，查询所有的上架记录：

```
{
  lists {
    id
    nft
    tokenId
    orderId
    seller
    payToken
    price
    deadline
    blockNumber
    blockTimestamp
    transactionHash
  }
}

```

![image-20240721075004140](/Users/yhb/Library/Application Support/typora-user-images/image-20240721075004140.png)

查询所有的成交记录：

```
{
  solds {
    id
    orderId
    buyer
    fee
    blockNumber
    blockTimestamp
    transactionHash
  }
}
```

![image-20240721075027929](/Users/yhb/Library/Application Support/typora-user-images/image-20240721075027929.png)

### 15.参考链接

- The Graph Documentation
- GraphQL Documentation

通过以上步骤，你可以成功部署并使用 TheGraph 来索引和查询你的 NFTMarket 合约的上架 List 和成交 Sold 记录。