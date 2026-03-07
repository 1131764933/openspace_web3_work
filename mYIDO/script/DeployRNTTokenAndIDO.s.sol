// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/RNTToken.sol";
import "../src/IDO.sol";

contract DeployRNTTokenAndIDO is Script {
    function run() external {
        // 获取部署者的私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 RNTToken 合约
        RNTToken rntToken = new RNTToken();
        
        // 部署 IDO 合约，传递 RNTToken 合约地址和初始所有者地址
        IDO ido = new IDO(
            address(rntToken),
            block.timestamp,  // presaleStart
            block.timestamp + 30 days,  // presaleEnd
            1e16,  // presalePrice, 0.01 ether per token
            1000000 * 10 ** rntToken.decimals(),  // tokensForSale
            100 ether,  // presaleTarget
            200 ether,  // presaleCap
            msg.sender  // initialOwner
        );
        
        // 将 100 万 RNT 代币转移到 IDO 合约地址
        rntToken.transfer(address(ido), 1000000 * 10 ** rntToken.decimals());
        
        // 停止广播交易
        vm.stopBroadcast();
    }
}
