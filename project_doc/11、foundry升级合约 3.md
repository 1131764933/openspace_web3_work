实现一个可升级的工厂合约并使用 Foundry 工具进行测试，可以按照以下步骤来进行。我们将创建两个版本的工厂合约，第一版用于普通的 ERC20 代币创建，第二版添加了价格参数并使用代理模式。以下是详细的实现步骤：

### 1. 设置 Foundry 项目

首先，确保你已经安装了 Foundry。如果没有，请按照 Foundry 的文档进行安装。

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 创建 Foundry 项目

创建一个新的 Foundry 项目：

```
forge init my-upgradable-factory
cd my-upgradable-factory
```

配置项目

```
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
```

末尾的`--no-commit`标志。这是因为你的项目文件夹已经与 git 存储库关联，所以我们必须指定不提交任何内容。

现在，让我们通过填写我们之前创建的**remappings.txt**文件来将导入配置到正确的路径。

向文件中添加以下配置：

```
@openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```

保存文件后，让我们打开**foundry.toml**文件，并向你的文件添加以下代码：

```
build_info = true
extra_output = ["storageLayout"]
[rpc_endpoints]
sepolia = "QUICKNODE_ENDPOINT_URL"
```

前两行（例如，`build_info`和`extra_output`）是在使用 OpenZeppelin Foundry Upgrades [library](https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades)（感谢 ericglau！）时所需的配置。此外，由于我们在本指南中在 Sepolia 测试网上部署，我们将把这个端点命名为`sepolia`。如果你在其他网络上部署，可以更改名称。**注意**，请记住将**QUICKNODE_ENDPOINT_URL**占位符替换为你之前创建的实际 QuickNode HTTP 提供程序 URL。

最后，让我们在环境中设置我们的私钥，使用以下变量名和你的私钥。在你的终端中运行以下命令，并将**YOUR_PRVATE_KEY**占位符更新为你的实际私钥。

```sh
export PRIVATE_KEY=YOUR_PRIVATE_KEY
```

### 3. 编写第一版合约

编写基础工厂合约BaseFactory.sol

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract BaseFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    function __BaseFactory_init(address initialOwner) internal initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public virtual returns (address);
    function mintInscription(address tokenAddr) public virtual payable;
}
```



#### `InscribedERC20.sol`

这是第一个版本的 ERC20 合约：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InscribedERC20 is ERC20, Ownable {
    uint256 public perMint;

    constructor(string memory name, string memory symbol, uint256 totalSupply, uint256 _perMint) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, totalSupply);
        perMint = _perMint;
    }

    function mintInscription(address to) public onlyOwner {
        _mint(to, perMint);
    }
}
```

#### `FactoryV1.sol`

这是第一个版本的工厂合约：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./BaseFactory.sol";
import "./InscribedERC20.sol";

contract FactoryV1 is BaseFactory {
    event InscribedERC20Created(address tokenAddress);

    function initialize(address initialOwner) public initializer {
        __BaseFactory_init(initialOwner);
    }

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public override returns (address) {
        InscribedERC20 token = new InscribedERC20(symbol, symbol, totalSupply, perMint);
        token.transferOwnership(msg.sender);
        emit InscribedERC20Created(address(token));
        return address(token);
    }

    function mintInscription(address tokenAddr) public payable override {
        require(msg.value == 0, "FactoryV1: minting is free");
        InscribedERC20(tokenAddr).mintInscription(msg.sender);
    }
}
```

### 4. 编写第二版合约

#### `InscribedERC20V2.sol`

这是第二个版本的 ERC20 合约：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract InscribedERC20V2 is ERC20Upgradeable, OwnableUpgradeable {
    uint256 public perMint;
    uint256 public price;

    function initialize(string memory name, string memory symbol, uint256 totalSupply, uint256 _perMint, uint256 _price, address initialOwner) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(initialOwner);
        _mint(initialOwner, totalSupply);
        perMint = _perMint;
        price = _price;
    }

    function mintInscription(address to) public payable {
        require(msg.value >= price * perMint / 1e18, "Insufficient payment");
        _mint(to, perMint);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
```

#### `FactoryV2.sol`

这是第二个版本的工厂合约：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./BaseFactory.sol";
import "./InscribedERC20V2.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract FactoryV2 is BaseFactory {
    event InscribedERC20Created(address tokenAddress);

    address public implementation;

    function initialize(address initialOwner) public initializer {
        __BaseFactory_init(initialOwner);
    }

    function setImplementation(address _implementation) public onlyOwner {
        implementation = _implementation;
    }

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public override returns (address) {
        return deployInscriptionWithPrice(symbol, totalSupply, perMint, 0);
    }

    function deployInscriptionWithPrice(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public returns (address) {
        require(implementation != address(0), "Implementation not set");
        address clone = Clones.clone(implementation);
        InscribedERC20V2(clone).initialize(symbol, symbol, totalSupply, perMint, price, msg.sender);
        emit InscribedERC20Created(clone);
        return clone;
    }

    function mintInscription(address tokenAddr) public payable override {
        InscribedERC20V2(tokenAddr).mintInscription{value: msg.value}(msg.sender);
    }
}
```

### 5. 编写测试用例

创建一个测试文件 `test/FactoryTest.t.sol`：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/FactoryV1.sol";
import "../src/FactoryV2.sol";
import "../src/InscribedERC20.sol";
import "../src/InscribedERC20V2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FactoryUpgradeTest is Test {
    FactoryV1 public factoryV1Implementation;
    FactoryV2 public factoryV2Implementation;
    ERC1967Proxy public proxy;
    InscribedERC20V2 public tokenImplementation;

    address public owner = address(1);
    address public user1 = address(2);

    function setUp() public {
        vm.startPrank(owner);
        factoryV1Implementation = new FactoryV1();
        factoryV2Implementation = new FactoryV2();
        tokenImplementation = new InscribedERC20V2();

        bytes memory initData = abi.encodeWithSelector(FactoryV1.initialize.selector, owner);
        proxy = new ERC1967Proxy(address(factoryV1Implementation), initData);

        vm.stopPrank();
    }

    function testUpgrade() public {
        FactoryV1 factoryV1 = FactoryV1(address(proxy));

        // Test V1 functionality
        vm.prank(user1);
        address tokenV1 = factoryV1.deployInscription("TEST", 1000000 * 1e18, 1000 * 1e18);
        InscribedERC20 token = InscribedERC20(tokenV1);
        assertEq(token.name(), "TEST");
        assertEq(token.totalSupply(), 1000000 * 1e18);
        assertEq(token.perMint(), 1000 * 1e18);

        // Upgrade to V2
        vm.prank(owner);
        FactoryV2(address(proxy)).upgradeToAndCall(
            address(factoryV2Implementation),
            abi.encodeWithSelector(FactoryV2.setImplementation.selector, address(tokenImplementation))
        );

        FactoryV2 factoryV2 = FactoryV2(address(proxy));

        // Test V2 functionality
        vm.prank(user1);
        address tokenV2 = factoryV2.deployInscriptionWithPrice("TEST2", 2000000 * 1e18, 2000 * 1e18, 0.1 ether);
        InscribedERC20V2 tokenV2Instance = InscribedERC20V2(tokenV2);
        assertEq(tokenV2Instance.name(), "TEST2");
        assertEq(tokenV2Instance.totalSupply(), 2000000 * 1e18);
        assertEq(tokenV2Instance.perMint(), 2000 * 1e18);
        assertEq(tokenV2Instance.price(), 0.1 ether);

        // Test minting with payment
        uint256 requiredPayment = tokenV2Instance.price() * tokenV2Instance.perMint() / 1e18;
        vm.deal(user1, requiredPayment);
        vm.prank(user1);
        factoryV2.mintInscription{value: requiredPayment}(tokenV2);

        // Check the balance after minting
        uint256 expectedBalance = tokenV2Instance.totalSupply();
        uint256 actualBalance = tokenV2Instance.balanceOf(user1);
        assertEq(actualBalance, expectedBalance, "User balance after minting is incorrect");
    }
}
```

### 6. 运行测试

运行测试以确保合约的正确性：

```
forge test -vvvv
```

输出结果为：

```
hb@yhbdeMacBook-Air my-upgradable-factory % forge test -vvvv
[⠒] Compiling...
[⠑] Compiling 1 files with Solc 0.8.25
[⠃] Solc 0.8.25 finished in 1.66s
Compiler run successful!

Ran 1 test for test/FactoryTest.t.sol:FactoryUpgradeTest
[PASS] testUpgrade() (gas: 963308)
Traces:
  [963308] FactoryUpgradeTest::testUpgrade()
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000002)
    │   └─ ← [Return] 
    ├─ [639452] ERC1967Proxy::deployInscription("TEST", 1000000000000000000000000 [1e24], 1000000000000000000000 [1e21])
    │   ├─ [634538] FactoryV1::deployInscription("TEST", 1000000000000000000000000 [1e24], 1000000000000000000000 [1e21]) [delegatecall]
    │   │   ├─ [596412] → new InscribedERC20@0xfE2f43e66C38ab1d9d3026300698fb2E4a39a6b6
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: ERC1967Proxy: [0x2c1DE3b4Dbb4aDebEbB5dcECAe825bE2a9fc6eb6])
    │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: ERC1967Proxy: [0x2c1DE3b4Dbb4aDebEbB5dcECAe825bE2a9fc6eb6], value: 1000000000000000000000000 [1e24])
    │   │   │   └─ ← [Return] 2287 bytes of code
    │   │   ├─ [2424] InscribedERC20::transferOwnership(0x0000000000000000000000000000000000000002)
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: ERC1967Proxy: [0x2c1DE3b4Dbb4aDebEbB5dcECAe825bE2a9fc6eb6], newOwner: 0x0000000000000000000000000000000000000002)
    │   │   │   └─ ← [Stop] 
    │   │   ├─ emit InscribedERC20Created(tokenAddress: InscribedERC20: [0xfE2f43e66C38ab1d9d3026300698fb2E4a39a6b6])
    │   │   └─ ← [Return] InscribedERC20: [0xfE2f43e66C38ab1d9d3026300698fb2E4a39a6b6]
    │   └─ ← [Return] InscribedERC20: [0xfE2f43e66C38ab1d9d3026300698fb2E4a39a6b6]
    ├─ [1201] InscribedERC20::name() [staticcall]
    │   └─ ← [Return] "TEST"
    ├─ [0] VM::assertEq("TEST", "TEST") [staticcall]
    │   └─ ← [Return] 
    ├─ [315] InscribedERC20::totalSupply() [staticcall]
    │   └─ ← [Return] 1000000000000000000000000 [1e24]
    ├─ [0] VM::assertEq(1000000000000000000000000 [1e24], 1000000000000000000000000 [1e24]) [staticcall]
    │   └─ ← [Return] 
    ├─ [363] InscribedERC20::perMint() [staticcall]
    │   └─ ← [Return] 1000000000000000000000 [1e21]
    ├─ [0] VM::assertEq(1000000000000000000000 [1e21], 1000000000000000000000 [1e21]) [staticcall]
    │   └─ ← [Return] 
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000001)
    │   └─ ← [Return] 
    ├─ [34919] ERC1967Proxy::upgradeToAndCall(FactoryV2: [0x535B3D7A252fa034Ed71F0C53ec0C6F784cB64E1], 0xd784d426000000000000000000000000c051134f56d56160e8c8ed9bb3c439c78ab27ccc)
    │   ├─ [34508] FactoryV1::upgradeToAndCall(FactoryV2: [0x535B3D7A252fa034Ed71F0C53ec0C6F784cB64E1], 0xd784d426000000000000000000000000c051134f56d56160e8c8ed9bb3c439c78ab27ccc) [delegatecall]
    │   │   ├─ [321] FactoryV2::proxiableUUID() [staticcall]
    │   │   │   └─ ← [Return] 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
    │   │   ├─ emit Upgraded(implementation: FactoryV2: [0x535B3D7A252fa034Ed71F0C53ec0C6F784cB64E1])
    │   │   ├─ [22734] FactoryV2::setImplementation(InscribedERC20V2: [0xc051134F56d56160E8c8ed9bB3c439c78AB27cCc]) [delegatecall]
    │   │   │   └─ ← [Stop] 
    │   │   └─ ← [Stop] 
    │   └─ ← [Return] 
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000002)
    │   └─ ← [Return] 
    ├─ [233017] ERC1967Proxy::deployInscriptionWithPrice("TEST2", 2000000000000000000000000 [2e24], 2000000000000000000000 [2e21], 100000000000000000 [1e17])
    │   ├─ [232597] FactoryV2::deployInscriptionWithPrice("TEST2", 2000000000000000000000000 [2e24], 2000000000000000000000 [2e21], 100000000000000000 [1e17]) [delegatecall]
    │   │   ├─ [9031] → new <unknown>@0x504093F088a762CFc487DD71263282b03DF0238e
    │   │   │   └─ ← [Return] 45 bytes of code
    │   │   ├─ [188127] 0x504093F088a762CFc487DD71263282b03DF0238e::initialize("TEST2", "TEST2", 2000000000000000000000000 [2e24], 2000000000000000000000 [2e21], 100000000000000000 [1e17], 0x0000000000000000000000000000000000000002)
    │   │   │   ├─ [185404] InscribedERC20V2::initialize("TEST2", "TEST2", 2000000000000000000000000 [2e24], 2000000000000000000000 [2e21], 100000000000000000 [1e17], 0x0000000000000000000000000000000000000002) [delegatecall]
    │   │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x0000000000000000000000000000000000000002)
    │   │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x0000000000000000000000000000000000000002, value: 2000000000000000000000000 [2e24])
    │   │   │   │   ├─ emit Initialized(version: 1)
    │   │   │   │   └─ ← [Stop] 
    │   │   │   └─ ← [Return] 
    │   │   ├─ emit InscribedERC20Created(tokenAddress: 0x504093F088a762CFc487DD71263282b03DF0238e)
    │   │   └─ ← [Return] 0x504093F088a762CFc487DD71263282b03DF0238e
    │   └─ ← [Return] 0x504093F088a762CFc487DD71263282b03DF0238e
    ├─ [1423] 0x504093F088a762CFc487DD71263282b03DF0238e::name() [staticcall]
    │   ├─ [1245] InscribedERC20V2::name() [delegatecall]
    │   │   └─ ← [Return] "TEST2"
    │   └─ ← [Return] "TEST2"
    ├─ [0] VM::assertEq("TEST2", "TEST2") [staticcall]
    │   └─ ← [Return] 
    ├─ [548] 0x504093F088a762CFc487DD71263282b03DF0238e::totalSupply() [staticcall]
    │   ├─ [382] InscribedERC20V2::totalSupply() [delegatecall]
    │   │   └─ ← [Return] 2000000000000000000000000 [2e24]
    │   └─ ← [Return] 2000000000000000000000000 [2e24]
    ├─ [0] VM::assertEq(2000000000000000000000000 [2e24], 2000000000000000000000000 [2e24]) [staticcall]
    │   └─ ← [Return] 
    ├─ [529] 0x504093F088a762CFc487DD71263282b03DF0238e::perMint() [staticcall]
    │   ├─ [363] InscribedERC20V2::perMint() [delegatecall]
    │   │   └─ ← [Return] 2000000000000000000000 [2e21]
    │   └─ ← [Return] 2000000000000000000000 [2e21]
    ├─ [0] VM::assertEq(2000000000000000000000 [2e21], 2000000000000000000000 [2e21]) [staticcall]
    │   └─ ← [Return] 
    ├─ [550] 0x504093F088a762CFc487DD71263282b03DF0238e::price() [staticcall]
    │   ├─ [384] InscribedERC20V2::price() [delegatecall]
    │   │   └─ ← [Return] 100000000000000000 [1e17]
    │   └─ ← [Return] 100000000000000000 [1e17]
    ├─ [0] VM::assertEq(100000000000000000 [1e17], 100000000000000000 [1e17]) [staticcall]
    │   └─ ← [Return] 
    ├─ [529] 0x504093F088a762CFc487DD71263282b03DF0238e::perMint() [staticcall]
    │   ├─ [363] InscribedERC20V2::perMint() [delegatecall]
    │   │   └─ ← [Return] 2000000000000000000000 [2e21]
    │   └─ ← [Return] 2000000000000000000000 [2e21]
    ├─ [550] 0x504093F088a762CFc487DD71263282b03DF0238e::price() [staticcall]
    │   ├─ [384] InscribedERC20V2::price() [delegatecall]
    │   │   └─ ← [Return] 100000000000000000 [1e17]
    │   └─ ← [Return] 100000000000000000 [1e17]
    ├─ [0] VM::deal(0x0000000000000000000000000000000000000002, 200000000000000000000 [2e20])
    │   └─ ← [Return] 
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000002)
    │   └─ ← [Return] 
    ├─ [11470] ERC1967Proxy::mintInscription{value: 200000000000000000000}(0x504093F088a762CFc487DD71263282b03DF0238e)
    │   ├─ [11080] FactoryV2::mintInscription{value: 200000000000000000000}(0x504093F088a762CFc487DD71263282b03DF0238e) [delegatecall]
    │   │   ├─ [3703] 0x504093F088a762CFc487DD71263282b03DF0238e::mintInscription{value: 200000000000000000000}(0x0000000000000000000000000000000000000002)
    │   │   │   ├─ [3534] InscribedERC20V2::mintInscription{value: 200000000000000000000}(0x0000000000000000000000000000000000000002) [delegatecall]
    │   │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x0000000000000000000000000000000000000002, value: 2000000000000000000000 [2e21])
    │   │   │   │   └─ ← [Stop] 
    │   │   │   └─ ← [Return] 
    │   │   └─ ← [Stop] 
    │   └─ ← [Return] 
    ├─ [548] 0x504093F088a762CFc487DD71263282b03DF0238e::totalSupply() [staticcall]
    │   ├─ [382] InscribedERC20V2::totalSupply() [delegatecall]
    │   │   └─ ← [Return] 2002000000000000000000000 [2.002e24]
    │   └─ ← [Return] 2002000000000000000000000 [2.002e24]
    ├─ [831] 0x504093F088a762CFc487DD71263282b03DF0238e::balanceOf(0x0000000000000000000000000000000000000002) [staticcall]
    │   ├─ [659] InscribedERC20V2::balanceOf(0x0000000000000000000000000000000000000002) [delegatecall]
    │   │   └─ ← [Return] 2002000000000000000000000 [2.002e24]
    │   └─ ← [Return] 2002000000000000000000000 [2.002e24]
    ├─ [0] VM::assertEq(2002000000000000000000000 [2.002e24], 2002000000000000000000000 [2.002e24], "User balance after minting is incorrect") [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 9.78ms (2.06ms CPU time)

Ran 2 tests for test/Counter.t.sol:CounterTest
[PASS] testFuzz_SetNumber(uint256) (runs: 256, μ: 30821, ~: 31288)
Traces:
  [31288] CounterTest::testFuzz_SetNumber(3392)
    ├─ [22290] Counter::setNumber(3392)
    │   └─ ← [Stop] 
    ├─ [283] Counter::number() [staticcall]
    │   └─ ← [Return] 3392
    ├─ [0] VM::assertEq(3392, 3392) [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

[PASS] test_Increment() (gas: 31303)
Traces:
  [31303] CounterTest::test_Increment()
    ├─ [22340] Counter::increment()
    │   └─ ← [Stop] 
    ├─ [283] Counter::number() [staticcall]
    │   └─ ← [Return] 1
    ├─ [0] VM::assertEq(1, 1) [staticcall]
    │   └─ ← [Return] 
    └─ ← [Stop] 

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 13.34ms (7.99ms CPU time)

Ran 2 test suites in 1.64s (23.12ms CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)
```



### 7. 部署合约

编写部署脚本 `script/Deploy.s.sol`确保你使用了正确的网络配置。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {FactoryV1} from "./FactoryV1.sol";
import {FactoryV2} from "./FactoryV2.sol";
import {InscribedERC20V2} from "./InscribedERC20V2.sol";

contract Deploy is Script {
    function run() external {
        address initialOwner = msg.sender; // 设置初始拥有者为执行脚本的地址

        vm.startBroadcast(); // 开始广播交易

        // 部署 FactoryV1
        FactoryV1 factoryV1 = new FactoryV1();
        factoryV1.initialize(initialOwner);
        console.log("FactoryV1 deployed at:", address(factoryV1));

        // 部署 InscribedERC20V2 合约实现
        InscribedERC20V2 inscribedERC20V2 = new InscribedERC20V2();
        console.log("InscribedERC20V2 deployed at:", address(inscribedERC20V2));

        // 部署 FactoryV2
        FactoryV2 factoryV2 = new FactoryV2();
        factoryV2.initialize(initialOwner);
        factoryV2.setImplementation(address(inscribedERC20V2));
        console.log("FactoryV2 deployed at:", address(factoryV2));

        vm.stopBroadcast(); // 停止广播交易
    }
}

```

执行部署命令

```
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```



### 8. 开源到区块链浏览器

将合约源码提交到 Etherscan 或其他区块链浏览器，并在 GitHub 的 README.md 文件中记录合约地址和代理地址。

### 9. 更新 README.md

在你的 GitHub 仓库的 README.md 文件中，添加部署地址和其他相关信息。

```
# Upgradable Factory Contracts

## Contracts

- FactoryV1: [0x...](https://etherscan.io/address/0x...)
- FactoryV2: [0x...](https://etherscan.io/address/0x...)
- ProxyAdmin: [0x...](https://etherscan.io/address/0x...)
- Implementation: [0x...](https://etherscan.io/address/0x...)
- Proxy: [0x...](https://etherscan.io/address/0x...)

## Usage

### Deploy Inscription (V1)
```

await factoryV1.deployInscription("TOKEN", 1000 * 10 ** 18, 10 * 10 ** 18);

```
### Mint Inscription (V1)
```

await factoryV1.mintInscription(tokenAddr);

```
### Deploy Inscription (V2)
```

await factoryV2.deployInscription("TOKEN", 1000 * 10 ** 18, 10 * 10 ** 18, 0.01 ether);

```
### Mint Inscription (V2)
```

await factoryV2.mintInscription(tokenAddr, { value: 0.01 ether });

```

```

通过以上步骤，你可以创建一个可升级的工厂合约，支持两种版本的代币部署和铸造功能，并能够在升级后保持合约状态的一致性。
