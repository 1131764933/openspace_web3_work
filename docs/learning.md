# 投票合约学习笔记

## 学习方法总结

1. **Run** - 先让项目跑起来
   - 编译 `forge build`
   - 运行测试 `forge test`

2. **Map** - 建立项目结构地图
   - src/ 源代码
   - test/ 测试
   - lib/ 依赖库
   - foundry.toml 配置

3. **Trace** - 追踪数据流
   - 用户调用 vote()
   - 投票权重加到提案的 voteCount
   - winningProposal() 返回票数最多的提案

4. **Modify** - 写测试理解系统
   - 权限测试（只有主席能授权）
   - 功能测试（投票、委托、计票）
   - 边界测试（时间限制、无效提案）

5. **Rebuild** - 重写简化版
   - 只保留核心功能
   - 提案 + 投票 + 计票

6. **Refactor** - 优化为生产级
   - 自定义 error（省 gas）
   - 循环优化
   - Gas 测试验证

7. **Teach** - 输出知识
   - 写文档
   - 讲给别人

## 关键知识点

### Solidity
- struct 结构体
- mapping 映射
- external vs public 函数
- 自定义 error
- 事件 events

### 测试 (Foundry)
- vm.prank() 模拟用户
- vm.expectRevert() 测试 revert
- gasleft() 测量 gas
- assertEq/assertTrue 断言

### Gas 优化
- 用 error 替代 require 字符串
- 循环变量存到 memory
- 简化数据结构

## 合约对比

| 功能 | Ballot (完整版) | SimpleBallot (简化版) |
|------|----------------|---------------------|
| 提案权重 | ✅ | ❌ |
| 委托投票 | ✅ | ❌ |
| 时间限制 | ✅ | ❌ |
| 自定义 error | ❌ | ✅ |
| Gas 优化 | ❌ | ✅ |
