// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDO is Ownable {
    IERC20 public token;
    uint256 public presaleStart;
    uint256 public presaleEnd;
    uint256 public presalePrice; // 代币价格（以 wei 为单位）
    uint256 public tokensForSale;
    uint256 public totalRaised;
    uint256 public totalTokensSold;
    uint256 public presaleTarget; // 预售目标
    uint256 public presaleCap; // 超募上限
    bool public end;

    uint256 public minContribution = 0.01 ether; // 单笔最低买入0.01ETH
    uint256 public maxContribution = 0.1 ether; // 单个地址最高买入0.1ETH

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensClaimed;

    event Presale(address indexed buyer, uint256 amount);
    event TokensClaimed(address indexed claimer, uint256 amount);
    event Refund(address indexed refunder, uint256 amount);

    constructor(
        address tokenAddress,
        uint256 _presaleStart,
        uint256 _presaleEnd,
        uint256 _presalePrice,
        uint256 _tokensForSale,
        uint256 _presaleTarget,
        uint256 _presaleCap,
        address initialOwner  // 添加初始所有者地址参数
    ) Ownable(initialOwner) {  // 调用 Ownable 构造函数
        require(_presaleStart < _presaleEnd, "Start time must be before end time");
        require(_presaleTarget <= _presaleCap, "Target must be less than or equal to cap");

        token = IERC20(tokenAddress);
        presaleStart = _presaleStart;
        presaleEnd = _presaleEnd;
        presalePrice = _presalePrice;
        tokensForSale = _tokensForSale;
        presaleTarget = _presaleTarget;
        presaleCap = _presaleCap;
    }

    modifier onlyActive() {
        require(!end && totalRaised + msg.value <= presaleCap, "Presale is not active or cap reached");
        _;
    }

    modifier onlyFailed() {
        require(block.timestamp > presaleEnd && totalRaised < presaleTarget, "Presale not failed");
        _;
    }

    modifier onlySuccess() {
        require(block.timestamp > presaleEnd && totalRaised >= presaleTarget, "Presale not successful");
        _;
    }

    function presale() external payable onlyActive {
        require(block.timestamp >= presaleStart && block.timestamp <= presaleEnd, "Presale not active");
        require(msg.value >= minContribution, "Contribution below minimum limit");
        require(contributions[msg.sender] + msg.value <= maxContribution, "Contribution exceeds maximum limit");

        uint256 tokensToBuy = msg.value * 10**18 / presalePrice;
        require(totalTokensSold + tokensToBuy <= tokensForSale, "Not enough tokens for sale");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        totalTokensSold += tokensToBuy;

        emit Presale(msg.sender, tokensToBuy);
    }

    function claimTokens() external onlySuccess {
        uint256 tokensToClaim = contributions[msg.sender] * 10**18 / presalePrice;
        require(tokensToClaim > 0, "No tokens to claim");
        require(tokensClaimed[msg.sender] == 0, "Tokens already claimed");

        tokensClaimed[msg.sender] = tokensToClaim;
        token.transfer(msg.sender, tokensToClaim);

        emit TokensClaimed(msg.sender, tokensToClaim);
    }

    function withdrawFunds() external onlyOwner onlySuccess {
        payable(owner()).transfer(address(this).balance);
    }

    function estimateAmount(uint256 ethAmount) external view returns (uint256) {
        return ethAmount * 10**18 / presalePrice;
    }

    function refund() external onlyFailed {
        uint256 contribution = contributions[msg.sender];
        require(contribution > 0, "No contribution to refund");
        require(tokensClaimed[msg.sender] == 0, "Tokens already claimed");

        contributions[msg.sender] = 0;
        totalRaised -= contribution;
        totalTokensSold -= contribution * 10**18 / presalePrice;

        payable(msg.sender).transfer(contribution);

        emit Refund(msg.sender, contribution);
    }

    function endPresale() external onlyOwner {
        require(block.timestamp > presaleEnd, "Presale not ended");
        end = true;
    }
}
