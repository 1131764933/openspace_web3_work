// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InscriptionToken.sol";

contract InscriptionFactoryV1 {
    event InscriptionDeployed(address indexed tokenAddress);

    function deployInscription(string memory name, string memory symbol, uint totalSupply, uint perMint) public returns (address) {
        // 使用无参数构造函数来初始化 InscriptionToken
        InscriptionToken token = new InscriptionToken();
        token.initialize(name, symbol, totalSupply, perMint);
        emit InscriptionDeployed(address(token));
        return address(token);
    }

    function mintInscription(address tokenAddr) public {
        InscriptionToken(tokenAddr).mint();
    }
}
