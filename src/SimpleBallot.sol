// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

contract SimpleBallot {
    // ============ 错误定义 ============
    error AlreadyVoted();
    error InvalidProposal();
    error NoProposals();
    
    // ============ 状态变量 ============
    Proposal[] public proposals;
    mapping(address => bool) public hasVoted;
    
    // ============ 结构体 ============
    struct Proposal {
        string name;
        uint256 voteCount;
    }
    
    // ============ 事件 ============
    event Voted(address voter, uint256 proposal);
    
    // ============ 构造函数 ============
    constructor(string[] memory proposalNames) {
        uint256 length = proposalNames.length;
        require(length > 0, "No proposals");
        
        for (uint256 i = 0; i < length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }
    
    // ============ 投票函数 ============
    function vote(uint256 proposalIndex) external {
        if (hasVoted[msg.sender]) revert AlreadyVoted();
        if (proposalIndex >= proposals.length) revert InvalidProposal();
        
        hasVoted[msg.sender] = true;
        proposals[proposalIndex].voteCount += 1;
        
        emit Voted(msg.sender, proposalIndex);
    }
    
    // ============ 计票函数 ============
    function winningProposal() external view returns (uint256) {
        uint256 length = proposals.length;
        if (length == 0) revert NoProposals();
        
        uint256 winningVoteCount = 0;
        uint256 winningIndex = 0;
        
        for (uint256 i = 0; i < length; i++) {
            uint256 count = proposals[i].voteCount;
            if (count > winningVoteCount) {
                winningVoteCount = count;
                winningIndex = i;
            }
        }
        
        return winningIndex;
    }
}
