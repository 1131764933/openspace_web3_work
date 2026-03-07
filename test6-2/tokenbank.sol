// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.2/contracts/utils/Address.sol";


interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external;
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenBank is ITokenReceiver {
    using Address for address;

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

    // 实现ITokenReceiver接口中的tokensReceived方法
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override {
        require(msg.sender == address(token), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");
        balances[from] += amount;

        // 触发存款事件
        emit Deposit(from, amount);
    }
}

