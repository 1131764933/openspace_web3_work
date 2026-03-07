// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./InscriptionToken.sol";

contract InscriptionFactoryV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using Clones for address;

    address public implementation;
    uint public mintingPrice;

    event InscriptionDeployed(address indexed tokenAddress);

    function initialize(address _implementation) initializer public {
        __Ownable_init(msg.sender);
        implementation = _implementation;
        mintingPrice = 0.01 ether; // 初始铸造费用
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deployInscription(string memory symbol, uint totalSupply, uint perMint) public onlyOwner returns (address) {
        address clone = implementation.clone();
        InscriptionToken(clone).initialize(symbol, symbol, totalSupply, perMint);
        emit InscriptionDeployed(clone);
        return clone;
    }

    function mintInscription(address tokenAddr) public payable {
        require(msg.value >= mintingPrice, "Insufficient payment for minting");
        InscriptionToken(tokenAddr).mint();
    }

    function setMintingPrice(uint newPrice) external onlyOwner {
        mintingPrice = newPrice;
    }
}
