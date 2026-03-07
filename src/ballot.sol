// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

contract Ballot {
    // 投票人结构体
    struct Voter {
        uint weight;        // 投票权重
        bool voted;         // 是否已投票
        address delegate;   // 委托给其他人投票的地址
        uint vote;          // 投给哪个提案的索引
    }

    // 提案结构体
    struct Proposal {
        bytes32 name;       // 提案的名称
        uint voteCount;     // 获得的投票总数
    }

    // 合约所有者，即投票的主席
    address public chairperson;

    // 保存每个地址对应的选民信息
    mapping(address => Voter) public voters;

    // 所有提案的数组
    Proposal[] public proposals;

    // 投票的开始和结束时间
    uint public startTime;
    uint public endTime;

    // 构造函数：初始化提案并设置投票时间窗口
    constructor(bytes32[] memory proposalNames, uint votingPeriodInMinutes) {
        chairperson = msg.sender;  // 合约的创建者为主席
        voters[chairperson].weight = 1;  // 主席的初始投票权重为1

        // 设置开始和结束时间
        startTime = block.timestamp;  // 当前区块时间为投票开始时间
        endTime = block.timestamp + votingPeriodInMinutes * 1 minutes;  // 结束时间为开始时间后若干分钟

        // 初始化每个提案
        for (uint i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i], 
                voteCount: 0
            }));
        }
    }

    // 给某个选民赋予投票权
    function giveRightToVote(address voter) public {
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "Already voted."
        );
        require(
            voters[voter].weight == 0,
            "Already has right to vote."
        );

        voters[voter].weight = 1;
    }

    // 允许主席为某个选民设置特定的投票权重
    function setVoterWeight(address voter, uint weight) public {
        require(msg.sender == chairperson, "Only chairperson can set voter weight.");
        require(!voters[voter].voted, "Voter has already voted.");
        require(weight > 0, "Weight must be greater than 0.");
        
        voters[voter].weight = weight;  // 设置选民的投票权重
    }

    // 将投票权委托给其他人
    function delegate(address to) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "Already voted.");
        require(to != msg.sender, "Self-delegation is not allowed.");

        // 循环查找最终的委托目标，防止环形委托
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // 防止环形委托
            require(to != msg.sender, "Found loop in delegation.");
        }

        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // 如果委托对象已经投票，则直接增加其投票的提案的票数
            proposals[delegate_.vote].voteCount += sender.weight; 
        } else {
            // 如果委托对象还没投票，则增加其投票权重
            delegate_.weight += sender.weight;
        }
    }

    // 投票给特定的提案
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "Already voted.");
        require(sender.weight != 0, "Has no right to vote.");
        require(proposal < proposals.length, "Invalid proposal.");
        
        // 确保投票时间在有效范围内
        require(block.timestamp >= startTime, "Voting has not started yet.");
        require(block.timestamp <= endTime, "Voting has ended.");

        sender.voted = true;
        sender.vote = proposal;

        // 统计投票权重
        proposals[proposal].voteCount += sender.weight;
    }

    // 获取当前票数最多的提案
    function winningProposal() public view returns (uint winningProposal_) {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // 返回获胜提案的名称
    function winnerName() public view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;    
    }

}