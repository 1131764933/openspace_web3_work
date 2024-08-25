### 使用 Web3Modal SDK 在 React 项目中实现连接 MetaMask 功能

要在 React 前端项目中实现连接 MetaMask 钱包的功能，并在网页中显示授权访问的钱包地址，你可以按照以下步骤操作。这些步骤将指导你如何在 React 应用中使用 Web3Modal 和 Wagmi 库。

### 1. 创建 React 项目

首先，创建一个新的 React 项目。如果你已经有一个 React 项目，可以跳过这一步。

```
npx create-react-app web3modal-example
cd web3modal-example
```

### 2. 安装依赖

安装所需的依赖包，包括 `@web3modal/wagmi`, `@wagmi/core`, `viem`, 和 `ethers`。

```
npm install @web3modal/wagmi @wagmi/core @wagmi/connectors viem ethers@^5.0.0  --legacy-peer-deps
```

### 3. 获取 WalletConnect 项目 ID

从 [WalletConnect Cloud](https://cloud.walletconnect.com/) 创建一个新项目并获取项目 ID。

### 4. 配置 Web3Modal 和 Wagmi

在你的 React 项目中，创建一个文件 `src/config.ts`，并添加以下代码：

```
// src/config.ts
import { createWeb3Modal, defaultWagmiConfig } from '@web3modal/wagmi';
import { mainnet, arbitrum } from 'viem/chains';
import { reconnect } from '@wagmi/core';

const projectId = 'YOUR_PROJECT_ID'; // 替换为你的项目 ID

const metadata = {
  name: 'Web3Modal',
  description: 'Web3Modal Example',
  url: 'https://web3modal.com', // 这里的origin必须与你的域名和子域名匹配
  icons: ['https://avatars.githubusercontent.com/u/37784886']
};

const chains = [mainnet, arbitrum] as const;

export const config = defaultWagmiConfig({
  chains,
  projectId,
  metadata,
});
reconnect(config);

export const modal = createWeb3Modal({
  wagmiConfig: config,
  projectId,
});
```

### 5. 创建 WalletConnector 组件

在 `src` 目录下创建一个文件 `WalletConnector.tsx`，并添加以下代码：

```
// src/WalletConnector.tsx
import React, { useState } from 'react';
import { getAccount, fetchBalance } from '@wagmi/core';
import { ethers } from 'ethers';
import { modal, config } from './config';

const WalletConnector = () => {
  const [address, setAddress] = useState<string | null>(null);
  const [balance, setBalance] = useState<string | null>(null);

  const connectWallet = async () => {
    try {
      await modal.open();

      const account = getAccount(config);

      if (!account.address) {
        console.error('Account address not found');
        return;
      }

      const balanceResult = await fetchBalance(config, { address: account.address });

      setAddress(account.address);
      setBalance(balanceResult.value ? ethers.utils.formatEther(balanceResult.value) : '0');
    } catch (error) {
      console.error('Wallet connection failed:', error);
    }
  };

  return (
    <div>
      <button onClick={connectWallet}>Connect Wallet</button>
      <div id="address">Address: {address}</div>
      <div id="balance">Balance: {balance} ETH</div>
    </div>
  );
};

export default WalletConnector;
```

### 6. 使用 WalletConnector 组件

将原来的文件`App.js`修改名称为`App.tsx`，在 `src/App.tsx` 文件中使用 `WalletConnector` 组件：

```
// src/App.tsx
import React from 'react';
import WalletConnector from './WalletConnector';

const App = () => {
  return (
    <div className="App">
      <WalletConnector />
    </div>
  );
};

export default App;
```

### 7. 确保 tsconfig.json 存在并正确配置

如果你的项目中没有 `tsconfig.json` 文件，请在项目根目录下创建一个：

```
npx tsc --init
```

然后确保 `tsconfig.json` 文件中包含以下配置：

```
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
```

### 8. 运行项目

确保项目编译成功，并运行 React 项目：

```
npm start
```

访问 `http://localhost:3000`，你应该能看到一个【Connect Wallet】按钮。点击按钮可以请求 MetaMask 钱包，获得授权后将在网页中显示钱包地址和余额。

![image-20240716084033450](/Users/yhb/Library/Application Support/typora-user-images/image-20240716084033450.png)

### 总结

上述步骤详细介绍了如何在 React 项目中使用 Web3Modal 和 Wagmi 实现连接 MetaMask 钱包的功能。确保你的项目 ID 配置正确，并且所有依赖项已正确安装。如果在运行过程中遇到问题，可以检查浏览器控制台的错误信息以进行调试。

这样可以让用户在网页上实现点击按钮连接钱包，并显示钱包地址和余额的功能。