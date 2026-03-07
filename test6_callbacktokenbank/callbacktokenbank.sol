
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/utils/introspection/ERC1820Implementer.sol";

contract TokenBank is IERC777Recipient, ERC1820Implementer {
    IERC777 public token;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    IERC1820Registry private _erc1820 = IERC1820Registry(
        0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24
    );
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    constructor(address _tokenAddress) {
        token = IERC777(_tokenAddress);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function tokensReceived(
        address /* operator */,
        address from,
        address /* to */,
        uint256 amount,
        bytes calldata /* userData */,
        bytes calldata /* operatorData */
    ) external override {
        require(msg.sender == address(token), "TokenBank: Invalid token");
        balances[from] += amount;
        emit Deposit(from, amount);
    }

    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        token.send(msg.sender, _amount, "");
        emit Withdraw(msg.sender, _amount);
    }
}

