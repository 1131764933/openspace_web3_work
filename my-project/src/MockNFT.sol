// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        nextTokenId = 1; // 初始化下一个 tokenId
    }

    function mint(address to) public onlyOwner {
        _mint(to, nextTokenId);
        nextTokenId++;
    }
}
