//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MockERC20} from "../src/libraries/dynamicERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeployMockUsdc is Script {
    function run() external {
        vm.startBroadcast();
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        vm.stopBroadcast();

        console.log("Mock USDC deployed at:", address(usdc));
    }
}

