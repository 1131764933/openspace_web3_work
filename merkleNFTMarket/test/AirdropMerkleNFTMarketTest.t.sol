// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "../src/MyToken.sol";
import "../src/MyNFT.sol";
import "../src/Multicall.sol";

contract AirdropMerkleNFTMarketTest is Test {
    MyToken token;
    MyNFT nft;
    AirdropMerkleNFTMarket market;
    Multicall multicall;
    bytes32 merkleRoot;
    address owner;
    address buyer;
    bytes32[] merkleProof;

    function setUp() public {
        owner = address(this);
        buyer = address(0x123);
        token = new MyToken();
        nft = new MyNFT();
        merkleRoot = 0x8d67552713f05e9ee5f6ceb6e84ce829484b6050965d2318da37b52fd2a425f6; // replace with your actual merkle root
        market = new AirdropMerkleNFTMarket(IERC20(address(token)), IERC721(address(nft)), merkleRoot);
        multicall = new Multicall();
        
        // Mint NFT to market owner
        nft.mint(owner);

        // Set NFT price
        market.setPrice(0, 1000 * 10**18);

        // Approve tokens for buyer
        token.transfer(buyer, 1000 * 10**18);
        vm.prank(buyer);
        token.approve(address(market), 1000 * 10**18);
    }

    function testBuyWithPermit() public {
        // Construct permit signature
        uint256 deadline = block.timestamp + 3600;
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            keccak256(abi.encodePacked(token.DOMAIN_SEPARATOR(), keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                500 * 10**18,
                token.nonces(buyer),
                deadline
            ))))
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0, digest); // Sign with buyer's key

        // Prepare multicall data
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(market.permitPrePay.selector, buyer, 500 * 10**18, deadline, v, r, s);
        data[1] = abi.encodeWithSelector(market.claimNFT.selector, 0, merkleProof, buyer);

        // Execute multicall
        multicall.multicall(data);

        // Check NFT ownership
        assertEq(nft.ownerOf(0), buyer);
    }
}