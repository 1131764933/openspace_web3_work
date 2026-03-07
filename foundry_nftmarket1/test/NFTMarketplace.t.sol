// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract NFT is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract Token is ERC20 {
    constructor() ERC20("TestToken", "TT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    NFT nft;
    Token token;
    address user1 = address(0x1);
    address user2 = address(0x2);

    event NFTListed(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed buyer);

    function setUp() public {
        token = new Token();
        marketplace = new NFTMarketplace(address(token));
        nft = new NFT();

        nft.mint(user1, 1);
        nft.mint(user1, 2);

        token.mint(user2, 1000 * 10 ** token.decimals());
    }

    // 测试上架成功
    function testListNFTSuccess() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(nft), 1, 100 * 10 ** token.decimals(), user1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        (uint256 price, address seller) = marketplace.listings(address(nft), 1);
        assertEq(price, 100 * 10 ** token.decimals());
        assertEq(seller, user1);
        vm.stopPrank();
    }

    //测试上架失败

    // 测试上架失败：上架者不是 NFT 的拥有者
    function testListNFTFailNotOwner() public {
        uint256 d=token.decimals();
        vm.startPrank(user2); // user2 不是 NFT 的拥有者
        nft.setApprovalForAll(address(marketplace), true);
        vm.expectRevert("You do not own this NFT");
        marketplace.list(address(nft), 1, 100 * 10 **d );
        vm.stopPrank();
    }

    // 测试上架失败：上架者没有批准市场合约
    function testListNFTFailNotApproved() public {
        uint256 d=token.decimals();
        vm.startPrank(user1);
        // 不设置 Approval
        vm.expectRevert("Marketplace not approved");
        marketplace.list(address(nft), 1, 100 * 10 **d);
        vm.stopPrank();
    }

    // // // 测试上架失败：尝试上架不存在的 NFT
    // function testListNFTFailNonexistentToken() public {
    //     uint256 d=token.decimals();
    //     vm.startPrank(user1);
    //     nft.setApprovalForAll(address(marketplace), true);
    //     vm.expectRevert("ERC721NonexistentToken(3)");
    //     marketplace.list(address(nft), 3, 100 * 10 **d); // Token ID 3 不存在
    //     vm.stopPrank();
    //     vm.startPrank(user1);
    //     nft.setApprovalForAll(address(marketplace), true);
    //     vm.expectRevert("ERC721: owner query for nonexistent token");
    //     marketplace.list(address(nft), 3, 100 * 10 **d); // Token ID 3 不存在
    //     vm.stopPrank();
    // }



    // 测试购买成功
    function testBuyNFTSuccess() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(marketplace), 100 * 10 ** token.decimals());
        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(nft), 1, 100 * 10 ** token.decimals(), user2);
        marketplace.buyNFT(address(nft), 1);
        assertEq(nft.ownerOf(1), user2);
        vm.stopPrank();
    }

    // 测试自己购买自己的NFT
    function testBuyNFTFailSelfPurchase() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        token.approve(address(marketplace), 100 * 10 ** token.decimals());
        vm.expectRevert("Cannot buy your own NFT");
        marketplace.buyNFT(address(nft), 1);
        vm.stopPrank();
    }

    // 测试NFT被重复购买
    function testBuyNFTFailDoublePurchase() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(marketplace), 100 * 10 ** token.decimals());
        marketplace.buyNFT(address(nft), 1);
        vm.expectRevert("NFT not listed for sale");
        marketplace.buyNFT(address(nft), 1);
        vm.stopPrank();
    }

    // 测试支付Token过多
    function testBuyNFTFailOverpayment() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(marketplace), 200 * 10 ** token.decimals());
        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(nft), 1, 100 * 10 ** token.decimals(), user2);
        marketplace.buyNFT(address(nft), 1);
        assertEq(nft.ownerOf(1), user2);
        vm.stopPrank();
    }

    // 测试支付Token过少
    function testBuyNFTFailUnderpayment() public {
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, 100 * 10 ** token.decimals());
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(marketplace), 50 * 10 ** token.decimals());
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        marketplace.buyNFT(address(nft), 1);
        vm.stopPrank();
    }

    // 测试随机价格上架NFT
    function testFuzzListing(uint256 price) public {
        vm.assume(price > 0.01 ether && price < 10000 ether);
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, price);
        (uint256 listedPrice, address seller) = marketplace.listings(address(nft), 1);
        assertEq(listedPrice, price);
        assertEq(seller, user1);
        vm.stopPrank();
    }

    // 测试随机Address购买NFT
    function testFuzzBuying(address buyer) public {
        uint256 price = 100 * 10 ** token.decimals();
        vm.assume(buyer != address(0) && buyer != user1 && buyer !=user2);
        vm.startPrank(user1);
        nft.approve(address(marketplace), 1);
        marketplace.list(address(nft), 1, price);
        vm.stopPrank();

    }

    // 测试不可变性，确保合约中没有持有任何Token
    function testInvariantTokenBalance() public view{
        uint256 balance = token.balanceOf(address(marketplace));
        assertEq(balance, 0);
    }
}
