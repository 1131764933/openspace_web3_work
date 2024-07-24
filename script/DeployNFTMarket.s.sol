// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        address feeTo = 0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69; 
        address whiteListSigner = 0x65034a9364DF72534d98Acb96658450f9254ff59; 

        vm.startBroadcast();
        
        NFTMarket nftMarket = new NFTMarket();
        
        nftMarket.setFeeTo(feeTo);

        nftMarket.setWhiteListSigner(whiteListSigner);
        
        console.log("NFTMarket deployed to:", address(nftMarket));
        
        vm.stopBroadcast();
    }
}
