// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Test.sol";
import "../src/NFTMarketplace.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract TestERC20 is ERC20 {
    constructor() ERC20("Test Token", "TST") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TestERC721 is ERC721 {
    constructor() ERC721("Test NFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    TestERC20 erc20;
    TestERC721 nft;

    address alice = address(0x123);
    address bob = address(0x456);

    function setUp() public {
        marketplace = new NFTMarketplace(address(erc20));
        erc20 = new TestERC20();
        nft = new TestERC721();

        // Mint some tokens and NFTs
        erc20.mint(alice, 10000 * 10 ** 18);
        nft.mint(alice, 1);

        // Approve the marketplace
        vm.prank(alice);
        nft.approve(address(marketplace), 1);
    }

    function testListNFTSuccess() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        (uint256 price, address seller) = marketplace.listings(address(nft), 1);
        assertEq(price, 1000 * 10 ** 18);
        assertEq(seller, alice);
    }

    function testListNFTFailureNotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert("You do not own this NFT");
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);
    }

    function testListNFTFailureNotApproved() public {
        vm.prank(alice);
        nft.approve(address(0), 1);

        vm.expectRevert("Marketplace not approved");
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);
    }

    function testBuyNFTSuccess() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        vm.prank(bob);
        erc20.mint(bob, 1000 * 10 ** 18);
        erc20.approve(address(marketplace), 1000 * 10 ** 18);
        marketplace.buyNFT(address(nft), 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function testBuyNFTSelf() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        vm.prank(alice);
        vm.expectRevert("NFT not listed for sale");
        marketplace.buyNFT(address(nft), 1);
    }

    function testBuyNFTAlreadySold() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        vm.prank(bob);
        erc20.mint(bob, 1000 * 10 ** 18);
        erc20.approve(address(marketplace), 1000 * 10 ** 18);
        marketplace.buyNFT(address(nft), 1);

        vm.prank(bob);
        vm.expectRevert("NFT not listed for sale");
        marketplace.buyNFT(address(nft), 1);
    }

    function testBuyNFTUnderpay() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        vm.prank(bob);
        erc20.mint(bob, 999 * 10 ** 18);
        erc20.approve(address(marketplace), 999 * 10 ** 18);

        vm.expectRevert("Insufficient payment");
        marketplace.buyNFT(address(nft), 1);
    }

    function testBuyNFTOverpay() public {
        vm.prank(alice);
        marketplace.list(address(nft), 1, 1000 * 10 ** 18);

        vm.prank(bob);
        erc20.mint(bob, 2000 * 10 ** 18);
        erc20.approve(address(marketplace), 2000 * 10 ** 18);
        marketplace.buyNFT(address(nft), 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function testFuzzListAndBuyNFT(uint256 price, address buyer) public {
        vm.assume(price > 0.01 * 10 ** 18 && price < 10000 * 10 ** 18);
        vm.assume(buyer != alice && buyer != address(0));

        vm.prank(alice);
        marketplace.list(address(nft), 1, price);

        vm.prank(buyer);
        erc20.mint(buyer, price);
        erc20.approve(address(marketplace), price);
        marketplace.buyNFT(address(nft), 1);

        assertEq(nft.ownerOf(1), buyer);
    }

    function testInvariantTokenBalance() public {
        // Invariant: NFTMarketplace should never hold any ERC20 tokens
        uint256 balance = erc20.balanceOf(address(marketplace));
        assertEq(balance, 0);
    }
}
