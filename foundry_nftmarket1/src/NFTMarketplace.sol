// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable, IERC721Receiver {
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

    // function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
    //     IERC721 nft = IERC721(nftContract);
    //     require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
    //     require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "Marketplace not approved");

    //     listings[nftContract][tokenId] = Listing(price, msg.sender);

    //     emit NFTListed(nftContract, tokenId, price, msg.sender);
    // }
    function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        IERC721 nft = IERC721(nftContract);
            // Check if token exists
        try nft.ownerOf(tokenId) returns (address owner) {
            require(owner == msg.sender, "You do not own this NFT");
        } catch {
            revert("ERC721: owner query for nonexistent token");
        }
        // require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "Marketplace not approved");

        listings[nftContract][tokenId] = Listing(price, msg.sender);

        emit NFTListed(nftContract, tokenId, price, msg.sender);
    }


    function buyNFT(address nftContract, uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");
        require(token.allowance(msg.sender, address(this)) >= listing.price, "ERC20: transfer amount exceeds allowance");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, listing.price, msg.sender);
    }

    // Implementing the IERC721Receiver interface
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // Override supportsInterface to support IERC721Receiver
    function supportsInterface(bytes4 interfaceId) external pure  returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId;
    }
}
