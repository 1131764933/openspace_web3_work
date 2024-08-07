// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarket {
    IERC20 public token;
    IERC721 public nft;
    address public owner;
    bytes32 public merkleRoot;
    mapping(uint256 => uint256) public nftPrices; // NFT ID to price

    constructor(IERC20 _token, IERC721 _nft, bytes32 _merkleRoot) {
        token = _token;
        nft = _nft;
        owner = msg.sender;
        merkleRoot = _merkleRoot;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setPrice(uint256 nftId, uint256 price) external onlyOwner {
        nftPrices[nftId] = price;
    }

    function permitPrePay(
        address holder,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(token)).permit(holder, address(this), value, deadline, v, r, s);
    }

    function claimNFT(
        uint256 nftId,
        bytes32[] calldata merkleProof,
        address buyer
    ) external {
        require(isWhitelisted(msg.sender, merkleProof), "Not whitelisted");
        uint256 price = nftPrices[nftId] / 2; // 50% discount
        require(token.transferFrom(buyer, owner, price), "Transfer failed");
        nft.safeTransferFrom(owner, buyer, nftId);
    }

    function isWhitelisted(address account, bytes32[] calldata merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}
