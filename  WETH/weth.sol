// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WETH is ERC20, Ownable {
    // 构造函数，初始化 WETH 的名称和符号
    constructor() ERC20("Wrapped Ether", "WETH")Ownable(msg.sender) {}

    // 存款函数，接收 ETH 并铸造等量的 WETH
    function deposit() external payable {
        require(msg.value > 0, "Must deposit non-zero amount");
        _mint(msg.sender, msg.value); // 按照 1:1 的比例铸造 WETH
    }

    // 提取函数，销毁 WETH 并提取等量的 ETH
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient WETH balance"); // 确认余额足够
        _burn(msg.sender, amount); // 销毁等量的 WETH
        payable(msg.sender).transfer(amount); // 返还对应的 ETH
    }

    // 合约接收 ETH 的回退函数
    receive() external payable {
        require(msg.value > 0, "Must send ETH");
        _mint(msg.sender, msg.value); // 直接铸造 WETH 而不是调用 deposit()
    }

    // 允许合约拥有者提取合约中可能存在的多余 ETH （例如非正常操作的遗留）
    function emergencyWithdrawETH() external onlyOwner {
        require(address(this).balance > 0, "No ETH balance to withdraw");
        payable(owner()).transfer(address(this).balance);
    }
}