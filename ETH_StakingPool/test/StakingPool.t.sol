// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/StakingPool.sol";
import "../src/MockKKToken.sol";


contract StakingPoolTest is Test {
    StakingPool stakingPool;
    // StakingPool private stakingPool;
    MockKKToken private kkToken;

    address private alice = address(0x1);
    address private bob = address(0x2);
    address private nftSeller = address(0x3);

    function setUp() public {
        kkToken = new MockKKToken();
        stakingPool = new StakingPool(kkToken);

        // Allocate ETH to test addresses
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(nftSeller, 10 ether);
    }

    function testStake() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();

        assertEq(stakingPool.balanceOf(alice), 1 ether);
    }

    function testUnstake() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        // Verify the initial balance
        assertEq(stakingPool.balanceOf(alice), 1 ether);

        stakingPool.unstake(0.5 ether); // Partially unstake
        assertEq(stakingPool.balanceOf(alice), 0.5 ether);

        stakingPool.unstake(0.5 ether); // Unstake the remaining amount
        assertEq(stakingPool.balanceOf(alice), 0);

        // Verify that the unstaked ETH is returned to Alice
        assertEq(alice.balance, 10 ether); // Initial balance + 1 ether unstaked
    }



    function testClaim() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();

        // Move forward by 10 blocks to generate rewards
        vm.roll(block.number + 10);

        stakingPool.claim();
        vm.stopPrank();

        uint256 expectedRewards = 10 * 10; // 10 blocks * 10 KK per block
        assertEq(kkToken.balanceOf(alice), expectedRewards);
    }

    function testNFTPurchaseWithFee() public {
        uint256 initialBalance = address(this).balance; // Initial balance of the test contract
        uint256 nftPrice = 1 ether; // Set NFT price

        // Fetch the transaction fee rate from the contract
        uint256 transactionFeeRate = stakingPool.transactionFeeRate();
        
        // Calculate the expected total cost (NFT price + fee)
        uint256 expectedTotalCost = nftPrice + (nftPrice * transactionFeeRate) / 10000;

        // Ensure the contract has enough ETH to perform the test
        payable(address(stakingPool)).transfer(expectedTotalCost);

        // Call the buyNFT function and ensure the transaction does not revert
        stakingPool.buyNFT{value: expectedTotalCost}(address(this), nftPrice);

        // Assert that the balance after purchase is correct
        assertEq(address(this).balance, initialBalance - expectedTotalCost, "Balance should match expected after purchase");
    }


    function testMultipleStakersDistribution() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bob);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();

        // Move forward by 10 blocks
        vm.roll(block.number + 10);

        vm.startPrank(alice);
        stakingPool.claim();
        vm.stopPrank();

        vm.startPrank(bob);
        stakingPool.claim();
        vm.stopPrank();

        uint256 totalRewards = 10 * 10; // 10 blocks * 10 KK per block
        uint256 aliceExpectedRewards = (totalRewards * 1 ether) / 3 ether;
        uint256 bobExpectedRewards = (totalRewards * 2 ether) / 3 ether;

        assertEq(kkToken.balanceOf(alice), aliceExpectedRewards);
        assertEq(kkToken.balanceOf(bob), bobExpectedRewards);
    }
}
