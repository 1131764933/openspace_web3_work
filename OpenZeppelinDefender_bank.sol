// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    address public owner;
    uint256 public depositThreshold;

    event Deposit(address indexed depositor, uint256 amount);
    event TransferToOwner(uint256 amount);

    constructor(uint256 _depositThreshold) {
        owner = msg.sender;
        depositThreshold = _depositThreshold;
    }

    // 用户存款
    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);

        // 检查存款是否超过阈值，如果是，调用 _transferToOwner()
        if (address(this).balance >= depositThreshold) {
            _transferToOwner();
        }
    }

    // 内部函数，用于将一半的存款转移到 owner
    function _transferToOwner() internal {
        uint256 transferAmount = address(this).balance / 2;
        (bool success, ) = owner.call{value: transferAmount}("");
        require(success, "Transfer failed");

        emit TransferToOwner(transferAmount);
    }

    // 设置新的存款阈值
    function setDepositThreshold(uint256 _newThreshold) external {
        require(msg.sender == owner, "Only owner can set threshold");
        depositThreshold = _newThreshold;
    }
}