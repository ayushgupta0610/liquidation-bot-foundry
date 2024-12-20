// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";
import {Superman} from "../../src/aave/Superman.sol";
import {IPool} from "../../src/interfaces/IPool.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IPoolAddressesProvider} from "../../src/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "../../src/interfaces/IAaveOracle.sol";
import {AggregatorProxy} from "./AggregatorProxy.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface AuthorizedForwarderInterface {
    function forward(address to, bytes memory data) external;
}

contract SupermanForkTest is Test {
    using SafeTransferLib for address;

    Superman private superman;
    HelperConfig.NetworkConfig private networkConfig;
    IPool private pool;
    IERC20 collateralToken; // weth
    IERC20 debtToken; // usdc
    address private owner;
    address private liquidator;

    address private user;
    uint256 public constant INITIAL_USDC_BALANCE = 1_000_000e6; // 1000_000 USDC
    uint256 public constant INITIAL_WETH_BALANCE = 30 ether; // 30 ethers

    IPoolAddressesProvider private poolAddressesProvider;
    IAaveOracle private aaveOracle;

    // Add constants for testing
    uint256 private constant FLASH_LOAN_PREMIUM = 5; // 0.05%
    uint256 private constant PRECISION = 10000;
    uint8 private constant ORACLE_DECIMAL = 8;
    uint256 private constant SLIPPAGE_FACTOR = 259; // 2.5% (250) slippage required to convert the collateral asset from debt asset (on Base UV2 from WETH to USDC!)

    function setUp() public {
        // Setup contracts
        user = vm.envAddress("USER_ADDRESS");
        string memory rpcUrl = vm.envString("ETH_FLASH_RPC_URL");
        uint256 FORK_BLOCK = vm.envUint("FORK_BLOCK_NUMBER"); // Example block number for Base network
        vm.createSelectFork(rpcUrl, FORK_BLOCK);

        HelperConfig config = new HelperConfig();
        networkConfig = config.getConfig();

        collateralToken = IERC20(networkConfig.weth);
        debtToken = IERC20(networkConfig.usdc);
        aaveOracle = IAaveOracle(networkConfig.aaveOracle);
        owner = networkConfig.account;
        liquidator = owner;

        // Deploy Superman with correct parameters
        poolAddressesProvider = IPoolAddressesProvider(networkConfig.poolAddressesProvider);
        pool = IPool(networkConfig.aavePool);
        superman = new Superman(
            owner, address(pool), address(poolAddressesProvider), networkConfig.routerV2, networkConfig.aaveOracle
        );

        // Additional setup
        deal(networkConfig.weth, address(user), INITIAL_WETH_BALANCE, false);

        // Execute a mock transaction to transmit price feed on Chainlink Oracle
        _mockTransmitPrice();
    }

    function _mockTransmitPrice() private {
        // Debug current price
        address ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 price,,,) = priceFeed.latestRoundData();
        console.log("Initial ETH price:", uint256(price));

        // Find implementation address
        AggregatorProxy proxy = AggregatorProxy(ETH_USD_FEED);
        uint16 currentPhaseId = proxy.phaseId();
        address implAddress = address(proxy.phaseAggregators(currentPhaseId));

        // Forwarder address
        address forwarder = 0x9cFAb1513FFA293E7023159B3C7A4C984B6a3480; // 0xd8Aa8F3be2fB0C790D3579dcF68a04701C1e33DB;
        address AuthorizedForwarder = 0x5eA7eAe0EBC1f4256806C8bf234F672d410Fc988;

        // From transaction: https://etherscan.io/tx/0xe86bbb7aaacebabb9876a695f8456f13702239406bc32188e537843089dc733f
        bytes memory data =
            hex"b1dc65a40001bae4cfd569eba896a006e16d478e1debbd72a760d3b452a0cc307c04d20c000000000000000000000000000000000000000000000000000000000046550543230db5514248bca6cad36b91ff94c1801db6286a6c82d0df5207ee613245d500000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000058000000000000000000000000000000000000000000000000000000000000007000100000101010101000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000048000000000000000000000000000000000000000000000000000000000671bd8b917151a020e0a00081d0c0d1e1312061103180b070f051c1604190114101b0900000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000bb5238aa26894b7c5000000000000000000000000000000000000000000000000000000000000001f0000000000000000000000000000000000000000000000000000003a5b7b4b300000000000000000000000000000000000000000000000000000003a5b7b4b300000000000000000000000000000000000000000000000000000003a5dece7570000000000000000000000000000000000000000000000000000003a5dece7570000000000000000000000000000000000000000000000000000003a5e961fc00000000000000000000000000000000000000000000000000000003a5e961fc00000000000000000000000000000000000000000000000000000003a61a052800000000000000000000000000000000000000000000000000000003a61a052800000000000000000000000000000000000000000000000000000003a627473940000000000000000000000000000000000000000000000000000003a627473940000000000000000000000000000000000000000000000000000003a62afe9110000000000000000000000000000000000000000000000000000003a62f004000000000000000000000000000000000000000000000000000000003a62f520980000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a643fb5800000000000000000000000000000000000000000000000000000003a6449eeb00000000000000000000000000000000000000000000000000000003a64d84c000000000000000000000000000000000000000000000000000000003a64d84c000000000000000000000000000000000000000000000000000000003a64d84c000000000000000000000000000000000000000000000000000000003a64f5a9b40000000000000000000000000000000000000000000000000000003a64f5a9b40000000000000000000000000000000000000000000000000000003a64f5a9b40000000000000000000000000000000000000000000000000000003a64f5a9b40000000000000000000000000000000000000000000000000000003a64f5a9b40000000000000000000000000000000000000000000000000000003a6b94b3300000000000000000000000000000000000000000000000000000003a6b94b3300000000000000000000000000000000000000000000000000000003a6b94b330000000000000000000000000000000000000000000000000000000000000000b10a15c15e34f5b16c39ba3b53bbd03ed4331bcacc8db1a830a6345a66eec1dcbb5da0f0159f24c65c2807bb315bedba44c9b22ed1a769ebbc441616454a0548e5df8d1258f992eb538416629b441d14dac9af9ebd605ce7c21b7002be6ebbf0a31f481c5ad575e777dcbb651a6c95914cc780a47f7d32d9eb6e4b7ca6c9f986faae9441deda23f59d70cb13d305c8ad541b09814e873d73980bc3be8d5e6fedf53ca9739ee8cde6d5ef7edd1084af13355c16019358c1581c1f339627bbbb42a48cfb7895b449f6e0bb50b2e0911955ca61a1ad69a9fa2cd8fb83305d1dfa8e6a541165af679fcd0713deab68cdf91b588c00240f0c55c9aadb75cebfe2116b3643e551cea968401b677204c2be1202e1314dfbec24dc75a2077bb769661a9adc31b3beccf5cb39109d0bb3ab5b1fd1ba659d025623bfd5ad92cc788107a5c43d2441399dd9a29ad436259614973281e01ded9a1053230194b8daf2da8bacea3000000000000000000000000000000000000000000000000000000000000000b232ed764018ecc91182460f9eab66c5d77240952c38512ae302f37648e9c5162790ca3bfc6b00c776893ecd9e69f3aa70d4d775cabafd6b7b0ba607d4b256e3b1ad568c3c161e2034a044b6f1e50dce99fefa7a049b0669da0617e9b7d48904e27cc80b69a654b0ae26abcef74089c854ee31aaa21ff578ec9c07682265da254012b8405c9caad59d1978378360f7d3a772fc2a45ce197d38711cc6f23c694800574b9dfcbd305a8fab06fd5ff22d0d022aa05882cafddcdbff21006dad8341e54406829495704d3ce1dbc89ba17713f75506097418505028c65ea548dbbdef80bddde088ea021c2ad57829af6050713ebb5a438fc04c2ef6d28ad06e6b8a7f543640381ee1ab86fc13326d427cec64a9e8ceb8773003e43650c3a011c5d7896146c88bdd21de19a156529eb7749b6af0da2410d2c5f1b7f0752fba92cdc2a2c635e5aa59a3caf6be0e9ad7f80f9e16f83996958b591a06d043e64f432715c3f";

        vm.startPrank(forwarder);
        // (bool success,) = AuthorizedForwarderInterface(AuthorizedForwarder).forward(implAddress, data);
        (bool success,) = AuthorizedForwarder.call(
            abi.encodeWithSelector(AuthorizedForwarderInterface.forward.selector, implAddress, data)
        );

        require(success, "Price update failed");
        vm.stopPrank();

        // Verify the update
        (, int256 updatedPrice,,,) = priceFeed.latestRoundData();
        console.log("Updated ETH price:", uint256(updatedPrice));
    }

    function testForkLiquidationHavingDebtToCover() public {
        // Store initial balances
        uint256 initialOwnerCollateral = collateralToken.balanceOf(liquidator);

        // Get total debt
        (, uint256 totalDebtBase,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        console.log("healthFactor :", healthFactor);

        // Try to liquidate 75% of the debt (should be capped at 50%)
        uint256 debtToCover = (totalDebtBase * 75) / 100;

        // Fund liquidator
        deal(address(debtToken), liquidator, debtToCover);

        vm.startPrank(liquidator);
        debtToken.approve(address(superman), debtToCover);

        superman.liquidate(address(collateralToken), address(debtToken), user, debtToCover, false, SLIPPAGE_FACTOR);
        vm.stopPrank();

        // Verify results
        (, uint256 finalTotalDebtBase,,,,) = pool.getUserAccountData(user);

        // Check that no more than 50% was liquidated
        assertGe(finalTotalDebtBase, totalDebtBase / 2, "Cannot liquidate more than 50%");
        assertLt(finalTotalDebtBase, totalDebtBase, "Should have liquidated some debt");

        // Check collateral transfer
        assertGt(collateralToken.balanceOf(liquidator), initialOwnerCollateral, "Owner should receive collateral");

        // Verify Superman contract has no leftover tokens
        assertEq(collateralToken.balanceOf(address(superman)), 0, "Superman should not have collateral tokens");
        assertEq(debtToken.balanceOf(address(superman)), 0, "Superman should not have debt tokens");
    }

    function testForkLiquidationWithoutDebtToCover() public {
        // Store initial balances
        // uint256 initialOwnerCollateral = collateralToken.balanceOf(liquidator);

        // Get total debt
        (, uint256 totalDebtBase,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        console.log("healthFactor :", healthFactor);

        // Try to liquidate 75% of the debt (should be capped at 50%)
        uint256 debtToCover = (totalDebtBase * 75) / 100;

        // Fund liquidator (This won't be there)
        // deal(address(debtToken), liquidator, debtToCover);

        vm.startPrank(liquidator);
        debtToken.approve(address(superman), debtToCover);

        superman.liquidate(address(collateralToken), address(debtToken), user, debtToCover, false, SLIPPAGE_FACTOR);
        vm.stopPrank();

        // Verify results
        (, uint256 finalTotalDebtBase,,,,) = pool.getUserAccountData(user);

        // Check that no more than 50% was liquidated
        assertGe(finalTotalDebtBase, totalDebtBase / 2, "Cannot liquidate more than 50%");
        assertLt(finalTotalDebtBase, totalDebtBase, "Should have liquidated some debt");

        // Verify Superman contract has no leftover tokens
        assertEq(collateralToken.balanceOf(address(superman)), 0, "Superman should not have collateral tokens");
        assertEq(debtToken.balanceOf(address(superman)), 0, "Superman should not have debt tokens");
    }
}
