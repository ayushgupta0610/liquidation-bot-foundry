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

        address ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        priceFeed = AggregatorV3Interface(ETH_USD_FEED);

        (uint80 roundId, int256 price,,,) = priceFeed.latestRoundData();
        console.log("Initial ETH price:", uint256(price));

        // Find implementation address
        AggregatorProxy proxy = AggregatorProxy(ETH_USD_FEED);
        uint16 currentPhaseId = proxy.phaseId();
        address implAddress = address(proxy.phaseAggregators(currentPhaseId));
        console.log("implAddress: ", implAddress);
    }

    function testGetPrice() external view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        console.log("price: ", price / 1e8);
        return price;
    }
}
