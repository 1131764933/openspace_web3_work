# 使用 Viem 实时监听最新区块和 USDT 转账流水



1、监听新区块，打印区块高度和区块哈稀值

如`20329474 (0x662022f0...cc0dea26)`

2、实时采集并打印最新 USDT Token（0xdac17f958d2ee523a2206206994597c13d831ec7） Transfer 流水
如`在 20329474 区块 0xe52ff...7ddcf 交易中从 0x65eDc7E1...5518AeF12 转账 50 USDT 到 0xa2D30559...30348f472`

使用 Viem 编写 TypeScript 脚本来监听最新区块和 USDT 转账流水，并使用 React 在网页中展示结果。以下是详细的实现步骤：

### 步骤 1: 创建项目文件夹和初始化项目

在你的终端中运行以下命令：

```
mkdir viem_USDTTransfer
cd viem_USDTTransfer
npm init -y
```

### 步骤 2: 安装依赖

安装 Viem 以及 TypeScript 和 React 等必要的依赖：

```
pnpm install viem react react-dom @types/react @types/react-dom

npm install --save-dev typescript ts-node @types/node @types/react @types/react-dom --legacy-peer-deps
```

### 步骤 3: 创建 TypeScript 配置文件

在项目根目录下创建 `tsconfig.json` 文件，内容如下：

```
{
  "compilerOptions": {
    "target": "ES2020", // 更新为 ES2020
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "jsx": "react",
    "jsxFactory": "React.createElement",
    "jsxFragmentFactory": "React.Fragment"
  },
  "include": ["src/**/*.tsx", "src/**/*.ts"],
  "exclude": ["node_modules", "**/*.spec.ts"]
}

```

### 步骤 4: 编写 TypeScript 脚本

在 `viem_USDTTransfer` 文件夹中创建 `src` 文件夹，然后在 `src` 文件夹中创建 `index.tsx` 文件，内容如下：

```
import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { createPublicClient, http, parseAbiItem, formatUnits } from 'viem';
import { mainnet } from 'viem/chains';

// USDT 合约地址
const USDT_CONTRACT_ADDRESS = '0xdac17f958d2ee523a2206206994597c13d831ec7';

// Transfer 事件的 ABI 格式
const TRANSFER_EVENT_ABI = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)');

const App = () => {
    const [blockHeight, setBlockHeight] = useState<number | null>(null);
    const [blockHash, setBlockHash] = useState<string | null>(null);
    const [transfers, setTransfers] = useState<any[]>([]);

    useEffect(() => {
        const client = createPublicClient({
            chain: mainnet,
            transport: http('https://rpc.flashbots.net'),
        });

        const fetchBlockData = async () => {
            const latestBlock = await client.getBlock({ blockTag: 'latest' });
            setBlockHeight(Number(latestBlock.number));
            setBlockHash(latestBlock.hash);
        };

        const subscribeToEvents = () => {
            client.watchBlockNumber({
                onBlockNumber: async (blockNumber) => {
                    if (blockNumber === undefined) {
                        setBlockHeight(null);
                        return;
                    }

                    const safeBlockNumber = blockNumber !== undefined ? BigInt(blockNumber) : 0n; // 提供默认值
                    console.log(safeBlockNumber, "Safe Block Number");
                    setBlockHeight(Number(safeBlockNumber));
                    
                    const fromBlock = safeBlockNumber - 100n;
                    const toBlock = safeBlockNumber;

                    const logs = await client.getLogs({
                        address: USDT_CONTRACT_ADDRESS,
                        event: TRANSFER_EVENT_ABI,
                        fromBlock,
                        toBlock,
                    });

                    console.log(logs, "Logs");

                    const newTransfers = logs.map(log => {
                        const { from, to, value } = log.args || {};
                        console.log(log, "Log");
                        return {
                            blockNumber: log.blockNumber.toString(), // 转换为字符串
                            transactionHash: log.transactionHash,
                            from,
                            to,
                            value: value ? Number(formatUnits(value, 6)).toFixed(5) : '0.00000' // 处理 value 可能为 undefined 的情况
                        };
                    });
                    console.log(newTransfers, "New Transfers");
                    setTransfers(newTransfers);
                },
            });
        };

        fetchBlockData();
        subscribeToEvents();
    }, []);

    return (
        <div>
            <h1>最新区块信息</h1>
            <p>区块高度: {blockHeight}</p>
            <p>区块哈希值: {blockHash}</p>
            <h2>最新 USDT 转账记录</h2>
            {transfers.map((transfer, index) => (
                <div key={index}>
                    <p>在 {transfer.blockNumber} 区块 {transfer.transactionHash} 交易中从 {transfer.from} 转账 {transfer.value} USDT 到 {transfer.to}</p>
                </div>
            ))}
        </div>
    );
};

ReactDOM.render(<App />, document.getElementById('root'));

```

### 步骤 5: 设置 HTML 模板

在项目根目录下创建 `public` 文件夹，然后在 `public` 文件夹中创建 `index.html` 文件，内容如下：

```
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>USDT Transfer</title>
</head>
<body>
    <div id="root"></div>
    <script src="index.js"></script>
</body>
</html>

```

### 步骤 6: 编译并运行项目

安装

```
npm install webpack webpack-cli ts-loader --save-dev
```

在项目根目录下创建 `webpack.config.js` 文件，用于配置 Webpack：

```
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
    entry: './src/index.tsx',
    output: {
        path: path.resolve(__dirname, 'dist'),
        filename: 'index.js',
    },
    resolve: {
        extensions: ['.tsx', '.ts', '.js'],
    },
    module: {
        rules: [
            {
                test: /\.tsx?$/,
                use: 'ts-loader',
                exclude: /node_modules/,
            },
        ],
    },
    devServer: {
        static: {
            directory: path.join(__dirname, 'public'),
        },
        compress: true,
        port: 9000,
    },
    plugins: [
        new HtmlWebpackPlugin({
            template: './public/index.html',
        }),
    ],
};

```

然后运行以下命令来编译并启动开发服务器：

```
npx webpack serve
```

打开浏览器访问 `http://localhost:9000`，你应该能够看到最新的区块高度和 USDT 转账记录。

![image-20240718211830725](/Users/yhb/Library/Application Support/typora-user-images/image-20240718211830725.png)