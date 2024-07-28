// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./InscribedERC20V2.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract FactoryV2 {
    address public implementation;
    event InscribedERC20Created(address tokenAddress);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public returns (address) {
        address clone = Clones.clone(implementation);
        InscribedERC20V2(clone).initialize(symbol, symbol, totalSupply, perMint, price, msg.sender);
        emit InscribedERC20Created(clone);
        return clone;
    }

    function mintInscription(address tokenAddr) public payable {
        InscribedERC20V2(tokenAddr).mintInscription{value: msg.value}(msg.sender);
    }
}