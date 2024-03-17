# KingSwap Contracts

KingSwap is a platform that enables users without native tokens to use an ERC20Permit compatible token for paying swap transaction fees towards a native token. It utilizes the EIP-2612 standard, allowing users to sign a message that authorizes a spender to use their tokens on their behalf. By integrating with PancakeSwapV4 hooks, KingSwap efficiently refunds transaction fees to the relayer on the user's behalf.

## Contracts Overview

### KingSwap

- **Description**: The central contract that users interact with for token swapping and for the relayer to receive refunds on transaction fees.
- **Main Functions**:
  - Token swapping
  - Refunding the relayer for transaction fees

### KingSwapHook

- **Description**: This contract monitors the gas expended by the relayer to cover transaction fees for the user.
- **Key Operations**:
  - Receives tokens from the PancakeSwap Vault
  - Splits tokens between the relayer and the user

## Development Guide

### Install Dependencies

```bash
forge install
```

### Compile Contracts

```bash
forge compile
```

### Run Tests

```bash
forge test
```

## Deployed Contracts Information

### Base Sepolia Testnet

- **KingSwap.sol**: [View on BaseScan](https://sepolia.basescan.org/address/0xdfa46254e8543e094fb3911d261cb824453b3f14)
- **KingSwapHook.sol**: [View on BaseScan](https://sepolia.basescan.org/address/0x0bf83d6eff67c49464fffca77f7553e6066c19d6)

### Arbitrum Sepolia Testnet

- **KingSwap.sol**: [View on Arbiscan](https://sepolia.arbiscan.io/address/0x8b8fc6d345ef56fbef941dda3794fcbf207169d2)
- **KingSwapHook.sol**: [View on Arbiscan](https://sepolia.arbiscan.io/address/0x7f5eac4cc93a670f9132040289453967a04cb549)
