// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Ballot} from "../src/ballot.sol";

contract BallotTest is Test {
    Ballot public ballot;
    
    address public chairperson = makeAddr("chairperson");
    
    function setUp() public {
        bytes32[] memory proposalNames = new bytes32[](2);
        proposalNames[0] = bytes32("Alice");
        proposalNames[1] = bytes32("Bob");
        
        vm.prank(chairperson);
        ballot = new Ballot(proposalNames, 10);
    }
    
    // 测试初始化
    function test_Initialize() public view {
        // chairperson 应该是部署者
        assertEq(ballot.chairperson(), chairperson);
    }
        // 测试主席可以授权投票权
    function test_GiveRightToVote() public {
        address voter = makeAddr("voter1");
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        // 验证 voter 可以投票（如果权重正确）
        vm.prank(voter);
        ballot.vote(0);
        
        // 如果能执行到这里，说明授权成功
        assertTrue(true);
    }
    
    // 测试非主席不能授权
    function test_RevertIf_NonChairperson() public {
        address voter = makeAddr("voter1");
        
        vm.prank(voter);  // 假装是普通人
        vm.expectRevert("Only chairperson can give right to vote.");
        ballot.giveRightToVote(voter);
    }
        // 测试投票
    function test_Vote() public {
        address voter = makeAddr("voter1");
        
        // 主席授权
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        // 投票
        vm.prank(voter);
        ballot.vote(0);
        
        // 验证投票成功（不再revert即成功）
        assertTrue(true);
    }
    
    // 测试不能重复投票
    function test_RevertIf_AlreadyVoted() public {
        address voter = makeAddr("voter1");
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        // 第一次投票
        vm.prank(voter);
        ballot.vote(0);
        
        // 第二次投票应该失败
        vm.prank(voter);
        vm.expectRevert("Already voted.");
        ballot.vote(1);
    }
    // 测试委托投票
    function test_Delegate() public {
        address voter1 = makeAddr("voter1");
        address voter2 = makeAddr("voter2");
        
        // 主席授权两个选民
        vm.prank(chairperson);
        ballot.giveRightToVote(voter1);
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter2);
        
        // voter1 委托给 voter2
        vm.prank(voter1);
        ballot.delegate(voter2);
        
        // voter2 投票
        vm.prank(voter2);
        ballot.vote(0);
        
        // 如果能执行到这里，说明委托成功
        assertTrue(true);
    }
    
    // 测试不能自我委托
    function test_RevertIf_SelfDelegation() public {
        address voter = makeAddr("voter1");
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        vm.prank(voter);
        vm.expectRevert("Self-delegation is not allowed.");
        ballot.delegate(voter);
    }
    // 测试获胜提案
    function test_WinningProposal() public {
        address voter1 = makeAddr("voter1");
        address voter2 = makeAddr("voter2");
        
        // 授权
        vm.prank(chairperson);
        ballot.giveRightToVote(voter1);
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter2);
        
        // 投票
        vm.prank(voter1);
        ballot.vote(0);  // Alice
        
        vm.prank(voter2);
        ballot.vote(0);  // Alice
        
        // 验证获胜提案是 0
        assertEq(ballot.winningProposal(), 0);
    }
    
    // 测试设置权重
    function test_SetVoterWeight() public {
        address voter = makeAddr("voter1");
        
        // 主席设置权重
        vm.prank(chairperson);
        ballot.setVoterWeight(voter, 5);
        
        // 投票
        vm.prank(voter);
        ballot.vote(0);
        
        // 成功即说明权重设置成功
        assertTrue(true);
    }
    // 测试没有投票权不能投票
    function test_RevertIf_NoRightToVote() public {
        address voter = makeAddr("voter1");
        
        // 不授权，直接投票
        vm.prank(voter);
        vm.expectRevert("Has no right to vote.");
        ballot.vote(0);
    }
    
    // 测试无效提案
    function test_RevertIf_InvalidProposal() public {
        address voter = makeAddr("voter1");
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        // 投票给不存在的提案
        vm.prank(voter);
        vm.expectRevert("Invalid proposal.");
        ballot.vote(99);
    }
    
    // 测试投票时间限制 - 投票还没开始
    function test_RevertIf_VotingNotStarted() public {
        address voter = makeAddr("voter1");
        
        vm.prank(chairperson);
        ballot.giveRightToVote(voter);
        
        // 时间回滚到投票开始之前
        vm.warp(ballot.startTime() - 1);
        
        vm.prank(voter);
        vm.expectRevert("Voting has not started yet.");
        ballot.vote(0);
    }


}
