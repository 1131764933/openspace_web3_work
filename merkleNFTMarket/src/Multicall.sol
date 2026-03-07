
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract Multicall {
    function multicall(bytes[] calldata data) external {
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Multicall: delegatecall failed");
        }
    }
}