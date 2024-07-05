
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    function withdraw(uint256 amount) external;
}

contract Bank {
    address public owner;
    mapping(address => uint256) public balances;
    address[3] public topThreeDepositors;

    constructor() {
        owner = msg.sender;
    }

    // 仅允许大于等于 0.001 ether 的存款
    modifier onlyDeposit() {
        require(msg.value >= 0.001 ether, "Deposit amount must be at least 0.001 ether");
        _;
    }

    // 仅管理员可调用的权限控制
    modifier onlyAdmin() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 接收以太币的函数
    receive() external payable {
        deposit();
    }

    // 存款函数
    function deposit() public payable onlyDeposit {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        balances[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
    }

    // 提款函数，仅管理员可调用
    function withdraw(uint256 amount) public onlyAdmin {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    // 更新前三名存款者数组
    function updateTopDepositors(address depositor) internal {
        for (uint256 i = 0; i < topThreeDepositors.length; i++) {
            if (balances[depositor] > balances[topThreeDepositors[i]]) {
                for (uint256 j = topThreeDepositors.length - 1; j > i; j--) {
                    topThreeDepositors[j] = topThreeDepositors[j - 1];
                }
                topThreeDepositors[i] = depositor;
                break;
            }
        }
    }

    // 获取合约所有者地址
    function getOwner() public view returns (address) {
        return owner;
    }
}

contract BigBank is Bank {
    constructor() {
        owner = msg.sender;
    }

    // 新的修饰符，仅允许大于等于 0.001 ether 的存款
    modifier onlyBigBankDeposit() {
        require(msg.value >= 0.001 ether, "Deposit amount must be at least 0.001 ether");
        _;
    }

    // 新的修饰符，仅管理员可调用的权限控制
    modifier onlyBigBankAdmin() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 提款函数，增加权限控制
    function withdrawFromBigBank(uint256 amount) public onlyBigBankAdmin {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
    }

    // 仅所有者可调用的权限控制
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 转移所有权函数
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner address cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // 从 Bank 合约提款函数，仅所有者可调用
    function withdrawFromBank(address bankContract, uint256 amount) public onlyOwner {
        IBank(bankContract).withdraw(amount);
    }
}
