// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyNFT.sol";
import "../src/AirdropMerkleNFTMarket.sol";

contract DeployAirdropMerkleNFTMarket is Script {
    function run() external {
        vm.startBroadcast();

        // 读取 merkleRoot.txt 文件
        // string memory rootFile = "merkleRoot.txt";
        // string memory root = vm.readFile(rootFile);
        // bytes32 merkleRoot = bytes32(abi.decode(bytes(root), (bytes32)));
        // 硬编码 merkleRoot
        bytes32 merkleRoot = 0x8d67552713f05e9ee5f6ceb6e84ce829484b6050965d2318da37b52fd2a425f6; // 替换为你的实际 merkleRoot
        // Instantiate token and NFT without constructor arguments
        IERC20 token = new MyToken();
        IERC721 nft = new MyNFT();

        // 部署 AirdropMerkleNFTMarket 合约
        AirdropMerkleNFTMarket market = new AirdropMerkleNFTMarket(token, nft, merkleRoot);

        console.log("AirdropMerkleNFTMarket deployed to:", address(market));

        vm.stopBroadcast();
    }
}
