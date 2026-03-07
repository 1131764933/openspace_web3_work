// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InscribedERC20 is ERC20, Ownable {
    uint256 public perMint;
    constructor(string memory name, string memory symbol, uint256 totalSupply, uint256 _perMint) ERC20(name, symbol)Ownable(msg.sender){
        _mint(msg.sender, totalSupply);
        perMint = _perMint;
    }
    function mintInscription(address to) public onlyOwner {
        _mint(to, perMint);
    }
}