# 使用 EIP712 进行链下 Permit 和白名单设计

## 

### 概述

本项目实现了基于 EIP-2612 标准的代币合约，并扩展了 `TokenBank` 和 `NFTMarketplace` 合约，支持链下签名授权和白名单机制。以下文档详细描述了合约的实现以及测试用例。

## 环境设置

### 1. 安装 Foundry

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 创建新项目

```
forge init my-project
cd my-project
```

### 3. 安装 OpenZeppelin 合约库

```
forge install OpenZeppelin/openzeppelin-contracts
```



## 合约实现

### 1. YHB Token 合约

使用 EIP-2612 标准创建 YHB Token 合约。

#### `YHBToken.sol`

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract YHBToken is ERC20Permit, Ownable {
    constructor() ERC20("YHB Token", "YHB") ERC20Permit("YHB Token") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function getPermitTypehash() public pure returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}

```



部署合约

```
source .env

forge script script/DeployYHBToken.s.sol --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

输出结果为：

```
yhb@yhbdeMacBook-Air my-project % forge script script/DeployYHBToken.s.sol --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --broadcast
[⠒] Compiling...
No files changed, compilation skipped
Script ran successfully.

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 30.016571506 gwei

Estimated total gas used for script: 1466390

Estimated amount required: 0.04401600029068334 ETH

==========================

##### sepolia
✅  [Success]Hash: 0xa041b504d39a321be4241eb04b7e907fdf9c4e8ebc3714a361f94d32502a4a0b
Contract Address: 0xdF1C65d42d94D48Fa4F7715f075644b81EcAe62b
Block: 6321854
Paid: 0.017693725415895924 ETH (1128381 gas * 15.680630404 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.017693725415895924 ETH (1128381 gas * avg 15.680630404 gwei)
                                                                         

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/yhb/my-project/broadcast/DeployYHBToken.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/yhb/my-project/cache/DeployYHBToken.s.sol/11155111/run-latest.json
```



### 2. TokenBank 合约

在 `TokenBank` 合约中添加 `permitDeposit` 函数，支持通过链下签名授权进行存款。

#### `TokenBank.sol`

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TokenBank {
    IERC20 public token;
    mapping(address => uint256) public balances;

    // 定义事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balances[msg.sender] += amount;
        
        // 触发存款事件
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        // 触发取款事件
        emit Withdraw(msg.sender, amount);
    }

    // 新增 permitDeposit 函数
    function permitDeposit(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 调用ERC20Permit的permit方法进行授权
        ERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);

        // 存款逻辑
        require(token.transferFrom(owner, address(this), value), "Transfer failed");
        balances[owner] += value;
        
        // 触发存款事件
        emit Deposit(owner, value);
    }
}

```

测试文件TokenBank.t.sol：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "../src/TokenBank.sol";
import "../src/YHBToken.sol";

contract TokenBankTest is Test {
    TokenBank public bank;
    YHBToken public token;
    address public owner;
    address public user1;
    uint256 private ownerPrivateKey;

    function setUp() public {
        ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
        owner = vm.addr(ownerPrivateKey);
        user1 = address(0x1);

        // 部署ERC20合约
        token = new YHBToken();
        
        // 部署TokenBank合约
        bank = new TokenBank(address(token));

        // 给测试合约的地址分配一些token
        token.mint(owner, 1000 * 10 ** token.decimals());
    }

    function testDeposit() public {
        uint256 amount = 100 * 10 ** token.decimals();

        // 先授权给TokenBank合约
        vm.prank(owner);
        token.approve(address(bank), amount);

        // 调用TokenBank的deposit函数
        vm.prank(owner);
        bank.deposit(amount);

        // 检查TokenBank合约的余额和用户的存款
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(bank.balances(owner), amount);
    }

    function testPermitDeposit() public {
        uint256 amount = 100 * 10 ** token.decimals();
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.getDomainSeparator(),
                keccak256(abi.encode(
                    token.getPermitTypehash(),
                    owner,
                    address(bank),
                    amount,
                    nonce,
                    deadline
                ))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // 调用TokenBank的permitDeposit函数
        vm.prank(owner);
        bank.permitDeposit(owner, amount, deadline, v, r, s);

        // 检查TokenBank合约的余额和用户的存款
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(bank.balances(owner), amount);
    }
}

```

测试命令：

```
forge test --match-contract TokenBankTest -vvvv
```

输出结果：

```
Book-Air my-project % forge test --match-contract TokenBankTest -vvvv

[⠰] Compiling...
[⠃] Compiling 1 files with Solc 0.8.25
[⠊] Solc 0.8.25 finished in 10.26s
Compiler run successful!

Ran 2 tests for test/TokenBank.t.sol:TokenBankTest
[PASS] testDeposit() (gas: 82419)
Traces:
  [82419] TokenBankTest::testDeposit()
    ├─ [222] YHBToken::decimals() [staticcall]
    │   └─ ← [Return] 18
    ├─ [0] VM::prank(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266)
    │   └─ ← [Return] 
    ├─ [24762] YHBToken::approve(TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], 100000000000000000000 [1e20])
    │   ├─ emit Approval(owner: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, spender: TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], value: 100000000000000000000 [1e20])
    │   └─ ← [Return] true
    ├─ [0] VM::prank(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266)
    │   └─ ← [Return] 
    ├─ [57451] TokenBank::deposit(100000000000000000000 [1e20])
    │   ├─ [30885] YHBToken::transferFrom(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], 100000000000000000000 [1e20])
    │   │   ├─ emit Transfer(from: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, to: TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], value: 100000000000000000000 [1e20])
    │   │   └─ ← [Return] true
    │   ├─ emit Deposit(user: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, amount: 100000000000000000000 [1e20])
    │   └─ ← [Stop] 
    ├─ [651] YHBToken::balanceOf(TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b]) [staticcall]
    │   └─ ← [Return] 100000000000000000000 [1e20]
    ├─ [0] VM::assertEq(100000000000000000000 [1e20], 100000000000000000000 [1e20]) [staticcall]
    │   └─ ← [Return] 
    ├─ [486] TokenBank::balances(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266) [staticcall]
    │   └─ ← [Return] 100000000000000000000 [1e20]
    ├─ [0] VM::assertEq(100000000000000000000 [1e20], 100000000000000000000 [1e20]) [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

[PASS] testPermitDeposit() (gas: 115199)
Traces:
  [115199] TokenBankTest::testPermitDeposit()
    ├─ [222] YHBToken::decimals() [staticcall]
    │   └─ ← [Return] 18
    ├─ [2616] YHBToken::nonces(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266) [staticcall]
    │   └─ ← [Return] 0
    ├─ [407] YHBToken::getDomainSeparator() [staticcall]
    │   └─ ← [Return] 0x6cd899580556d2787ade7e411a1c4b23eb5b43f518aeeb1471cdded883bad887
    ├─ [215] YHBToken::getPermitTypehash() [staticcall]
    │   └─ ← [Return] 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9
    ├─ [0] VM::sign("<pk>", 0x26110ffc56ea244aff0bc6cb6df1cb11b8eba960232a93ae331f9fb334d5101c) [staticcall]
    │   └─ ← [Return] 28, 0xda472b1cbca9260b64dee10c63c3e72243220cb6c71b4566c48dc9c5b3464fe1, 0x41e0f66b9728c0e0b8c180efd5018c0591e1cebcc868b8bfb67d0b1f47d49234
    ├─ [0] VM::prank(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266)
    │   └─ ← [Return] 
    ├─ [107728] TokenBank::permitDeposit(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, 100000000000000000000 [1e20], 86401 [8.64e4], 28, 0xda472b1cbca9260b64dee10c63c3e72243220cb6c71b4566c48dc9c5b3464fe1, 0x41e0f66b9728c0e0b8c180efd5018c0591e1cebcc868b8bfb67d0b1f47d49234)
    │   ├─ [49462] YHBToken::permit(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], 100000000000000000000 [1e20], 86401 [8.64e4], 28, 0xda472b1cbca9260b64dee10c63c3e72243220cb6c71b4566c48dc9c5b3464fe1, 0x41e0f66b9728c0e0b8c180efd5018c0591e1cebcc868b8bfb67d0b1f47d49234)
    │   │   ├─ [3000] PRECOMPILES::ecrecover(0x26110ffc56ea244aff0bc6cb6df1cb11b8eba960232a93ae331f9fb334d5101c, 28, 98729944682591051163648568416182464899298529114443776240882444257116044021729, 29797809630657198228133730577169343835294414083442081449959608353996190028340) [staticcall]
    │   │   │   └─ ← [Return] 0x0000000000000000000000007c8999dc9a822c1f0df42023113edb4fdd543266
    │   │   ├─ emit Approval(owner: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, spender: TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], value: 100000000000000000000 [1e20])
    │   │   └─ ← [Stop] 
    │   ├─ [30885] YHBToken::transferFrom(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], 100000000000000000000 [1e20])
    │   │   ├─ emit Transfer(from: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, to: TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], value: 100000000000000000000 [1e20])
    │   │   └─ ← [Return] true
    │   ├─ emit Deposit(user: 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266, amount: 100000000000000000000 [1e20])
    │   └─ ← [Stop] 
    ├─ [651] YHBToken::balanceOf(TokenBank: [0x2e234DAe75C793f67A35089C9d99245E1C58470b]) [staticcall]
    │   └─ ← [Return] 100000000000000000000 [1e20]
    ├─ [0] VM::assertEq(100000000000000000000 [1e20], 100000000000000000000 [1e20]) [staticcall]
    │   └─ ← [Return] 
    ├─ [486] TokenBank::balances(0x7c8999dC9a822c1f0Df42023113EDB4FDd543266) [staticcall]
    │   └─ ← [Return] 100000000000000000000 [1e20]
    ├─ [0] VM::assertEq(100000000000000000000 [1e20], 100000000000000000000 [1e20]) [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 87.50ms (5.30ms CPU time)

Ran 1 test suite in 4.95s (87.50ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```



### 3. NFTMarketplace 合约

在 `NFTMarketplace` 合约中添加 `permitBuy` 功能，实现只有经过离线授权的白名单地址才能购买 NFT。

修改上面的NFTMarketplace.sol 合约，用YHBNFT作为名称，发行 NFT上架市场，添加功能`permitBuy()` 实现只有离线授权的白名单地址才可以购买 YHBNFT （） 。

白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 `permitBuy()` 函数，在`permitBuy()`中判断时候是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。

```
  function permitBuy(signature){
       // check  signer == owner // hash(...) == EIP712
       // erc20.trasnferFrom(...)

    }

    function permitBuy(signatureEIP712,signatureEIP2612){
       // check  signer == owner // hash(...) == EIP712
        
       erc20.permit(signatureEIP2612)
    }



onchain: list(nft,tokenId,price)

offchain:
    sell: EIP712(sellOrder(seller,nft,tokenId,price,deadline)) => signatureForSellOrder
 
// 买家可以直接买入NFT
; 在买入时，买家只需要拿到卖家订单的离线签名（由平台中心化管理 opensea）
buy(SellOrder order,signatureForSellOrder,signatureForApprove , signatureForWL){
    ; check signatureForWL
    require(getSigner(hashStruct(Message{msg.sender}),signatureForWL)==owner,"invalid signature");
    

    //check sell order is valid, EIP712
    bytes32 orderHash= hashStruct(order);
    require(getSigner(orderHash,signatureForSellOrder)== order.seller,"invalid signature");
    require(orders[orderHash]!="filled","order sold");
    //check
    orders[orderHash]="filled";

    ; token trasnfer
    address buyer=msg.sender;
    erc20.permit(buyer,address(this),order.price, signatureForApprove) // == approve
    erc20.trasnferFrom(buyer,order.seller,order.price); // 
    ; nft trasnfer
    nft.safeTrasnferFrom(order.seller,buyer,order.tokenId) 
}
```



#### `NFTMarketplace.sol`

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

interface IERC20Receiver {
    function onERC20Received(address operator, address from, uint256 value, bytes calldata data) external returns (bytes4);
}

contract YHBNFTMarketplace is ReentrancyGuard, Ownable, IERC20Receiver, EIP712 {
    using ECDSA for bytes32;

    struct Listing {
        uint256 price;
        address seller;
    }

    struct SellOrder {
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 deadline;
    }

    IERC20 public token;
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(bytes32 => bool) public orders;

    event NFTListed(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed buyer);
    event Deposit(address indexed user, uint256 amount);

    bytes32 private constant SELL_ORDER_TYPEHASH = keccak256("SellOrder(address nftContract,uint256 tokenId,uint256 price,address seller,uint256 deadline)");

    constructor(address _tokenAddress) EIP712("YHBNFTMarketplace", "1") Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
    }

    function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "Marketplace not approved");

        listings[nftContract][tokenId] = Listing(price, msg.sender);

        emit NFTListed(nftContract, tokenId, price, msg.sender);
    }

    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, listing.price, msg.sender);
    }

    function onERC20Received(address /*operator*/, address from, uint256 value, bytes calldata data) external override returns (bytes4) {
        require(msg.sender == address(token), "Only the specified ERC20 token can call this function");

        (address nftContract, uint256 tokenId) = abi.decode(data, (address, uint256));
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");
        require(value == listing.price, "Incorrect token amount");

        IERC721(nftContract).safeTransferFrom(listing.seller, from, tokenId);
        token.transfer(listing.seller, value);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, value, from);

        return this.onERC20Received.selector;
    }

    function permitDeposit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        ERC20Permit(address(token)).permit(owner, spender, value, deadline, v, r, s);
        token.transferFrom(owner, address(this), value);
        emit Deposit(owner, value);
    }

    function permitBuy(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signatureForWL,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove,
        address buyer
    ) external nonReentrant {
        // 验证白名单签名
        verifyWhitelistSignature(buyer, deadline, signatureForWL);
        
        // 检查订单并处理购买
        handlePurchase(nftContract, tokenId, price, deadline, signatureForSellOrder, signatureForApprove, buyer);
    }

    function verifyWhitelistSignature(address buyer, uint256 deadline, bytes calldata signatureForWL) internal view {
        bytes32 messageHash = keccak256(abi.encodePacked(buyer, deadline));
        bytes32 ethSignedMessageHash = _hashTypedDataV4(messageHash);
        require(getSigner(ethSignedMessageHash, signatureForWL) == owner(), "Invalid whitelist signature");
    }

    function handlePurchase(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove,
        address buyer
    ) internal {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price == price, "Incorrect price");
        
        bytes32 orderHash = _hashTypedDataV4(keccak256(abi.encode(
            SELL_ORDER_TYPEHASH,
            nftContract,
            tokenId,
            price,
            listing.seller,
            deadline
        )));
        require(getSigner(orderHash, signatureForSellOrder) == listing.seller, "Invalid sell order signature");
        require(!orders[orderHash], "Order already filled");

        orders[orderHash] = true;

        // 处理 ERC20 授权
        ERC20Permit(address(token)).permit(buyer, address(this), price, deadline, uint8(signatureForApprove[64]), bytes32(signatureForApprove), bytes32(signatureForApprove[32:64]));

        token.transferFrom(buyer, listing.seller, price);
        IERC721(nftContract).safeTransferFrom(listing.seller, buyer, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, price, buyer);
    }

    function getSigner(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
        return messageHash.recover(signature);
    }
}

```

## 

### NFT 购买测试用例

使用 Foundry 编写测试用例以验证 NFT 购买功能。

#### `YHBNFTMarketplaceTest.t.sol`

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "../src/YHBToken.sol";
import "../src/MockNFT.sol";
import "../src/NFTMarketplace.sol";

contract YHBNFTMarketplaceTest is Test {
    YHBToken token;
    MockNFT nft;
    YHBNFTMarketplace marketplace;

    address seller = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId = 1;
    uint256 price = 100 ether;

    function setUp() public {
        // 部署 ERC20 和 ERC721 代币
        token = new YHBToken();
        nft = new MockNFT("Mock NFT", "MNFT");

        // 部署市场合约
        marketplace = new YHBNFTMarketplace(address(token));

        // 将代币分配给卖家
        token.transfer(seller, 1000 ether);
        
        // 将代币分配给买家，确保买家有足够的代币
        token.transfer(buyer, 1000 ether); // 添加这一行
        
        // 将 NFT 发送给卖家并批准市场合约
        nft.mint(seller);
        
        // 使用 seller 的身份进行批准
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();
        
        // 卖家在市场上列出 NFT
        vm.startPrank(seller);
        marketplace.list(address(nft), tokenId, price);
        vm.stopPrank();
    }

    function testBuyNFT() public {
        vm.startPrank(buyer);
        token.approve(address(marketplace), price);
        marketplace.buyNFT(address(nft), tokenId); // 更改为 buyNFT
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), buyer);
    }
}

```

## 测试用例运行

使用以下命令运行测试用例，并查看运行日志：

```
forge test --match-contract YHBNFTMarketplaceTest -vvvv
```

输出结果为：

```
hb@yhbdeMacBook-Air my-project % forge test --match-contract YHBNFTMarketplaceTest -vvvv

[⠊] Compiling...
[⠘] Compiling 1 files with Solc 0.8.25
[⠃] Solc 0.8.25 finished in 1.79s
Compiler run successful!

Ran 1 test for test/YHBNFTMarketplaceTest.t.sol:YHBNFTMarketplaceTest
[PASS] testBuyNFT() (gas: 99604)
Traces:
  [103816] YHBNFTMarketplaceTest::testBuyNFT()
    ├─ [0] VM::startPrank(0x0000000000000000000000000000000000000002)
    │   └─ ← [Return] 
    ├─ [24762] YHBToken::approve(YHBNFTMarketplace: [0xF62849F9A0B5Bf2913b396098F7c7019b51A820a], 100000000000000000000 [1e20])
    │   ├─ emit Approval(owner: 0x0000000000000000000000000000000000000002, spender: YHBNFTMarketplace: [0xF62849F9A0B5Bf2913b396098F7c7019b51A820a], value: 100000000000000000000 [1e20])
    │   └─ ← [Return] true
    ├─ [81279] YHBNFTMarketplace::buyNFT(MockNFT: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], 1)
    │   ├─ [13785] YHBToken::transferFrom(0x0000000000000000000000000000000000000002, 0x0000000000000000000000000000000000000001, 100000000000000000000 [1e20])
    │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000002, to: 0x0000000000000000000000000000000000000001, value: 100000000000000000000 [1e20])
    │   │   └─ ← [Return] true
    │   ├─ [43558] MockNFT::safeTransferFrom(0x0000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000002, 1)
    │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000001, to: 0x0000000000000000000000000000000000000002, tokenId: 1)
    │   │   └─ ← [Stop] 
    │   ├─ emit NFTSold(nftContract: MockNFT: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], tokenId: 1, price: 100000000000000000000 [1e20], buyer: 0x0000000000000000000000000000000000000002)
    │   └─ ← [Stop] 
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return] 
    ├─ [620] MockNFT::ownerOf(1) [staticcall]
    │   └─ ← [Return] 0x0000000000000000000000000000000000000002
    ├─ [0] VM::assertEq(0x0000000000000000000000000000000000000002, 0x0000000000000000000000000000000000000002) [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 9.57ms (1.72ms CPU time)

Ran 1 test suite in 1.31s (9.57ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
yhb@yhbdeMacBook-Air my-project % 
```



## GitHub 项目链接

https://github.com/1131764933/openspace_web3_work/tree/dfc42e669af5e77411f6db0b933cb26788d61229