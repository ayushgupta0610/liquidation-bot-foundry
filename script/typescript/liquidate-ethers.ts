import { ethers } from "ethers";
import dotenv from "dotenv";

dotenv.config();

const config = {
  mainnet: {
    rpcUrl: process.env.ETH_FLASH_RPC_URL!,
    supermanAddress: "0x...", // Your Superman contract address
    wethAddress: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    usdcAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    aavePool: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2",
    slippageFactor: 100n, // 1%
  },
  base: {
    rpcUrl: process.env.BASE_RPC_URL!,
    supermanAddress: "0x492845a32B8d5b27d39F54F4AE1D0FefE051FB88", // Your Superman contract address
    wethAddress: "0x4200000000000000000000000000000000000006",
    usdcAddress: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    aavePool: "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5",
    slippageFactor: 250n, // 2.5%
  },
  arbitrum: {
    rpcUrl: process.env.ARBITRUM_RPC_URL!,
    supermanAddress: "0xE16A82c9d7509EBc271E9e756901ae8D52B0028e", // Your Superman contract address
    aavePool: "0x794a61358d6845594f94dc1db02a252b5b4814ad",
    usdcAddress: "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
    wethAddress: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    slippageFactor: , // 2.5%
  },
};

const supermanAbi = [
  "function liquidate(address collateralToken, address debtToken, address user, uint256 debtToCover, bool receiveAToken, uint256 slippageFactor) external",
];

const poolAbi = [
  "function getUserAccountData(address user) external view returns (uint256 totalCollateralBase, uint256 totalDebtBase, uint256 availableBorrowsBase, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor)",
];

async function liquidateUser(user: string, chainId: 1 | 8453) {
  const currentConfig = chainId === 1 ? config.mainnet : config.base;

  const provider = new ethers.JsonRpcProvider(currentConfig.rpcUrl);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  const superman = new ethers.Contract(
    currentConfig.supermanAddress,
    supermanAbi,
    wallet
  );

  const pool = new ethers.Contract(currentConfig.aavePool, poolAbi, wallet);

  try {
    // Get user's debt data
    const [, totalDebtBase] = await pool.getUserAccountData(user);

    // Calculate 50% of the debt
    const debtToCover = (totalDebtBase * 50n) / 100n;

    console.log(`Attempting to liquidate user ${user}`);
    console.log(`Debt to cover: ${ethers.formatEther(debtToCover)} ETH`);

    // Execute liquidation
    const tx = await superman.liquidate(
      currentConfig.wethAddress,
      currentConfig.usdcAddress,
      user,
      debtToCover,
      false,
      currentConfig.slippageFactor,
      {
        gasLimit: 1000000, // Adjust as needed
      }
    );

    // Wait for transaction confirmation
    const receipt = await tx.wait();

    console.log(`Liquidation successful! Tx hash: ${receipt?.hash}`);
    return receipt;
  } catch (error) {
    console.error(`Failed to liquidate user ${user}:`, error);
    throw error;
  }
}

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

async function main() {
  const liquidatableUsers = ["0x...", "0x..."]; // Your list of users to liquidate
  const chainId = 8453; // or 8453 for Base

  await processLiquidations(liquidatableUsers, chainId);
}

main().catch(console.error);
