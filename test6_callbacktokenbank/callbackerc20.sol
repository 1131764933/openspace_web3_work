// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.2/contracts/token/ERC777/ERC777.sol"; // 使用特定版本的路径

contract CallbackERC20 is ERC777 {

    constructor() ERC777("CallbackERC20", "CERC20", new address[](0)) {
        _mint(msg.sender, 1000 * 10 ** 18, "", "");
    }
}
