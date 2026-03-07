// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./InscribedERC20.sol";


contract Factory_V1 {
    event InscribedERC20Created(address tokenAddress);

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public returns (address) {
        InscribedERC20 token = new InscribedERC20(symbol, symbol, totalSupply, perMint);        
        token.transferOwnership(msg.sender);
        emit InscribedERC20Created(address(token));
        return address(token);
    }
    function mintInscription(address tokenAddr) public {
        InscribedERC20 token = InscribedERC20(tokenAddr);
        token.mintInscription(tokenAddr);
    }
}