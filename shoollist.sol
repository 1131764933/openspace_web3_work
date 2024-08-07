// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract SchoolOptimized {
  //存储每个学生地址对应的分数的映射
  mapping(address => uint256) public scores;
  //用于链接每个学生到列表中下一个学生的映射，形成一个链表
  mapping(address => address) _nextStudents;
  //一个计数器，用于记录学生列表的大小
  uint256 public listSize;
  //一个常量地址，用于标记链表的头部，防止链表为空
  address constant GUARD = address(1);
  
  constructor() {
    //初始化时，将 GUARD 指向自己，形成一个循环的链表起点
    _nextStudents[GUARD] = GUARD;
  }
  
  //添加学生
  function addStudent(address student, uint256 score, address candidateStudent) public {
    require(_nextStudents[student] == address(0));
    //检查 candidateStudent 是否有效，即它是否存在于链表中
    require(_nextStudents[candidateStudent] != address(0));
    //确保新学生的分数在 candidateStudent 和其后继学生之间是有效的
    require(_verifyIndex(candidateStudent, score, _nextStudents[candidateStudent]));
    scores[student] = score;
    //将新学生插入到 candidateStudent 后
    _nextStudents[student] = _nextStudents[candidateStudent];
    _nextStudents[candidateStudent] = student;
    listSize++;
  }
  
  function increaseScore(
    address student, 
    uint256 score, 
    address oldCandidateStudent, 
    address newCandidateStudent
  ) public {
    updateScore(student, scores[student] + score, oldCandidateStudent, newCandidateStudent);
  }
  
  function reduceScore(
    address student, 
    uint256 score, 
    address oldCandidateStudent, 
    address newCandidateStudent
  ) public {
    updateScore(student, scores[student] - score, oldCandidateStudent, newCandidateStudent);
  }
  
  function updateScore(
    address student, 
    uint256 newScore, 
    address oldCandidateStudent, 
    address newCandidateStudent
  ) public {
    require(_nextStudents[student] != address(0));
    require(_nextStudents[oldCandidateStudent] != address(0));
    require(_nextStudents[newCandidateStudent] != address(0));
    if(oldCandidateStudent == newCandidateStudent)
    {
      require(_isPrevStudent(student, oldCandidateStudent));
      require(_verifyIndex(newCandidateStudent, newScore, _nextStudents[student]));
      scores[student] = newScore;
    } else {
      removeStudent(student, oldCandidateStudent);
      addStudent(student, newScore, newCandidateStudent);
    }
  }
  
  function removeStudent(address student, address candidateStudent) public {
    require(_nextStudents[student] != address(0));
    require(_isPrevStudent(student, candidateStudent));
    _nextStudents[candidateStudent] = _nextStudents[student];
    _nextStudents[student] = address(0);
    scores[student] = 0;
    listSize--;
  }
  //获取前 k 名学生
  function getTop(uint256 k) public view returns(address[] memory) {
    require(k <= listSize);
    address[] memory studentLists = new address[](k);
    address currentAddress = _nextStudents[GUARD];
    //遍历链表，提取前 k 个学生
    for(uint256 i = 0; i < k; ++i) {
      studentLists[i] = currentAddress;
      currentAddress = _nextStudents[currentAddress];
    }
    return studentLists;
  }
  
  //检查新的学生分数是否在合适的位置（即它应介于前驱和后继学生之间）
  function _verifyIndex(address prevStudent, uint256 newValue, address nextStudent)
    internal
    view
    returns(bool)
  {
    return (prevStudent == GUARD || scores[prevStudent] >= newValue) && 
          (nextStudent == GUARD || newValue > scores[nextStudent]);
  }
  //验证某个学生是否为另一学生的前驱
  function _isPrevStudent(address student, address prevStudent) internal view returns(bool) {
    return _nextStudents[prevStudent] == student;
  }
} 