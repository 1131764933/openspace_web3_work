// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/forge-std/src/Script.sol";
import "../src/YHBToken.sol";

contract DeployYHBToken is Script {
    function run() external {
        vm.startBroadcast();

        YHBToken token = new YHBToken();

        vm.stopBroadcast();
    }
}
