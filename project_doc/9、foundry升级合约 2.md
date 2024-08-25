使用 Foundry 部署一个可升级的 NFT 市场合约，并在第二版本中加入离线签名上架 NFT 的功能，可以按照以下步骤进行。

实现⼀个可升级的 NFT 市场合约：
•实现合约的第⼀版本：编写一个简单的 NFT市场合约，使用自己的发行的 Token 来买卖 NFT， 函数的方法有：`list()` : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFT 市场。`buyNFT()` : 实现购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

第⼆版本，加⼊离线签名上架 NFT 功能⽅法（签名内容：tokenId， 价格），实现⽤户⼀次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使⽤签名上架。

需要部署到测试⽹，并开源到区块链浏览器，在你的Github的 Readme.md 中备注代理合约及两个实现的合约地址。

要求：

1. 有升级的测试用例（在升级前后状态不变）
2. 有运行测试的日志





### 准备环境

1. 安装 Foundry：

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

1. 初始化项目：

```
forge init nft-marketplace
cd nft-marketplace

forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-foundry-upgrades
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

实现一个可升级的 NFT 市场合约分为几个步骤。首先，我们需要编写一个简单的 NFT 市场合约，允许使用自发行的 Token 买卖 NFT。然后，我们扩展该合约以支持离线签名的 NFT 上架功能。最后，我们将合约部署到测试网，并记录合约地址在 Github 的 Readme.md 中。

### 第一步：实现第一版本的 NFT 市场合约

#### ERC20 Token 合约

首先，我们编写一个自定义的 MyToken.sol合约，用于买卖 NFT。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20,Ownable {
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK")Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
```

#### NFT 合约

然后，我们编写一个简单的 MyNFT.sol合约。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    function createNFT(string memory tokenURI) public onlyOwner returns (uint256) {
        uint256 newTokenId = tokenCounter;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenCounter++;
        return newTokenId;
    }
}

```

#### NFT 市场合约

接下来，我们编写一个简单的 NFTMarketplace.sol 市场合约。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is Ownable {
    IERC20 public token;
    struct Listing {
        uint256 price;
        address seller;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, address indexed buyer);

    constructor(IERC20 _token) {
        token = _token;
    }

    function list(address nftAddress, uint256 tokenId, uint256 price) public {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(nft.isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");

        listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit NFTListed(nftAddress, tokenId, price, msg.sender);
    }

    function buyNFT(address nftAddress, uint256 tokenId) public {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.price > 0, "NFT not listed");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftAddress][tokenId];
        emit NFTBought(nftAddress, tokenId, msg.sender);
    }
}
```

### 第二步：实现第二版本的 NFT 市场合约

#### 离线签名上架功能

在第二版本NFTMarketplaceV2.sol中，我们将实现离线签名上架 NFT 的功能。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTMarketplace.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NFTMarketplaceV2 is NFTMarketplace, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    mapping(bytes32 => bool) public usedSignatures;

    function initialize(address _token) initializer public {
        __Ownable_init();
        NFTMarketplace.initialize(IERC20(_token));
    }

    function listWithSignature(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        bytes memory signature
    ) public {
        bytes32 messageHash = keccak256(abi.encodePacked(nftAddress, tokenId, price));
        require(!usedSignatures[messageHash], "Signature already used");

        address signer = recoverSigner(messageHash, signature);
        require(signer == IERC721(nftAddress).ownerOf(tokenId), "Invalid signature");

        usedSignatures[messageHash] = true;
        super.list(nftAddress, tokenId, price);
    }

    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        return recover(ethSignedMessageHash, signature);
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        return ecrecover(hash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### 第三步：编写测试用例

编写测试用例NFTMarketplaceV2.t.sol，确保在升级前后状态不变。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/NFTMarketplaceV2.sol";
import "../contracts/MyToken.sol";
import "../contracts/MyNFT.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplaceV2 public marketplace;
    MyToken public token;
    MyNFT public nft;

    function setUp() public {
        token = new MyToken(1000 * 10 ** 18);
        nft = new MyNFT();
        marketplace = new NFTMarketplaceV2();
        marketplace.initialize(address(token));
    }

    function testListAndBuy() public {
        nft.createNFT("uri");
        nft.setApprovalForAll(address(marketplace), true);

        marketplace.list(address(nft), 0, 100 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 1000 * 10 ** 18);
        
        token.approve(address(marketplace), 100 * 10 ** 18);
        marketplace.buyNFT(address(nft), 0);
        
        assertEq(nft.ownerOf(0), address(this));
        assertEq(token.balanceOf(address(this)), 900 * 10 ** 18);
    }
}
```

### 第四步：部署合约到测试网并记录合约地址

在这一步，我们将详细介绍如何使用 Foundry 部署合约到测试网，并记录代理合约及两个实现合约的地址。

#### 2. 编写合约

在 `src` 目录下创建你的合约文件：

- `src/MyToken.sol`
- `src/MyNFT.sol`
- `src/NFTMarketplace.sol`
- `src/NFTMarketplaceV2.sol`

你可以将之前提供的合约代码分别放入这些文件中。

#### 3. 编写部署脚本

在 `script` 目录下创建一个新的脚本文件 `Deploy.s.sol`：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketplace.sol";
import "../src/NFTMarketplaceV2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署自定义的 ERC20 Token 合约
        MyToken token = new MyToken(1000 * 10 ** 18);

        // 部署 ERC721 NFT 合约
        MyNFT nft = new MyNFT();

        // 部署 NFT Marketplace 合约的第一个版本
        NFTMarketplace marketplaceV1 = new NFTMarketplace(address(token));

        // 部署 NFT Marketplace 合约的第二个版本
        NFTMarketplaceV2 marketplaceV2 = new NFTMarketplaceV2();

        // 部署 ProxyAdmin 合约
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // 部署 TransparentUpgradeableProxy 合约，并指向第一个版本的实现合约
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(marketplaceV1),
            address(proxyAdmin),
            ""
        );

        vm.stopBroadcast();

        // 打印合约地址
        console.log("MyToken address:", address(token));
        console.log("MyNFT address:", address(nft));
        console.log("NFTMarketplaceV1 address:", address(marketplaceV1));
        console.log("NFTMarketplaceV2 address:", address(marketplaceV2));
        console.log("ProxyAdmin address:", address(proxyAdmin));
        console.log("TransparentUpgradeableProxy address:", address(proxy));
    }
}
```

#### 4. 部署到测试网

确保你有一个支持的网络配置，例如 Alchemy 或 Infura。然后，在 `.env` 文件中配置你的私钥和网络 URL：

```
PRIVATE_KEY=你的私钥
RPC_URL=你的网络URL
```

使用 Foundry 部署合约：

```
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

#### 5. 更新 Github 的 Readme.md

在 Github 的 Readme.md 中添加代理合约及两个实现的合约地址。你可以从部署脚本的输出中获取这些地址：

```
## NFT Marketplace Contracts

### Proxy Contract
- Address: [TransparentUpgradeableProxy address]

### Implementation Contracts
- V1: [NFTMarketplaceV1 address]
- V2: [NFTMarketplaceV2 address]
```

### 运行测试并记录日志

确保所有测试用例通过，并记录测试日志。

```
forge test --contracts test/NFTMarketplaceTest.sol -vv
```

通过这些步骤，你将成功地在测试网上部署一个可升级的 NFT 市场合约，并在 Github 的 Readme.md 中记录代理合约及两个实现的合约地址。

### 第五步：更新 Github 的 Readme.md

在 Github 的 Readme.md 中添加代理合约及两个实现的合约地址。

```
## NFT Marketplace Contracts

### Proxy Contract
- Address: [proxy_contract_address]

### Implementation Contracts
- V1: [v1_contract_address]
- V2: [v2_contract_address]
```

### 运行测试并记录日志

确保所有测试用例通过，并记录测试日志。

```
forge test --contracts test/NFTMarketplaceTest.sol -vv
```

完成这些步骤后，你将拥有一个可升级的 NFT 市场合约，并且可以在测试网上验证其功能。



### 

