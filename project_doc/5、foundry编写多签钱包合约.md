使用 Foundry 部署和测试多签钱包合约，我们需要设置一个 Foundry 项目，编写合约代码，编写测试用例，并运行测试。以下是详细的步骤和代码示例。

### 1. 设置 Foundry 项目

首先，确保你已安装 Foundry。如果没有安装，可以通过以下命令安装：

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

安装完成后，创建一个新的 Foundry 项目：

```
forge init multisig-wallet
cd multisig-wallet
```

### 2. 编写合约代码

在 `src` 目录下创建一个名为 `SimpleMultisigWallet.sol` 的文件，并添加以下代码：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract SimpleMultisigWallet {
    address[] public owners;
    uint public requiredConfirmations;

    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public confirmations;

    Transaction[] public transactions;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed executor, uint indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1;
        confirmations[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex) public txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= requiredConfirmations, "Cannot execute transaction");

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }
}
```

### 3. 编写测试代码

在 `test` 目录下创建一个名为 `SimpleMultisigWallet.t.sol` 的文件，并添加以下测试代码：

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/SimpleMultisigWallet.sol";

contract SimpleMultisigWalletTest is Test {
    SimpleMultisigWallet wallet;
    address[] owners;
    address owner1;
    address owner2;
    address owner3;

    function setUp() public {
        owner1 = address(0x1);
        owner2 = address(0x2);
        owner3 = address(0x3);

        owners = new address ;
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new SimpleMultisigWallet(owners, 2);
    }

    function testSubmitTransaction() public {
        // 使用owner1提交交易
        vm.prank(owner1);
        wallet.submitTransaction(address(0x4), 100, "");

        (address to, uint value,, bool executed, uint confirmations) = wallet.transactions(0);
        assertEq(to, address(0x4));
        assertEq(value, 100);
        assertFalse(executed);
        assertEq(confirmations, 0);
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0x4), 100, "");

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        (, , , , uint confirmations) = wallet.transactions(0);
        assertEq(confirmations, 1);
    }

    function testExecuteTransaction() public {
        vm.deal(address(wallet), 1000); // 为合约分配1000 wei

        vm.prank(owner1);
        wallet.submitTransaction(address(0x4), 100, "");

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner3);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        (,, bool executed,,) = wallet.transactions(0);
        assertTrue(executed);
    }

    function testExecuteTransactionWithInsufficientConfirmations() public {
        vm.deal(address(wallet), 1000); // 为合约分配1000 wei

        vm.prank(owner1);
        wallet.submitTransaction(address(0x4), 100, "");

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.expectRevert("Cannot execute transaction");
        vm.prank(owner1);
        wallet.executeTransaction(0);
    }
}
```

### 4. 运行测试

在终端中运行以下命令来测试合约：

```
bash
复制代码
forge test
```

这将执行测试用例并显示测试结果。

### 文档

#### 多签钱包合约

- **构造函数**：初始化合约时，指定持有者和所需的确认门槛。
- **提交交易**：持有者可以提交交易提案。
- **确认交易**：持有者可以确认交易提案。
- **执行交易**：当提案获得足够的确认后，任何人都可以执行该交易。

#### 测试用例

1. **提交交易**：
   - 验证交易提案是否正确存储。
2. **确认交易**：
   - 验证持有者确认提案后，确认数是否增加。
3. **执行交易**：
   - 在获得足够确认后执行交易。
   - 验证交易状态。
4. **不足确认执行交易**：
   - 验证在确认数不足时无法执行交易。

### 小结

通过 Foundry 部署和测试多签钱包合约，可以确保合约的功能符合预期。可以根据实际需要扩展合约功能，例如添加更多安全措施或优化代码。
