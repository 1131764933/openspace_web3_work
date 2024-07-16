// src/config.ts
import { createWeb3Modal, defaultWagmiConfig } from '@web3modal/wagmi';
import { mainnet, arbitrum } from 'viem/chains';
import { reconnect } from '@wagmi/core';

const projectId = 'ff42aea1030542ecf983fa7e0c9c4873'; // 替换为你的项目 ID

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
