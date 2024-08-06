// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract SimpleMultisigWallet {
    address[] public owners;
    uint public requiredConfirmations;

    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public confirmations;

    Transaction[] public transactions;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed executor, uint indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1;
        confirmations[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex) public txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= requiredConfirmations, "Cannot execute transaction");

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }
}