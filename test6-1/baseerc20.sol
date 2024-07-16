// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.2/contracts/utils/Address.sol";

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external;
}

contract BaseERC20 {
    using Address for address;  // 引入Address库

    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 
    mapping (address => mapping (address => uint256)) allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000 * (10 ** uint256(decimals));      
        balances[msg.sender] = totalSupply;  
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _internalTransfer(msg.sender, _to, _value, abi.encodePacked());
        return true;
    }

    function transferWithCallback(address _to, uint256 _value, bytes calldata _data) public returns (bool success) {
        _internalTransfer(msg.sender, _to, _value, _data);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0));
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(balances[_to] + _value >= balances[_to]); // Overflow check

        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        _executeTokensReceivedCallback(_from, _to, _value, abi.encodePacked());
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0));
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {     
        return allowances[_owner][_spender];
    }

    function _internalTransfer(address _from, address _to, uint256 _value, bytes memory _data) internal {
        require(_to != address(0));
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(balances[_to] + _value >= balances[_to]); // Overflow check

        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
        _executeTokensReceivedCallback(_from, _to, _value, _data);
    }

    function _executeTokensReceivedCallback(address _from, address _to, uint256 _value, bytes memory _data) internal {
        if (_to.isContract()) {
            ITokenReceiver(_to).tokensReceived(_from, _value, _data);
        }
    }
}

