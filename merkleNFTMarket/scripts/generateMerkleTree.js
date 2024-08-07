const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');

// 示例白名单地址
const whitelist = [
  '0x65034a9364DF72534d98Acb96658450f9254ff59',
  '0x6Bf159Eb8e007Bd3CBb65b1478AeE7C32001CCdC',
  '0x531247BbA4d32ED9D870bc3aBe71A2B9ce911e69',
];

// 将地址转换为 Merkle 树的叶子节点
const leaves = whitelist.map(addr => keccak256(addr));
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = tree.getHexRoot();

// 输出 Merkle 根节点
console.log('Merkle Root:', root);

// 将 Merkle 根节点写入文件
fs.writeFileSync('merkleRoot.txt', root);