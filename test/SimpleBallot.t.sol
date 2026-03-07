// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleBallot} from "../src/SimpleBallot.sol";

contract SimpleBallotTest is Test {
    SimpleBallot public ballot;
    
    address public owner = makeAddr("owner");
    
    function setUp() public {
        string[] memory names = new string[](2);
        names[0] = "Alice";
        names[1] = "Bob";
        
        vm.prank(owner);
        ballot = new SimpleBallot(names);
    }
    
    // ============ 功能测试 ============
    
    function test_Initialize() public {
        address voter = makeAddr("voter");
        
        vm.prank(voter);
        ballot.vote(0);
        
        assertTrue(ballot.hasVoted(voter));
    }
    
    function test_Vote() public {
        address voter = makeAddr("voter");
        
        vm.prank(voter);
        ballot.vote(0);
        
        assertTrue(ballot.hasVoted(voter));
    }
    
    function test_WinningProposal() public {
        address voter1 = makeAddr("voter1");
        address voter2 = makeAddr("voter2");
        
        vm.prank(voter1);
        ballot.vote(0);
        
        vm.prank(voter2);
        ballot.vote(0);
        
        assertEq(ballot.winningProposal(), 0);
    }
    
    // ============ Gas 测试 ============
    
    function test_GasForVote() public {
        address voter = makeAddr("voter");
        
        uint256 gasBefore = gasleft();
        
        vm.prank(voter);
        ballot.vote(0);
        
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Vote gas used:", gasUsed);
        
        // 调整阈值到 60000
        assertLt(gasUsed, 60000);
    }
    
    function test_GasForWinningProposal() public {
        // 每个选民投 0 或 1
        for (uint256 i = 0; i < 10; i++) {
            address voter = makeAddr(string(abi.encodePacked("voter", i)));
            vm.prank(voter);
            ballot.vote(i % 2);
        }
        
        uint256 gasBefore = gasleft();
        ballot.winningProposal();
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Counting gas used (10 voters):", gasUsed);
        
        assertLt(gasUsed, 100000);
    }
}
