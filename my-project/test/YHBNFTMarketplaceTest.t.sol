// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "../src/YHBToken.sol";
import "../src/MockNFT.sol";
import "../src/NFTMarketplace.sol";

contract YHBNFTMarketplaceTest is Test {
    YHBToken token;
    MockNFT nft;
    YHBNFTMarketplace marketplace;

    address seller = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId = 1;
    uint256 price = 100 ether;

    function setUp() public {
        // 部署 ERC20 和 ERC721 代币
        token = new YHBToken();
        nft = new MockNFT("Mock NFT", "MNFT");

        // 部署市场合约
        marketplace = new YHBNFTMarketplace(address(token));

        // 将代币分配给卖家
        token.transfer(seller, 1000 ether);
        
        // 将代币分配给买家，确保买家有足够的代币
        token.transfer(buyer, 1000 ether); // 添加这一行
        
        // 将 NFT 发送给卖家并批准市场合约
        nft.mint(seller);
        
        // 使用 seller 的身份进行批准
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();
        
        // 卖家在市场上列出 NFT
        vm.startPrank(seller);
        marketplace.list(address(nft), tokenId, price);
        vm.stopPrank();
    }

    function testBuyNFT() public {
        vm.startPrank(buyer);
        token.approve(address(marketplace), price);
        marketplace.buyNFT(address(nft), tokenId); // 更改为 buyNFT
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), buyer);
    }
}
