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
