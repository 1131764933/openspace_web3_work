// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface IStaking {
    function stake() payable external;
    function unstake(uint256 amount) external; 
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}

contract StakingPool is IStaking {
    IToken public kkToken;
    uint256 public rewardRate = 10; // 每个区块产出的 KK Token
    uint256 public totalStaked;
    uint256 public totalRewardPerToken;
    uint256 public transactionFeeRate = 100; // 1% 的交易手续费

    struct StakerInfo {
        uint256 balance;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
    }

    mapping(address => StakerInfo) public stakers;
    address[] public stakerList; // 新增的数组来跟踪所有质押者
    mapping(address => uint256) public transactionFeeBalance;

    uint256 public lastUpdateBlock;

    constructor(IToken _kkToken) {
        kkToken = _kkToken;
        lastUpdateBlock = block.number;
    }

    modifier updateReward(address account) {
        totalRewardPerToken = rewardPerToken();
        lastUpdateBlock = block.number;
        
        if (account != address(0)) {
            stakers[account].rewards = earned(account);
            stakers[account].rewardPerTokenPaid = totalRewardPerToken;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return totalRewardPerToken;
        }
        return totalRewardPerToken + ((block.number - lastUpdateBlock) * rewardRate * 1e18 / totalStaked);
    }

    function stake() payable external updateReward(msg.sender) {
        require(msg.value > 0, "Cannot stake 0");

        if (stakers[msg.sender].balance == 0) {
            stakerList.push(msg.sender); // 如果是新的质押者，添加到数组
        }

        stakers[msg.sender].balance += msg.value;
        totalStaked += msg.value;
    }

    function unstake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot unstake 0");
        require(stakers[msg.sender].balance >= amount, "Insufficient balance to unstake");

        stakers[msg.sender].balance -= amount;
        totalStaked -= amount;

        // 在移除质押者之前，确保其余额为零
        if (stakers[msg.sender].balance == 0) {
            removeStaker(msg.sender); 
        }

        // 使用安全的 transfer 操作避免 gas 问题
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }


    function claim() external updateReward(msg.sender) {
        uint256 reward = stakers[msg.sender].rewards;
        if (reward > 0) {
            stakers[msg.sender].rewards = 0;
            kkToken.mint(msg.sender, reward);
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return stakers[account].balance;
    }

    function earned(address account) public view returns (uint256) {
        return ((stakers[account].balance * (rewardPerToken() - stakers[account].rewardPerTokenPaid)) / 1e18) + stakers[account].rewards;
    }

    function buyNFT(address buyer, uint256 nftPrice) external payable updateReward(buyer) {
        uint256 fee = (nftPrice * transactionFeeRate) / 10000; // 计算 1% 的手续费

        // 将交易费用累计到每个质押用户的交易费用余额中
        if (totalStaked > 0) {
            transactionFeeBalance[buyer] += fee;
        }

        // 买家支付 NFT 的价格加上手续费
        require(msg.value >= nftPrice + fee, "Insufficient ETH for NFT purchase");

        // 发送费用给卖家，实际发送逻辑根据市场合约实现
        // payable(nftSeller).transfer(nftPrice);

        // 结算质押用户的交易费用
        distributeTransactionFees();
    }



    function distributeTransactionFees() internal {
        uint256 totalFees = 0;
        for (uint256 i = 0; i < stakerList.length; i++) {
            address staker = stakerList[i];
            uint256 stakeAmount = stakers[staker].balance;
            uint256 feeShare = (stakeAmount * transactionFeeBalance[staker]) / totalStaked;
            transactionFeeBalance[staker] = 0;
            totalFees += feeShare;
        }
        
        if (totalFees > 0) {
            for (uint256 i = 0; i < stakerList.length; i++) {
                address staker = stakerList[i];
                uint256 stakeAmount = stakers[staker].balance;
                uint256 feeShare = (stakeAmount * totalFees) / totalStaked;
                stakers[staker].rewards += feeShare;
            }
        }
    }


    function removeStaker(address staker) internal {
        for (uint256 i = 0; i < stakerList.length; i++) {
            if (stakerList[i] == staker) {
                stakerList[i] = stakerList[stakerList.length - 1];
                stakerList.pop();
                break;
            }
        }
    }
}
