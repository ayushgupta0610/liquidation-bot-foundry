// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Superman} from "../src/aave/Superman.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract SupermanScript is Script {
    Superman public superman;

    function run() public {
        // Deploy mocks
        string memory rpcUrl = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(rpcUrl);

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();

        superman = new Superman(
            config.account, config.aavePool, config.poolAddressesProvider, config.routerV2, config.aaveOracle
        );

        vm.stopBroadcast();
    }
}
