// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract InscriptionToken is ERC20, Initializable {
    uint public perMint;

    string private _customName;
    string private _customSymbol;

    constructor() ERC20("", "") {}

    function initialize(string memory customName, string memory customSymbol, uint totalSupply, uint _perMint) initializer public {
        _customName = customName;
        _customSymbol = customSymbol;

        _mint(msg.sender, totalSupply);
        perMint = _perMint;
    }

    function name() public view override returns (string memory) {
        return _customName;
    }

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }

    function mint() external {
        _mint(msg.sender, perMint);
    }
}
