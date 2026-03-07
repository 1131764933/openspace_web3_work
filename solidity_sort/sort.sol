// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Sort {
    function bubbleSort(uint[] memory arr) public pure returns (uint[] memory) {
        uint n = arr.length;
        for (uint i = 1; i < n; i++) {
            uint key = arr[i];
            uint j = i - 1;
            while (j >= 0 && arr[j] > key) {
                arr[j + 1] = arr[j];
                if (j == 0) break;
                j--;
            }
            arr[j + 1] = key;
        }
        return arr;
    }

    function sortArray() external pure returns (uint[] memory) {
        uint[] memory arr = new uint[](5);
        arr[0] = 5;
        arr[1] = 3;
        arr[2] = 8;
        arr[3] = 4;
        arr[4] = 2;
        return bubbleSort(arr);
    }
}