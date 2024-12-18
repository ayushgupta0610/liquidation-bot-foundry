import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  formatEther,
  Account,
} from "viem";
import { mainnet, base } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import dotenv from "dotenv";

dotenv.config();

// ABI for the relevant functions
const supermanAbi = parseAbi([
  "function liquidate(address collateralToken, address debtToken, address user, uint256 debtToCover, bool receiveAToken, uint256 slippageFactor) external",
  "function getUserAccountData(address user) external view returns (uint256 totalCollateralBase, uint256 totalDebtBase, uint256 availableBorrowsBase, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor)",
]);

// Configuration
const config = {
  mainnet: {
    rpcUrl: process.env.ETH_FLASH_RPC_URL!,
    supermanAddress: "0x...", // Your Superman contract address on mainnet
    wethAddress: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    usdcAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    slippageFactor: 100n, // 1%
  },
  base: {
    rpcUrl: process.env.BASE_RPC_URL!,
    supermanAddress: "0x...", // Your Superman contract address on base
    wethAddress: "0x4200000000000000000000000000000000000006",
    usdcAddress: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    slippageFactor: 250n, // 2.5%
  },
  arbitrum: {
    rpcUrl: process.env.ARBITRUM_RPC_URL!,
    supermanAddress: "0xE16A82c9d7509EBc271E9e756901ae8D52B0028e", // Your Superman contract address
    usdcAddress: "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
    wethAddress: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    slippageFactor: , // 2.5%
  },
};

// Create clients
const mainnetClient = createPublicClient({
  chain: mainnet,
  transport: http(config.mainnet.rpcUrl),
});

const baseClient = createPublicClient({
  chain: base,
  transport: http(config.base.rpcUrl),
});

// Create wallet client
const account = privateKeyToAccount(process.env.PRIVATE_KEY! as `0x${string}`);
const mainnetWallet = createWalletClient({
  account,
  chain: mainnet,
  transport: http(config.mainnet.rpcUrl),
});

const baseWallet = createWalletClient({
  account,
  chain: base,
  transport: http(config.base.rpcUrl),
});

async function liquidateUser(user: string, chainId: 1 | 8453) {
  const currentConfig = chainId === 1 ? config.mainnet : config.base;
  const client = chainId === 1 ? mainnetClient : baseClient;
  const wallet = chainId === 1 ? mainnetWallet : baseWallet;

  try {
    // Get user's debt data
    const { totalDebtBase } = await client.readContract({
      address: currentConfig.supermanAddress,
      abi: supermanAbi,
      functionName: "getUserAccountData",
      args: [user],
    });

    // Calculate 50% of the debt
    const debtToCover = (totalDebtBase * 50n) / 100n;

    console.log(`Attempting to liquidate user ${user}`);
    console.log(`Debt to cover: ${formatEther(debtToCover)} ETH`);

    // Execute liquidation
    const hash = await wallet.writeContract({
      address: currentConfig.supermanAddress,
      abi: supermanAbi,
      functionName: "liquidate",
      args: [
        currentConfig.wethAddress,
        currentConfig.usdcAddress,
        user,
        debtToCover,
        false,
        currentConfig.slippageFactor,
      ],
    });

    // Wait for transaction confirmation
    const receipt = await client.waitForTransactionReceipt({ hash });

    console.log(`Liquidation successful! Tx hash: ${receipt.transactionHash}`);
    return receipt;
  } catch (error) {
    console.error(`Failed to liquidate user ${user}:`, error);
    throw error;
  }
}

// Function to process multiple users
async function processLiquidations(users: string[], chainId: 1 | 8453) {
  for (const user of users) {
    try {
      await liquidateUser(user, chainId);
    } catch (error) {
      console.error(`Skipping to next user after error with ${user}`);
      continue;
    }
  }
}

// Example usage
async function main() {
  const liquidatableUsers = ["0x...", "0x..."]; // Your list of users to liquidate
  const chainId = 1; // or 8453 for Base

  await processLiquidations(liquidatableUsers, chainId);
}

main().catch(console.error);
