// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/RNTToken.sol";

contract DeployRNTToken is Script {
    function run() external {
        vm.startBroadcast();

        // 部署合约
        RNTToken token = new RNTToken();

        vm.stopBroadcast();
    }
}
