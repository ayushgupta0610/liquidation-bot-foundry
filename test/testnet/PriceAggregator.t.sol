// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AggregatorProxy} from "./AggregatorProxy.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PriceCheckerTest is Test {
    AggregatorV3Interface internal priceFeed;

    function setUp() public {
        string memory rpcUrl = vm.envString("ETH_RPC_URL");
        uint256 FORK_BLOCK = vm.envUint("FORK_BLOCK_NUMBER");
        vm.createSelectFork(rpcUrl, FORK_BLOCK);

        // Debug current price
        address ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        priceFeed = AggregatorV3Interface(ETH_USD_FEED);
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        console.log("Initial ETH price:", uint256(price));

        // Find implementation address (phase aggregator)
        AggregatorProxy proxy = AggregatorProxy(ETH_USD_FEED);
        uint16 currentPhaseId = proxy.phaseId();
        address implAddress = address(proxy.phaseAggregators(currentPhaseId));
        console.log("Implementation address:", implAddress);

        // This is the OCR transmitter that submits price updates
        address transmitter = 0x37dC56A5FD7fD61EdF3233b77Ea91CA5E1112C32;
        // The actual transmission data from block 21044202
        bytes memory transmitData =
            hex"0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000065580717000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000006577867c000000000000000000000000000000000000000000000000000000006577867c00000000000000000000000000000000000000000000000000000000000d6ee0cbd9792256c4cb55affa67506024fa3eaecd746af8a53b5f4d62e5bffd7d98d9a200000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000041aedb12ccfd1c6c8a170192cf53cbab9c80262f0a7c33ea1cbd02758c38dad7aa33d0d33cbe7ebcf1327fc488a42c62f1c6f5430a6cfd96ce36f591db534785c1c00000000000000000000000000000000000000000000000000000000000000";

        vm.startPrank(transmitter);
        // We need to interact with implementation contract directly
        (bool success,) = implAddress.call(transmitData);
        require(success, "Price update failed");
        vm.stopPrank();
    }

    function testPriceAggragation() public {}
}
