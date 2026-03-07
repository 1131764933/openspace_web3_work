#  react前端使用 web3modal SDK实现点击【Connect Wallet】按钮，请求 MetaMask 钱包



要在 React 前端项目中实现一个连接钱包的功能，你可以按照以下步骤操作。这些步骤将指导你如何在一个 React 应用中使用 Web3Modal 和 Wagmi 库来实现连接 MetaMask 钱包的功能，并在网页中显示授权访问的钱包地址。

### 1. 创建 React 项目

首先，创建一个新的 React 项目。如果你已经有一个 React 项目，可以跳过这一步。

```
npx create-react-app web3modal-example
cd web3modal-example
```

### 2. 安装依赖

安装 `@web3modal/wagmi`, `@wagmi/core`, 和 `viem` 库。

```
npm install @web3modal/wagmi @wagmi/core @wagmi/connectors viem ethers@^5.0.0  --legacy-peer-deps

npm install typescript @types/node @types/react @types/react-dom @types/jest --legacy-peer-deps
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

### 5. 创建 React 组件

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

### 6. 使用组件

在 `src/App.tsx` 文件中使用 `WalletConnector` 组件：

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

### 3. 确保 `tsconfig.json` 存在并正确配置

如果你的项目中没有 `tsconfig.json` 文件，请确保在项目根目录下创建一个：

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

### 

### 7. 运行项目

确保项目编译成功，并运行 React 项目：

```
npm start
```

访问 `http://localhost:3000`，你应该能看到一个【Connect Wallet】按钮。点击按钮可以请求 MetaMask 钱包，获得授权后将在网页中显示授权访问的钱包地址和余额。

### 总结

上述步骤详细介绍了如何在一个 React 项目中使用 Web3Modal 和 Wagmi 来实现连接 MetaMask 钱包的功能，并在网页中显示钱包地址和余额。确保你的项目 ID 正确配置，并且所有依赖项正确安装。如果在运行过程中遇到问题，可以检查浏览器控制台的错误信息以进行调试。





调试代码：

1、我想把上面的代码功能做一个改动，在没有连接之前显示的是Connect Wallet，就是当我连接钱包成功之后，这个Connect Wallet就显示成了该钱包的地址

修改后的 `WalletConnector.tsx`

```
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
      <button onClick={connectWallet}>
        {address ? address : 'Connect Wallet'}
      </button>
      {address && (
        <>
          <div id="balance">Balance: {balance} ETH</div>
        </>
      )}
    </div>
  );
};

export default WalletConnector;

```

### 关键改动

1. **按钮文本的动态更新**:
   - 在 `<button>` 中，我们通过三元运算符 `address ? address : 'Connect Wallet'` 动态设置按钮的文本。如果 `address` 存在（即钱包已经连接），按钮将显示钱包地址；否则，按钮将显示 “Connect Wallet”。
2. **条件渲染余额**:
   - 只有在地址存在（即钱包已连接）时才显示余额信息。这通过条件渲染 `{address && (...)}` 实现。

### 功能解释

- 在页面加载时，`address` 和 `balance` 的初始值为 `null`。

- 当用户点击 “Connect Wallet” 按钮时，会触发

   

  ```
  connectWallet
  ```

   

  函数：

  1. 打开连接钱包的 Modal。
  2. 获取钱包账户信息（包括地址）。
  3. 获取钱包余额并格式化为 Ether 单位。
  4. 将获取到的 `address` 和 `balance` 更新到组件的状态中。

- 一旦连接成功，按钮的文本会动态更新为钱包的地址，同时页面上会显示该钱包的余额。

通过这种方式，当用户连接钱包后，不再需要显示 “Connect Wallet” 按钮，而是直接显示已连接的钱包地址，从而简化用户界面。

like this

![image-20240823095714303](/Users/yhb/Library/Application Support/typora-user-images/image-20240823095714303.png)

2、不用把钱包地址全部展示出来，我希望是地址开头是0x234...1e69这种形式

为了只显示钱包地址的部分内容，可以对地址进行截断处理，仅显示开头的几位和结尾的几位，中间用省略号代替。下面是修改后的代码：

```
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

  const truncateAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <div>
      <button onClick={connectWallet}>
        {address ? truncateAddress(address) : 'Connect Wallet'}
      </button>
      {address && (
        <>
          <div id="balance">Balance: {balance} ETH</div>
        </>
      )}
    </div>
  );
};

export default WalletConnector;

```

### 关键改动

1. **地址截断函数 `truncateAddress`**:
   - 添加了一个 `truncateAddress` 函数，用于截断钱包地址，只显示开头的 6 个字符和结尾的 4 个字符，中间用省略号 (`...`) 代替。
   - 例如，地址 `0x234567891234abcd1e69` 将被显示为 `0x2345...1e69`。
2. **在按钮文本中使用截断地址**:
   - 在按钮文本中，使用 `truncateAddress(address)` 函数来显示截断后的地址，而不是完整地址。

### 功能解释

- 在用户点击“Connect Wallet”并成功连接钱包后，按钮将显示截断后的地址形式，例如 `0x2345...1e69`。
- 余额信息将继续显示在按钮下方。

通过这种方式，用户可以在页面上更直观地查看钱包地址，而不会被全地址占据过多的空间，同时又能保持地址的识别性。

like this：

![image-20240823095616794](/Users/yhb/Library/Application Support/typora-user-images/image-20240823095616794.png)

