
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Bank {
    address public owner;
    mapping(address => uint256) public balances;
    address[3] public topThreeDepositors;

    constructor() {
        owner = msg.sender;
    }

    // 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
    receive() external payable {
        // deposit();
    }

    // 存款函数：存入以太币到合约账户
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");

        balances[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
    }

    // 提取资金函数：仅管理员可以调用该方法提取合约中的资金
    function withdraw(uint256 amount) public {
        require(msg.sender == owner, "Only owner can withdraw funds");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(msg.sender).transfer(amount);
    }

    // 更新存款前三名用户数组
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
