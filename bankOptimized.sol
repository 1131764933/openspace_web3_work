// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    struct Node {
        address user;
        uint256 amount;
        address next;
    }

    mapping(address => uint256) public balances; // 每个地址的存款金额
    mapping(address => Node) public topDepositors; // 存储前十名的用户和其存款信息

    address public head; // 链表头部
    uint256 public topCount; // 当前前十名用户数量
    uint256 public minTopAmount; // 前十名中最小的存款金额

    address constant GUARD = address(1); // 链表的哨兵节点

    constructor() {
        head = GUARD;
        topDepositors[GUARD] = Node(address(0), 0, GUARD);
    }

    receive() external payable {
        deposit(msg.sender, msg.value);
    }

    function deposit(address depositor, uint256 amount) internal {
        balances[depositor] += amount;

        // 更新链表，如果新的存款金额可以进入前十
        if (topCount < 10) {
            _insert(depositor, balances[depositor]);
            topCount++;
        } else if (balances[depositor] > minTopAmount) {
            _remove(minTopAmount); // 移除最小的存款者
            _insert(depositor, balances[depositor]);
        }

        // 更新最小存款金额
        minTopAmount = topDepositors[topDepositors[GUARD].next].amount;
    }

    function _insert(address user, uint256 amount) internal {
        // 找到插入位置
        address prev = GUARD;
        address curr = topDepositors[GUARD].next;

        while (curr != GUARD && topDepositors[curr].amount > amount) {
            prev = curr;
            curr = topDepositors[curr].next;
        }

        // 插入新节点
        topDepositors[user] = Node(user, amount, curr);
        topDepositors[prev].next = user;
    }

    function _remove(uint256 amount) internal {
        address prev = GUARD;
        address curr = topDepositors[GUARD].next;

        while (curr != GUARD && topDepositors[curr].amount != amount) {
            prev = curr;
            curr = topDepositors[curr].next;
        }

        if (curr != GUARD) {
            topDepositors[prev].next = topDepositors[curr].next;
            delete topDepositors[curr];
        }
    }

    function getTopDepositors() public view returns (address[] memory) {
        address[] memory result = new address[](topCount);
        address current = topDepositors[GUARD].next;

        for (uint256 i = 0; i < topCount; i++) {
            result[i] = current;
            current = topDepositors[current].next;
        }

        return result;
    }
}
