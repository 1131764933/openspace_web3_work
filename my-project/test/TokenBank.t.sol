// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "../src/TokenBank.sol";
import "../src/YHBToken.sol";

contract TokenBankTest is Test {
    TokenBank public bank;
    YHBToken public token;
    address public owner;
    address public user1;
    uint256 private ownerPrivateKey;

    function setUp() public {
        ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
        owner = vm.addr(ownerPrivateKey);
        user1 = address(0x1);

        // 部署ERC20合约
        token = new YHBToken();
        
        // 部署TokenBank合约
        bank = new TokenBank(address(token));

        // 给测试合约的地址分配一些token
        token.mint(owner, 1000 * 10 ** token.decimals());
    }

    function testDeposit() public {
        uint256 amount = 100 * 10 ** token.decimals();

        // 先授权给TokenBank合约
        vm.prank(owner);
        token.approve(address(bank), amount);

        // 调用TokenBank的deposit函数
        vm.prank(owner);
        bank.deposit(amount);

        // 检查TokenBank合约的余额和用户的存款
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(bank.balances(owner), amount);
    }

    function testPermitDeposit() public {
        uint256 amount = 100 * 10 ** token.decimals();
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.getDomainSeparator(),
                keccak256(abi.encode(
                    token.getPermitTypehash(),
                    owner,
                    address(bank),
                    amount,
                    nonce,
                    deadline
                ))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);

        // 调用TokenBank的permitDeposit函数
        vm.prank(owner);
        bank.permitDeposit(owner, amount, deadline, v, r, s);

        // 检查TokenBank合约的余额和用户的存款
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(bank.balances(owner), amount);
    }
}
