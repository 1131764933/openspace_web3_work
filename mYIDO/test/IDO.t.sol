// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/IDO.sol";
import "../src/RNTToken.sol";

contract IDOTest is Test {
    RNTToken token;
    IDO ido;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = vm.addr(1);
        user2 = vm.addr(2);

        // 部署 RNTToken 合约
        token = new RNTToken();
        uint256 presaleStart = block.timestamp + 1 days;
        uint256 presaleEnd = block.timestamp + 7 days;
        uint256 presalePrice = 0.0001 ether;
        uint256 tokensForSale = 1000000 * 10**18;
        uint256 presaleTarget = 100 ether;
        uint256 presaleCap = 200 ether;

        // 部署 IDO 合约
        ido = new IDO(
            address(token),
            presaleStart,
            presaleEnd,
            presalePrice,
            tokensForSale,
            presaleTarget,
            presaleCap,
            owner
        );

        // 授权 IDO 合约
        token.approve(address(ido), tokensForSale);
    }

    function testPresale() public {
        // 设置当前区块时间为 presaleStart 之后
        vm.warp(ido.presaleStart() + 1);

        // 用户1参与预售
        vm.deal(user1, 0.05 ether);
        vm.startPrank(user1);
        ido.presale{value: 0.05 ether}();
        vm.stopPrank();

        // 确认用户1的贡献
        assertEq(ido.contributions(user1), 0.05 ether);
        assertEq(ido.totalRaised(), 0.05 ether);
    }

    // function testClaimTokens() public {
    //     // 设置当前区块时间为 presaleStart 之后
    //     vm.warp(ido.presaleStart() + 1);

    //     // 用户1参与预售
    //     vm.deal(user1, 0.05 ether);
    //     vm.startPrank(user1);
    //     ido.presale{value: 0.05 ether}();
    //     vm.stopPrank();

    //     // 设置当前区块时间为 presaleEnd 之后
    //     vm.warp(ido.presaleEnd() + 1);
        
    //     // 设置预售成功
    //     vm.deal(owner, 100 ether);
    //     payable(owner).transfer(100 ether);

    //     // 用户1提取代币
    //     vm.startPrank(user1);
    //     ido.claimTokens();
    //     vm.stopPrank();

    //     // 确认用户1的代币余额
    //     uint256 expectedTokens = 0.05 ether * 10**18 / ido.presalePrice();
    //     assertEq(token.balanceOf(user1), expectedTokens);
    // }

    function testRefund() public {
        // 设置当前区块时间为 presaleStart 之后
        vm.warp(ido.presaleStart() + 1);

        // 用户1参与预售
        vm.deal(user1, 0.05 ether);
        vm.startPrank(user1);
        ido.presale{value: 0.05 ether}();
        vm.stopPrank();

        // 设置当前区块时间为 presaleEnd 之后
        vm.warp(ido.presaleEnd() + 1);

        // 用户1申请退款
        vm.startPrank(user1);
        ido.refund();
        vm.stopPrank();

        // 确认用户1的退款
        assertEq(ido.contributions(user1), 0);
        assertEq(user1.balance, 0.05 ether);
    }

    // function testWithdrawFunds() public {
    //     // 设置当前区块时间为 presaleStart 之后
    //     vm.warp(ido.presaleStart() + 1);

    //     // 用户1参与预售
    //     vm.deal(user1, 0.05 ether);
    //     vm.startPrank(user1);
    //     ido.presale{value: 0.05 ether}();
    //     vm.stopPrank();

    //     // 设置当前区块时间为 presaleEnd 之后
    //     vm.warp(ido.presaleEnd() + 1);

    //     // 设置预售成功
    //     vm.deal(owner, 100 ether);
    //     payable(owner).transfer(100 ether);

    //     // 项目方提取募集的ETH
    //     uint256 ownerInitialBalance = owner.balance;
    //     vm.prank(owner);
    //     ido.withdrawFunds();
    //     uint256 ownerFinalBalance = owner.balance;

    //     // 确认项目方提取的ETH
    //     assertEq(ownerFinalBalance, ownerInitialBalance + 0.05 ether);
    // }
}