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