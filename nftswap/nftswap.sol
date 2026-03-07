// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTSwap is Ownable {
    constructor() Ownable(msg.sender) {
        // Initialize the contract with the deployer as the initial owner
    }
    struct Order {
        address owner; // NFT 的原始持有人
        uint256 price; // 出售价格
    }

    // mapping 记录每个 NFT 的订单
    mapping(address => mapping(uint256 => Order)) public orders;

    // 事件定义
    event List(address indexed nftAddr, uint256 indexed tokenId, uint price, address indexed owner);
    event Revoke(address indexed nftAddr, uint256 indexed tokenId, address indexed owner);
    event Update(address indexed nftAddr, uint256 indexed tokenId, uint newPrice, address indexed owner);
    event Purchase(address indexed nftAddr, uint256 indexed tokenId, uint price, address  buyer, address  seller);

    // 卖家挂单
    function list(address nftAddr, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        IERC721 nft = IERC721(nftAddr);

        require(nft.ownerOf(tokenId) == msg.sender, "You are not the owner of this NFT");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "Contract is not approved to transfer this NFT");
        require(orders[nftAddr][tokenId].owner == address(0), "Order already exists");

        // 将 NFT 从卖家转移到合约
        nft.transferFrom(msg.sender, address(this), tokenId);

        // 创建订单
        orders[nftAddr][tokenId] = Order({owner: msg.sender, price: price});
        emit List(nftAddr, tokenId, price, msg.sender);
    }

    // 卖家撤单
    function revoke(address nftAddr, uint256 tokenId) external {
        Order memory order = orders[nftAddr][tokenId];
        require(order.owner != address(0), "Order does not exist");
        require(order.owner == msg.sender, "Not the owner of the order");

        IERC721 nft = IERC721(nftAddr);

        // 将 NFT 退还给卖家
        nft.transferFrom(address(this), msg.sender, tokenId);

        // 删除订单
        delete orders[nftAddr][tokenId];
        emit Revoke(nftAddr, tokenId, msg.sender);
    }

    // 卖家更新价格
    function update(address nftAddr, uint256 tokenId, uint256 newPrice) external {
        Order storage order = orders[nftAddr][tokenId];
        require(order.owner == msg.sender, "Not the owner of the order");
        require(newPrice > 0, "New price must be greater than 0");

        // 更新价格
        order.price = newPrice;
        emit Update(nftAddr, tokenId, newPrice, msg.sender);
    }

    // 买家购买 NFT
    function buy(address nftAddr, uint256 tokenId) external payable {
        Order memory order = orders[nftAddr][tokenId];
        require(order.owner != address(0), "Order does not exist");
        require(msg.value == order.price, "Incorrect payment amount");

        IERC721 nft = IERC721(nftAddr);
        require(nft.ownerOf(tokenId) == address(this), "NFT is not held by contract");

        // 转移支付给卖家
        payable(order.owner).transfer(msg.value);

        // 将 NFT 转移给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        // 删除订单
        delete orders[nftAddr][tokenId];
        emit Purchase(nftAddr, tokenId, order.price, msg.sender, order.owner);
    }

    // 紧急取回 NFT (仅限合约拥有者)
    function emergencyWithdrawNFT(address nftAddr, uint256 tokenId) external onlyOwner {
        IERC721 nft = IERC721(nftAddr);
        address owner = nft.ownerOf(tokenId);

        // 如果合约拥有 NFT，则将其退还给合约拥有者
        if (owner == address(this)) {
            nft.safeTransferFrom(address(this), msg.sender, tokenId);
        }
    }
}