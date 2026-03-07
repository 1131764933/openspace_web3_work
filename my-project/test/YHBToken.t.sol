// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "src/YHBToken.sol";

contract YHBToken_Test is Test {
    YHBToken public token;
    address public owner;
    address public user1;
 
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        
        // Initialize the YHBToken contract
        token = new YHBToken();
    }

    function testInitialSupply() public {
        // Check if the initial supply is correct
        uint256 expectedSupply = 1000000 * 10 ** token.decimals();
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(owner), expectedSupply);
    }

    function testTransfer() public {
        // Test transferring tokens
        uint256 amount = 100 * 10 ** token.decimals();

        // Transfer tokens from owner to user1
        token.transfer(user1, amount);

        // Check balances after transfer
        assertEq(token.balanceOf(owner), 1000000 * 10 ** token.decimals() - amount);
        assertEq(token.balanceOf(user1), amount);
    }
}
