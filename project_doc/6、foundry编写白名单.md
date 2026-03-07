实现一个支持 Merkle 树白名单验证和 Permit 授权的 `AirdropMerkleNFTMarket` 合约，需要如下步骤：

1. **Merkle 树白名单验证**：使用 Merkle 树验证用户是否在白名单中。
2. **Permit 授权**：使用 ERC20 的 `permit` 方法来授权 token 支付。
3. **Multicall 调用**：使用 `delegateCall` 方式在一次交易中调用 `permitPrePay` 和 `claimNFT`。

以下是详细的实现步骤：

我们需要设置一个 Foundry 项目，编写合约代码，编写测试用例，并运行测试。以下是详细的步骤和代码示例。

### 总结

1. **创建 Foundry 项目** 并安装必要的依赖。
2. **编写合约代码**，包括 Token、NFT 和 AirdropMerkleNFTMarket 合约。
3. **生成 Merkle 树和根节点**，并将根节点值添加到合约中。
4. **编写测试用例** 并确保所有功能正常。
5. **运行测试** 确保合约的行为符合预期。

### 设置 Foundry 项目

首先，确保你已安装 Foundry。如果没有安装，可以通过以下命令安装：

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

安装完成后，创建一个新的 Foundry 项目：

```
forge init merkleNFTMarket
cd merkleNFTMarket
forge install OpenZeppelin/openzeppelin-contracts
```

**生成 `remappings.txt`：**

在项目根目录下运行以下命令：

```
forge remappings > remappings.txt
```

这将生成一个 `remappings.txt` 文件，并将当前依赖项的映射信息写入其中。

**检查和修改 `remappings.txt`：**

打开生成的 `remappings.txt`，它通常会包含类似以下的内容：

```
@openzeppelin/=lib/openzeppelin-contracts/
```

- `@openzeppelin/` 是 Solidity 中 `import` 的路径前缀。
- `lib/openzeppelin-contracts/` 是 OpenZeppelin 库在本地文件系统中的相对路径。

### 合约实现

#### Token 合约

首先，我们需要一个支持 `permit` 的 ERC20 Token 合约。这里我们可以使用 OpenZeppelin 的 ERC20Permit 扩展。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyToken is ERC20, ERC20Permit {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
```

#### NFT 合约

我们也需要一个简单的 NFT 合约。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, tokenCounter);
        tokenCounter++;
    }
}

```

#### AirdropMerkleNFTMarket 合约

接下来是 `AirdropMerkleNFTMarket` 合约的实现。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarket {
    IERC20 public token;
    IERC721 public nft;
    address public owner;
    bytes32 public merkleRoot;
    mapping(uint256 => uint256) public nftPrices; // NFT ID to price

    constructor(IERC20 _token, IERC721 _nft, bytes32 _merkleRoot) {
        token = _token;
        nft = _nft;
        owner = msg.sender;
        merkleRoot = _merkleRoot;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setPrice(uint256 nftId, uint256 price) external onlyOwner {
        nftPrices[nftId] = price;
    }

    function permitPrePay(
        address holder,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(token)).permit(holder, address(this), value, deadline, v, r, s);
    }

    function claimNFT(
        uint256 nftId,
        bytes32[] calldata merkleProof,
        address buyer
    ) external {
        require(isWhitelisted(msg.sender, merkleProof), "Not whitelisted");
        uint256 price = nftPrices[nftId] / 2; // 50% discount
        require(token.transferFrom(buyer, owner, price), "Transfer failed");
        nft.safeTransferFrom(owner, buyer, nftId);
    }

    function isWhitelisted(address account, bytes32[] calldata merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}

```

#### Multicall 合约

实现 `multicall` 以便一次性调用两个方法。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract Multicall {
    function multicall(bytes[] calldata data) external {
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Multicall: delegatecall failed");
        }
    }
}
```

### Merkle 树生成

### 生成 Merkle 树和根节点

**生成 Merkle 树和根节点的步骤：**

1. **创建一个 Node.js 项目：**

   首先，你需要创建一个用于生成 Merkle 树和根节点的 Node.js 项目。你可以在你的 Foundry 项目目录下创建一个子目录，例如 `scripts`，并在其中创建一个 JavaScript 文件。

   ```
   mkdir scripts
   cd scripts
   touch generateMerkleTree.js
   ```

2. **安装所需的 Node.js 库：**

   你需要安装 `merkletreejs` 和 `keccak256` 这两个库来生成 Merkle 树。可以使用 `npm` 来安装这些库。

   ```
   npm init -y
   npm install merkletreejs keccak256
   ```

3. **编写生成 Merkle 树的脚本：**

   在 `generateMerkleTree.js` 文件中编写以下代码：

   ```
   const { MerkleTree } = require('merkletreejs');
   const keccak256 = require('keccak256');
   const fs = require('fs');
   
   // 示例白名单地址
   const whitelist = [
     '0x65034a9364DF72534d98Acb96658450f9254ff59',
     '0x6Bf159Eb8e007Bd3CBb65b1478AeE7C32001CCdC',
     '0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69',
   ];
   
   // 将地址转换为 Merkle 树的叶子节点
   const leaves = whitelist.map(addr => keccak256(addr));
   const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
   const root = tree.getHexRoot();
   
   // 输出 Merkle 根节点
   console.log('Merkle Root:', root);
   
   // 将 Merkle 根节点写入文件
   fs.writeFileSync('merkleRoot.txt', root);
   ```

   请将 `whitelist` 数组中的地址替换为你的实际白名单地址。

4. **运行生成脚本：**

   ```
   node generateMerkleTree.js
   ```

   运行脚本后，会在 `scripts` 目录下生成一个 `merkleRoot.txt` 文件，其中包含生成的 Merkle 根节点。

5. **将根节点值添加到合约中：**

   打开 `AirdropMerkleNFTMarket` 合约，将 `merkleRoot` 变量的值设置为从 `merkleRoot.txt` 文件中读取的值。可以在部署合约时读取文件内容并设置根节点，或者直接在合约中硬编码。

   ### 编写部署脚本

   接下来，在 Foundry 项目中创建一个脚本，用于读取 `merkleRoot.txt` 并部署合约。确保在脚本中正确传递 `merkleRoot`。

   在 `script/` 目录下创建一个新的脚本文件，例如 `DeployAirdropMerkleNFTMarket.s.sol`：

   ```
   // SPDX-License-Identifier: MIT
   pragma solidity ^0.8.25;
   
   import "forge-std/Script.sol";
   import "../src/MyToken.sol";
   import "../src/MyNFT.sol";
   import "../src/AirdropMerkleNFTMarket.sol";
   
   contract DeployAirdropMerkleNFTMarket is Script {
       function run() external {
           vm.startBroadcast();
   
           // 读取 merkleRoot.txt 文件
           string memory rootFile = "merkleRoot.txt";
           string memory root = vm.readFile(rootFile);
           bytes32 merkleRoot = bytes32(abi.decode(bytes(root), (bytes32)));
   
           // Instantiate token and NFT without constructor arguments
           IERC20 token = new MyToken();
           IERC721 nft = new MyNFT();
   
           // 部署 AirdropMerkleNFTMarket 合约
           AirdropMerkleNFTMarket market = new AirdropMerkleNFTMarket(token, nft, merkleRoot);
   
           console.log("AirdropMerkleNFTMarket deployed to:", address(market));
   
           vm.stopBroadcast();
       }
   }
   
   ```

   ### 部署合约

   编写好.env文件，确保你的 Foundry 项目设置正确，然后运行部署脚本以部署合约：

   ```
   source .env
   
   forge script script/DeployAirdropMerkleNFTMarket.s.sol --rpc-url ${RPC_URL} --broadcast --verify -vvvv --private-key ${PRIVATE_KEY}
   ```

输出结果为

```
yhb@yhbdeMacBook-Air merkleNFTMarket % forge script script/DeployAirdropMerkleNFTMarket.s.sol --rpc-url ${RPC_URL} --broadcast --private-key ${PRIVATE_KEY}          
[⠒] Compiling...
No files changed, compilation skipped
Script ran successfully.

== Logs ==
  AirdropMerkleNFTMarket deployed to: 0x46e2c3790Bc8Ff52021F6bc7Bba406992C365351

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 69.44584673 gwei

Estimated total gas used for script: 3419525

Estimated amount required: 0.23747180903940325 ETH

==========================

##### sepolia
✅  [Success]Hash: 0xadd9ea5eab27380587b0cbae1c4c175a84919034f3187831335d1121b4ea828b
Contract Address: 0x46e2c3790Bc8Ff52021F6bc7Bba406992C365351
Block: 6454828
Paid: 0.020413553107342304 ETH (555296 gas * 36.761570599 gwei)


##### sepolia
✅  [Success]Hash: 0x3ebfd3f07f01aad1825e7a590a1c257152392d35e7da0dd30a6b12ccfb24bef5
Contract Address: 0xa417d3B8Ac9f880912063FC82adafC3BEf839491
Block: 6454828
Paid: 0.036566587228542904 ETH (994696 gas * 36.761570599 gwei)


##### sepolia
✅  [Success]Hash: 0xce2ce371bb4ca3aa4ea4c8057e195769ab6fdbc73c402c8fb0d5a1e6062bd7d6
Contract Address: 0xED6dC78849C06f53a2eE5a7a82bCBAe10c9980Be
Block: 6454828
Paid: 0.039746426323785805 ETH (1081195 gas * 36.761570599 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.096726566659671013 ETH (2631187 gas * avg 36.761570599 gwei)
                                                                             

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/yhb/merkleNFTMarket/broadcast/DeployAirdropMerkleNFTMarket.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/yhb/merkleNFTMarket/cache/DeployAirdropMerkleNFTMarket.s.sol/11155111/run-latest.json

```



### Foundry 测试用例

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "./AirdropMerkleNFTMarket.sol";
import "./MyToken.sol";
import "./MyNFT.sol";
import "./Multicall.sol";

contract AirdropMerkleNFTMarketTest is Test {
    MyToken token;
    MyNFT nft;
    AirdropMerkleNFTMarket market;
    Multicall multicall;
    bytes32 merkleRoot;
    address owner;
    address buyer;
    bytes32[] merkleProof;

    function setUp() public {
        owner = address(this);
        buyer = address(0x123);
        token = new MyToken();
        nft = new MyNFT();
        merkleRoot = 0xabc123; // replace with your actual merkle root
        market = new AirdropMerkleNFTMarket(IERC20(address(token)), IERC721(address(nft)), merkleRoot);
        multicall = new Multicall();
        
        // Mint NFT to market owner
        nft.mint(owner);

        // Set NFT price
        market.setPrice(0, 1000 * 10**18);

        // Approve tokens for buyer
        token.transfer(buyer, 1000 * 10**18);
        vm.prank(buyer);
        token.approve(address(market), 1000 * 10**18);
    }

    function testBuyWithPermit() public {
        // Construct permit signature
        uint256 deadline = block.timestamp + 3600;
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            keccak256(abi.encodePacked(token.DOMAIN_SEPARATOR(), keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                500 * 10**18,
                token.nonces(buyer),
                deadline
            ))))
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0, digest); // Sign with buyer's key

        // Prepare multicall data
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(market.permitPrePay.selector, buyer, 500 * 10**18, deadline, v, r, s);
        data[1] = abi.encodeWithSelector(market.claimNFT.selector, 0, merkleProof, buyer);

        // Execute multicall
        multicall.multicall(data);

        // Check NFT ownership
        assertEq(nft.ownerOf(0), buyer);
    }
}
```

### 总结

上述代码展示了如何使用 Foundry 实现一个支持 Merkle 树白名单验证、Permit 授权和 Multicall 调用的 `AirdropMerkleNFTMarket` 合约。通过这些步骤，可以实现一个用户友好的、一次性购买优惠 NFT 的市场合约。









