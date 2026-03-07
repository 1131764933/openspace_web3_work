// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/erc20.sol";

contract DeployMyToken is Script {
    function run() external {
        vm.startBroadcast();
        
        // 部署合约，填写你的 token 名称和符号
        new MyToken("MyTokenName", "MTK");
        
        vm.stopBroadcast();
    }
}
