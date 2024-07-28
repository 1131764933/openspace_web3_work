// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract InscribedERC20V2 is ERC20, Ownable, Initializable {
    uint256 public perMint;
    uint256 public price;

    constructor() ERC20("","") Ownable(msg.sender){}

    function initialize(string memory name, string memory symbol, uint256 totalSupply, uint256 _perMint, uint256 _price, address owner) public initializer {
        _mint(owner, totalSupply);
        perMint = _perMint;
        price = _price;
        _transferOwnership(owner);
    }

    function mintInscription(address to) public payable {
        require(msg.value >= price, "Insufficient funds");
        _mint(to, perMint);
    }
}