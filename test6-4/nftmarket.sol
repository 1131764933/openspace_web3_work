// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    struct Listing {
        uint256 price;
        address seller;
    }

    IERC20 public token;
    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed seller);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, uint256 price, address indexed buyer);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
    }

    function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "Marketplace not approved");

        listings[nftContract][tokenId] = Listing(price, msg.sender);

        emit NFTListed(nftContract, tokenId, price, msg.sender);
    }

    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, listing.price, msg.sender);
    }
}

