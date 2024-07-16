
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

contract Counter {
    uint256 public counter;

    constructor() {
        counter=0;
    }

    function getCounter() public view returns(uint256)  {
        return counter;
    }

    function addCounter(uint256 x) public  returns(uint256 _counter){
         counter=counter+x;
         return counter;
    }


}

